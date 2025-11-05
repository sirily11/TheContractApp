import Foundation
import BigInt

/// Default implementation of the Contract protocol
public struct EvmContract: Contract {
    public let address: Address
    public let abi: [AbiItem]
    public let signer: Signer
    public let transport: Transport

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
    public init(address: Address, abi: [AbiItem], signer: Signer, transport: Transport) {
        self.address = address
        self.abi = abi
        self.signer = signer
        self.transport = transport
    }

    /// Convenience initializer that accepts an AbiParser
    /// - Parameters:
    ///   - address: The contract address
    ///   - abiParser: The ABI parser containing the contract ABI
    ///   - signer: The signer to use for signing transactions
    ///   - transport: The transport to use for RPC communication
    public init(address: Address, abiParser: AbiParser, signer: Signer, transport: Transport) {
        self.init(address: address, abi: abiParser.items, signer: signer, transport: transport)
    }

    /// Call a function on the contract
    /// - Parameters:
    ///   - name: The name of the function to call
    ///   - args: The arguments to pass to the function
    ///   - value: The value (in wei) to send with the call
    ///   - gasLimit: Optional gas limit for the call
    ///   - gasPrice: Optional gas price for the call
    /// - Returns: The decoded result of the function call
    /// - Throws: ContractError if the function is not found or the call fails
    public func callFunction<T>(
        name: String,
        args: [AnyCodable],
        value: BigInt,
        gasLimit: BigInt? = nil,
        gasPrice: BigInt? = nil
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

        // Encode the function call
        let callData: String
        do {
            // Convert AnyCodable to Any
            let rawArgs = args.map { $0.value }
            callData = try function.encodeCall(args: rawArgs)
        } catch {
            throw ContractError.encodingFailed(error)
        }

        // Build the eth_call parameters
        var callParams: [String: Any] = [
            "to": address.value,
            "data": callData
        ]

        // Add optional parameters
        if value > 0 {
            callParams["value"] = "0x" + String(value, radix: 16)
        }
        if let gasLimit = gasLimit {
            callParams["gasLimit"] = "0x" + String(gasLimit, radix: 16)
        }
        if let gasPrice = gasPrice {
            callParams["gasPrice"] = "0x" + String(gasPrice, radix: 16)
        }

        // Create the RPC request
        let request = RpcRequest(
            method: "eth_call",
            params: [
                AnyCodable(callParams),
                AnyCodable("latest")  // Block parameter
            ]
        )

        // Send the request
        let response: RpcResponse
        do {
            response = try await transport.send(request: request)
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
