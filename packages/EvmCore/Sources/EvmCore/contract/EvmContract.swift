import BigInt
import Foundation

/// Default implementation of the Contract protocol
public struct EvmContract: Contract {
    public let address: Address
    public let abi: [AbiItem]
    public let signer: Signer
    public let evmSigner: EvmClientWithSigner

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
    ///   - signer: The signer to use for signing transactions
    ///   - transport: The transport to use for RPC communication
    public init(address: Address, abi: [AbiItem], signer: Signer, evmSigner: EvmClientWithSigner) {
        self.address = address
        self.abi = abi
        self.signer = signer
        self.evmSigner = evmSigner
    }

    /// Convenience initializer that accepts an AbiParser
    /// - Parameters:
    ///   - address: The contract address
    ///   - abiParser: The ABI parser containing the contract ABI
    ///   - signer: The signer to use for signing transactions
    ///   - transport: The transport to use for RPC communication
    public init(
        address: Address, abiParser: AbiParser, signer: Signer, evmSigner: EvmClientWithSigner
    ) {
        self.init(address: address, abi: abiParser.items, signer: signer, evmSigner: evmSigner)
    }

    /// Call a function on the contract
    /// Automatically chooses between read (eth_call) or write (transaction) based on function's stateMutability
    /// - Parameters:
    ///   - name: The name of the function to call
    ///   - args: The arguments to pass to the function
    ///   - value: The value to send with the call/transaction
    ///   - gasLimit: Optional gas limit for the call/transaction
    ///   - gasPrice: Optional gas price for the call/transaction (in gwei)
    /// - Returns: The decoded result of the function call
    /// - Throws: ContractError if the function is not found or the call fails
    public func callFunction<T>(
        name: String,
        args: [AnyCodable],
        value: Wei,
        gasLimit: GasLimit? = nil,
        gasPrice: Gwei? = nil
    ) async throws -> T where T: Codable {
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
    private func read<T>(
        function: AbiFunction,
        args: [AnyCodable],
        value: Wei,
        gasLimit: GasLimit?,
        gasPrice: Gwei?
    ) async throws -> T where T: Codable {
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
        if value.value > 0 {
            callParams["value"] = "0x" + String(value.value, radix: 16)
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

        // Decode the result
        do {
            return try function.decodeResult(data: resultData)
        } catch {
            throw ContractError.decodingFailed(error)
        }
    }

    /// Private helper: Write data by sending a transaction for nonpayable/payable functions
    private func write<T>(
        function: AbiFunction,
        args: [AnyCodable],
        value: Wei,
        gasLimit: GasLimit?,
        gasPrice: Gwei?
    ) async throws -> T where T: Codable {
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
                from: signer.address.value,
                to: address.value,
                gas: gasLimit,
                gasPrice: gasPrice,
                maxFeePerGas: nil,
                maxPriorityFeePerGas: nil,
                value: TransactionValue(wei: value),
                data: callData,
                nonce: nil
            )
        )

        // Wait for transaction receipt
        let receipt = try await pendingTx.wait()

        // For write operations, if the function has outputs, we need to decode from logs
        // For now, return a dummy value since write operations typically don't return data
        // In the future, we could decode return data from transaction receipt
        if function.outputs.isEmpty {
            // No outputs expected, return unit type or similar
            if T.self == String.self {
                return receipt.transactionHash as! T
            }
            throw ContractError.invalidResponse("Write function completed but return type mismatch")
        } else {
            // Functions with outputs would need special handling
            // For now, throw an error suggesting to use events instead
            throw ContractError.invalidResponse(
                "Write functions with return values are not yet supported. Use events to capture output."
            )
        }
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
