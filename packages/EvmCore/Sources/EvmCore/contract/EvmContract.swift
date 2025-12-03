import BigInt
import Foundation

/// Default implementation of the Contract protocol
public struct EvmContract: Contract {
    public let address: Address
    public let abi: [AbiItem]
    public let evmSigner: EvmClientWithSigner

    /// Computed property that returns the signer from evmSigner
    public var signer: Signer {
        return evmSigner.signer
    }

    /// Derived functions from the ABI
    public var functions: [AbiFunction] {
        abi.compactMap { item in
            guard item.type == .function else { return nil }
            return try? AbiFunction.from(item: item)
        }
    }

    /// Derived events from the ABI
    public var events: [AbiEvent] {
        abi.compactMap { item in
            guard item.type == .event else { return nil }
            return try? AbiEvent.from(item: item)
        }
    }

    /// Initialize a new contract instance
    /// - Parameters:
    ///   - address: The contract address
    ///   - abi: The contract ABI as an array of AbiItem
    ///   - evmSigner: The EVM client with signer for signing transactions
    public init(address: Address, abi: [AbiItem], evmSigner: EvmClientWithSigner) {
        self.address = address
        self.abi = abi
        self.evmSigner = evmSigner
    }

    /// Convenience initializer that accepts an AbiParser
    /// - Parameters:
    ///   - address: The contract address
    ///   - abiParser: The ABI parser containing the contract ABI
    ///   - evmSigner: The EVM client with signer for signing transactions
    public init(
        address: Address, abiParser: AbiParser, evmSigner: EvmClientWithSigner
    ) {
        self.init(address: address, abi: abiParser.items, evmSigner: evmSigner)
    }

    /// Call a function on the contract
    /// Automatically chooses between read (eth_call) or write (transaction) based on function's stateMutability
    /// - Parameters:
    ///   - name: The name of the function to call
    ///   - args: The arguments to pass to the function
    ///   - value: The value to send with the call/transaction
    ///   - gasLimit: Optional gas limit for the call/transaction
    ///   - gasPrice: Optional gas price for the call/transaction (in gwei)
    /// - Returns: The decoded result with optional transaction hash
    /// - Throws: ContractError if the function is not found or the call fails
    public func callFunction(
        name: String,
        args: [AnyCodable],
        value: TransactionValue,
        gasLimit: GasLimit? = nil,
        gasPrice: Gwei? = nil
    ) async throws -> ContractCallResult {
        // Find the function in the ABI
        let matchingFunctions = functions.filter { $0.name == name }

        guard !matchingFunctions.isEmpty else {
            throw ContractError.functionNotFound(name)
        }

        // For now, use the first matching function
        // TODO: In the future, support function overloading by matching parameter types
        let function = matchingFunctions[0]

        // Validate argument count
        guard args.count == function.inputs.count else {
            throw ContractError.argumentCountMismatch(
                expected: function.inputs.count,
                got: args.count
            )
        }

        // Choose between read and write based on stateMutability
        switch function.stateMutability {
        case .view, .pure:
            // Read-only operations use eth_call
            return try await read(
                function: function,
                args: args,
                value: value,
                gasLimit: gasLimit,
                gasPrice: gasPrice
            )
        case .nonpayable, .payable:
            // State-changing operations use transactions
            return try await write(
                function: function,
                args: args,
                value: value,
                gasLimit: gasLimit,
                gasPrice: gasPrice
            )
        }
    }

    /// Private helper: Read data from a view/pure function using eth_call
    private func read(
        function: AbiFunction,
        args: [AnyCodable],
        value: TransactionValue,
        gasLimit: GasLimit?,
        gasPrice: Gwei?
    ) async throws -> ContractCallResult {
        // Encode the function call
        let callData: String
        do {
            let rawArgs = args.map { $0.value }
            callData = try function.encodeCall(args: rawArgs)
        } catch {
            throw ContractError.encodingFailed(error)
        }

        // Build the eth_call parameters
        var callParams: [String: Any] = [
            "to": address.value,
            "data": callData,
        ]

        // Add optional parameters
        if value.toWei().value > 0 {
            callParams["value"] = value.toHexString()
        }
        if let gasLimit = gasLimit {
            callParams["gasLimit"] = gasLimit.toHex()
        }
        if let gasPrice = gasPrice {
            callParams["gasPrice"] = "0x" + String(gasPrice.toWei().value, radix: 16)
        }

        // Create the RPC request
        let request = RpcRequest(
            method: "eth_call",
            params: [
                AnyCodable(callParams),
                AnyCodable("latest"),  // Block parameter
            ]
        )

        // Send the request
        let response: RpcResponse
        do {
            response = try await evmSigner.transport.send(request: request)
        } catch {
            throw ContractError.transportFailed(error)
        }

        // Extract the result data
        guard let resultData = response.result.value as? String else {
            throw ContractError.invalidResponse("Expected string result")
        }

        // Decode the result based on ABI output types
        do {
            let decoded = try decodeAbiResult(function: function, data: resultData)
            return ContractCallResult(result: AnyCodable(decoded), transactionHash: nil)
        } catch {
            throw ContractError.decodingFailed(error)
        }
    }

    /// Decode ABI function result dynamically based on output types
    private func decodeAbiResult(function: AbiFunction, data: String) throws -> Any {
        // Handle functions with no outputs
        guard !function.outputs.isEmpty else {
            return ""
        }

        // Single output - decode based on type
        if function.outputs.count == 1 {
            let outputType = function.outputs[0].type

            // Determine the concrete type to decode
            // IMPORTANT: Check array and tuple types BEFORE primitive types
            // because "uint256[]" would match "starts(with: uint)"
            if outputType == "tuple" || outputType.hasPrefix("tuple[") {
                // For tuples/structs, use the non-generic method
                return try function.decodeResultToAny(data: data)
            } else if outputType.hasSuffix("[]") || (outputType.contains("[") && outputType.contains("]")) {
                // For arrays, use the non-generic method
                return try function.decodeResultToAny(data: data)
            } else if outputType.starts(with: "uint") || outputType.starts(with: "int") {
                return try function.decodeResult(data: data) as BigInt
            } else if outputType == "string" {
                return try function.decodeResult(data: data) as String
            } else if outputType == "bool" {
                return try function.decodeResult(data: data) as Bool
            } else if outputType == "address" {
                return try function.decodeResult(data: data) as String
            } else if outputType == "bytes" || outputType.starts(with: "bytes") {
                return try function.decodeResult(data: data) as String
            } else {
                // For other complex types, try as String
                return try function.decodeResult(data: data) as String
            }
        }

        // Multiple outputs - decode using the non-generic method
        return try function.decodeResultToAny(data: data)
    }

    /// Private helper: Write data by sending a transaction for nonpayable/payable functions
    private func write(
        function: AbiFunction,
        args: [AnyCodable],
        value: TransactionValue,
        gasLimit: GasLimit?,
        gasPrice: Gwei?
    ) async throws -> ContractCallResult {
        // Encode the function call
        let callData: String
        do {
            let rawArgs = args.map { $0.value }
            callData = try function.encodeCall(args: rawArgs)
        } catch {
            throw ContractError.encodingFailed(error)
        }

        // Send transaction
        let pendingTx = try await evmSigner.signAndSendTransaction(
            params: .init(
                from: evmSigner.signer.address.value,
                to: address.value,
                gas: gasLimit,
                gasPrice: gasPrice,
                maxFeePerGas: nil,
                maxPriorityFeePerGas: nil,
                value: value,
                data: callData,
                nonce: nil
            )
        )

        // Wait for transaction receipt
        let receipt = try await pendingTx.wait()

        // For write operations, return the transaction hash
        // Note: Solidity functions don't return values from transactions, only from calls
        // Transaction results must be read from events or by calling view functions after the transaction
        return ContractCallResult(
            result: AnyCodable(receipt.transactionHash),
            transactionHash: receipt.transactionHash
        )
    }

    /// Get a function by name
    /// - Parameter name: The name of the function
    /// - Returns: Array of matching functions (can be multiple due to overloading)
    public func function(named name: String) -> [AbiFunction] {
        return functions.filter { $0.name == name }
    }

    /// Get an event by name
    /// - Parameter name: The name of the event
    /// - Returns: Array of matching events
    public func event(named name: String) -> [AbiEvent] {
        return events.filter { $0.name == name }
    }
}

// MARK: - Contract Errors

public enum ContractError: Error, LocalizedError {
    case functionNotFound(String)
    case eventNotFound(String)
    case argumentCountMismatch(expected: Int, got: Int)
    case encodingFailed(Error)
    case decodingFailed(Error)
    case transportFailed(Error)
    case invalidResponse(String)

    public var errorDescription: String? {
        switch self {
        case .functionNotFound(let name):
            return "Function not found: \(name)"
        case .eventNotFound(let name):
            return "Event not found: \(name)"
        case .argumentCountMismatch(let expected, let got):
            return "Argument count mismatch: expected \(expected), got \(got)"
        case .encodingFailed(let error):
            return "Failed to encode function call: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode function result: \(error.localizedDescription)"
        case .transportFailed(let error):
            return "Transport failed: \(error.localizedDescription)"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        }
    }
}
