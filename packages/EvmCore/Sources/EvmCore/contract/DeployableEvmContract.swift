import Foundation
import BigInt
import Solidity

/// A contract that can be deployed to the blockchain
public struct DeployableEvmContract: DeployableContract {
    public let sourceCode: String?
    public let contractName: String?
    public let bytecode: String?
    public let abi: [AbiItem]
    public let signer: Signer
    public let transport: Transport
    public let compiler: SolidityCompiler?

    /// Initialize with source code (will be compiled during deployment)
    /// - Parameters:
    ///   - sourceCode: Solidity source code
    ///   - contractName: Name of the contract to deploy (required for source compilation)
    ///   - abi: Contract ABI
    ///   - signer: Signer for the deployment transaction
    ///   - transport: Transport for RPC communication
    ///   - compiler: Solidity compiler instance for compiling source code
    public init(
        sourceCode: String,
        contractName: String,
        abi: [AbiItem],
        signer: Signer,
        transport: Transport,
        compiler: SolidityCompiler
    ) {
        self.sourceCode = sourceCode
        self.contractName = contractName
        self.bytecode = nil
        self.abi = abi
        self.signer = signer
        self.transport = transport
        self.compiler = compiler
    }

    /// Initialize with bytecode (already compiled)
    /// - Parameters:
    ///   - bytecode: Compiled contract bytecode (hex string)
    ///   - abi: Contract ABI
    ///   - signer: Signer for the deployment transaction
    ///   - transport: Transport for RPC communication
    public init(bytecode: String, abi: [AbiItem], signer: Signer, transport: Transport) {
        self.sourceCode = nil
        self.contractName = nil
        self.bytecode = bytecode
        self.abi = abi
        self.signer = signer
        self.transport = transport
        self.compiler = nil
    }

    /// Deploy the contract to the blockchain
    /// - Parameters:
    ///   - constructorArgs: Arguments for the constructor
    ///   - importCallback: Optional callback for resolving imports (used during compilation)
    ///   - value: Value to send with deployment (in wei)
    ///   - gasLimit: Optional gas limit
    ///   - gasPrice: Optional gas price
    /// - Returns: A deployed contract instance
    public func deploy(
        constructorArgs: [AnyCodable],
        importCallback: ImportCallback?,
        value: BigInt,
        gasLimit: BigInt?,
        gasPrice: BigInt?
    ) async throws -> Contract {
        // Get the bytecode (either provided or compile from source)
        let deployBytecode: String
        if let bytecode = self.bytecode {
            deployBytecode = bytecode
        } else if let sourceCode = self.sourceCode,
                  let contractName = self.contractName,
                  let compiler = self.compiler {
            // Compile the source code
            deployBytecode = try await compileContract(
                sourceCode: sourceCode,
                contractName: contractName,
                compiler: compiler,
                importCallback: importCallback
            )
        } else {
            throw DeploymentError.missingBytecode(
                "Either bytecode must be provided, or sourceCode with contractName and compiler"
            )
        }

        // Encode constructor arguments if any
        var deployData = deployBytecode.ensureHexPrefix()

        if !constructorArgs.isEmpty {
            // Find constructor in ABI
            guard let constructor = abi.first(where: { $0.type == .constructor }) else {
                throw DeploymentError.constructorNotFound("Constructor not found in ABI")
            }

            // Get constructor inputs
            let inputs = constructor.inputs ?? []

            // Validate argument count
            guard constructorArgs.count == inputs.count else {
                throw DeploymentError.encodingFailed(
                    "Constructor argument count mismatch: expected \(inputs.count), got \(constructorArgs.count)"
                )
            }

            // Encode constructor arguments
            let encodedArgs: String
            do {
                // Convert AnyCodable to Any
                let rawArgs = constructorArgs.map { $0.value }
                // Encode parameters directly
                encodedArgs = try encodeConstructorArguments(inputs: inputs, args: rawArgs)
            } catch {
                throw DeploymentError.encodingFailed("Failed to encode constructor arguments: \(error)")
            }

            // Append encoded arguments to bytecode
            deployData += encodedArgs.stripHexPrefix()
        }

        // Create transaction helper
        let txHelper = TransactionHelper(transport: transport)

        // Send deployment transaction
        let txHash: String
        do {
            txHash = try await txHelper.sendTransaction(
                from: signer.address,
                to: nil, // nil for contract deployment
                data: deployData,
                value: value,
                gas: gasLimit,
                gasPrice: gasPrice
            )
        } catch {
            throw DeploymentError.transactionFailed("Failed to send deployment transaction: \(error)")
        }

        // Wait for transaction receipt
        let receipt: TransactionReceipt
        do {
            receipt = try await txHelper.waitForReceipt(txHash: txHash)
        } catch {
            throw DeploymentError.transactionFailed("Failed to get transaction receipt: \(error)")
        }

        // Check if deployment was successful
        guard receipt.isSuccessful else {
            throw DeploymentError.deploymentFailed("Deployment transaction failed with status: \(receipt.status)")
        }

        // Extract contract address
        guard let contractAddressHex = receipt.contractAddress else {
            throw DeploymentError.missingContractAddress("Contract address not found in receipt")
        }

        let contractAddress = try Address(fromHexString: contractAddressHex)

        // Create and return deployed contract instance
        return EvmContract(
            address: contractAddress,
            abi: abi,
            signer: signer,
            transport: transport
        )
    }

    /// Compile Solidity source code and extract the bytecode
    /// - Parameters:
    ///   - sourceCode: Solidity source code
    ///   - contractName: Name of the contract to extract bytecode for
    ///   - compiler: Solidity compiler instance
    ///   - importCallback: Optional callback for resolving imports
    /// - Returns: Compiled bytecode as hex string
    private func compileContract(
        sourceCode: String,
        contractName: String,
        compiler: SolidityCompiler,
        importCallback: ImportCallback?
    ) async throws -> String {
        // Create compilation input
        let input = Input(
            language: "Solidity",
            sources: ["contract.sol": SourceIn(content: sourceCode)],
            settings: Settings(
                optimizer: Optimizer(enabled: true, runs: 200),
                outputSelection: [
                    "*": [
                        "*": ["abi", "evm.bytecode.object"]
                    ]
                ]
            )
        )

        // Compile
        let options = CompileOptions(importCallback: importCallback)
        let output: Output
        do {
            output = try await compiler.compile(input, options: options)
        } catch {
            throw DeploymentError.compilationFailed("Compilation failed: \(error)")
        }

        // Check for compilation errors
        if let errors = output.errors {
            let criticalErrors = errors.filter { $0.severity == "error" }
            if !criticalErrors.isEmpty {
                let errorMessages = criticalErrors.compactMap { $0.formattedMessage ?? $0.message }.joined(separator: "\n")
                throw DeploymentError.compilationFailed("Compilation errors:\n\(errorMessages)")
            }
        }

        // Extract bytecode
        guard let contracts = output.contracts,
              let fileContracts = contracts["contract.sol"],
              let contract = fileContracts[contractName],
              let evm = contract.evm,
              let bytecode = evm.bytecode,
              let bytecodeObject = bytecode.object else {
            throw DeploymentError.compilationFailed("Failed to extract bytecode from compilation output")
        }

        // Ensure bytecode is not empty
        guard !bytecodeObject.isEmpty else {
            throw DeploymentError.compilationFailed("Compiled bytecode is empty")
        }

        return bytecodeObject
    }
}

// MARK: - Constructor Argument Encoding Helper

/// Encode constructor arguments without function selector
/// - Parameters:
///   - inputs: The constructor input parameters
///   - args: The argument values to encode
/// - Returns: Hex-encoded constructor arguments
private func encodeConstructorArguments(inputs: [AbiParameter], args: [Any]) throws -> String {
    var encoded = Data()

    // Encode each parameter
    for (param, arg) in zip(inputs, args) {
        let encodedParam = try encodeParameter(type: param.type, value: arg)
        encoded.append(encodedParam)
    }

    return "0x" + encoded.map { String(format: "%02x", $0) }.joined()
}

/// Encode a single parameter value
private func encodeParameter(type: String, value: Any) throws -> Data {
    // Handle uint types
    if type.starts(with: "uint") {
        if let bigInt = value as? BigInt {
            return encodeUInt(bigInt)
        } else if let int = value as? Int {
            return encodeUInt(BigInt(int))
        } else if let uint = value as? UInt {
            return encodeUInt(BigInt(uint))
        }
        throw DeploymentError.encodingFailed("Invalid uint value")
    }

    // Handle address
    if type == "address" {
        if let addressStr = value as? String {
            let addr = try Address(fromHexString: addressStr)
            return encodeAddress(addr)
        } else if let addr = value as? Address {
            return encodeAddress(addr)
        }
        throw DeploymentError.encodingFailed("Invalid address value")
    }

    // Add more types as needed
    throw DeploymentError.encodingFailed("Unsupported parameter type: \(type)")
}

private func encodeUInt(_ value: BigInt) -> Data {
    let hex = String(value, radix: 16)
    let paddedHex = String(repeating: "0", count: 64 - hex.count) + hex
    return Data(hex: paddedHex)
}

private func encodeAddress(_ address: Address) -> Data {
    let hex = address.value.stripHexPrefix()
    let data = Data(hex: hex)
    // Pad to 32 bytes
    return Data(repeating: 0, count: 32 - data.count) + data
}

/// Errors that can occur during contract deployment
public enum DeploymentError: Error, LocalizedError {
    case missingBytecode(String)
    case constructorNotFound(String)
    case encodingFailed(String)
    case transactionFailed(String)
    case deploymentFailed(String)
    case missingContractAddress(String)
    case compilationNotSupported(String)
    case compilationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missingBytecode(let message):
            return "Missing bytecode: \(message)"
        case .constructorNotFound(let message):
            return "Constructor not found: \(message)"
        case .encodingFailed(let message):
            return "Encoding failed: \(message)"
        case .transactionFailed(let message):
            return "Transaction failed: \(message)"
        case .deploymentFailed(let message):
            return "Deployment failed: \(message)"
        case .missingContractAddress(let message):
            return "Missing contract address: \(message)"
        case .compilationNotSupported(let message):
            return "Compilation not supported: \(message)"
        case .compilationFailed(let message):
            return "Compilation failed: \(message)"
        }
    }
}

// MARK: - AbiFunction Extension for Parameter Encoding

extension AbiFunction {
    /// Encode function parameters without the function selector
    /// Used for constructor arguments
    func encodeParameters(args: [Any]) throws -> String {
        // Validate argument count
        guard args.count == inputs.count else {
            throw ContractError.argumentCountMismatch(expected: inputs.count, got: args.count)
        }

        // Use the existing encoding logic but without the selector
        var encoded = Data()

        // Encode each parameter
        for (param, arg) in zip(inputs, args) {
            let encodedParam = try encodeParameter(type: param.type, value: arg)
            encoded.append(encodedParam)
        }

        return "0x" + encoded.map { String(format: "%02x", $0) }.joined()
    }

    /// Encode a single parameter
    private func encodeParameter(type: String, value: Any) throws -> Data {
        // Parse the type
        let baseType: String
        let arrayDepth: Int

        if type.hasSuffix("[]") {
            // Dynamic array
            baseType = String(type.dropLast(2))
            arrayDepth = 1
        } else if type.contains("[") {
            // Fixed array - for simplicity, treat like dynamic
            let parts = type.split(separator: "[")
            baseType = String(parts[0])
            arrayDepth = 1
        } else {
            baseType = type
            arrayDepth = 0
        }

        // Handle arrays
        if arrayDepth > 0 {
            guard let array = value as? [Any] else {
                throw ContractError.encodingFailed(NSError(domain: "Expected array for type \(type)", code: -1))
            }

            var encoded = Data()

            // Encode length for dynamic arrays
            if type.hasSuffix("[]") {
                let lengthData = encodeUInt(BigInt(array.count))
                encoded.append(lengthData)
            }

            // Encode each element
            for element in array {
                let elementData = try encodeParameter(type: baseType, value: element)
                encoded.append(elementData)
            }

            return encoded
        }

        // Handle basic types
        switch baseType {
        case "address":
            if let addressStr = value as? String {
                let addr = try Address(fromHexString: addressStr)
                return encodeAddress(addr)
            } else if let addr = value as? Address {
                return encodeAddress(addr)
            }
            throw ContractError.encodingFailed(NSError(domain: "Invalid address value", code: -1))

        case let t where t.starts(with: "uint"):
            if let bigInt = value as? BigInt {
                return encodeUInt(bigInt)
            } else if let int = value as? Int {
                return encodeUInt(BigInt(int))
            } else if let uint = value as? UInt {
                return encodeUInt(BigInt(uint))
            }
            throw ContractError.encodingFailed(NSError(domain: "Invalid uint value", code: -1))

        case let t where t.starts(with: "int"):
            if let bigInt = value as? BigInt {
                return encodeInt(bigInt)
            } else if let int = value as? Int {
                return encodeInt(BigInt(int))
            }
            throw ContractError.encodingFailed(NSError(domain: "Invalid int value", code: -1))

        case "bool":
            if let bool = value as? Bool {
                return encodeBool(bool)
            }
            throw ContractError.encodingFailed(NSError(domain: "Invalid bool value", code: -1))

        case "string":
            if let str = value as? String {
                return try encodeString(str)
            }
            throw ContractError.encodingFailed(NSError(domain: "Invalid string value", code: -1))

        case "bytes":
            if let data = value as? Data {
                return try encodeBytes(data)
            } else if let hex = value as? String {
                let data = Data(hex: hex.stripHexPrefix())
                return try encodeBytes(data)
            }
            throw ContractError.encodingFailed(NSError(domain: "Invalid bytes value", code: -1))

        default:
            throw ContractError.encodingFailed(NSError(domain: "Unsupported type: \(baseType)", code: -1))
        }
    }

    // Encoding helpers
    private func encodeAddress(_ address: Address) -> Data {
        let hex = address.value.stripHexPrefix()
        let data = Data(hex: hex)
        // Pad to 32 bytes
        return Data(repeating: 0, count: 32 - data.count) + data
    }

    private func encodeUInt(_ value: BigInt) -> Data {
        let hex = String(value, radix: 16)
        let paddedHex = String(repeating: "0", count: 64 - hex.count) + hex
        return Data(hex: paddedHex)
    }

    private func encodeInt(_ value: BigInt) -> Data {
        // For simplicity, handle positive ints same as uint
        // Full implementation would handle two's complement for negative
        return encodeUInt(value)
    }

    private func encodeBool(_ value: Bool) -> Data {
        return encodeUInt(value ? 1 : 0)
    }

    private func encodeString(_ value: String) -> Data {
        let data = value.data(using: .utf8)!
        return try! encodeBytes(data)
    }

    private func encodeBytes(_ data: Data) -> Data {
        var result = Data()
        // Encode length
        result.append(encodeUInt(BigInt(data.count)))
        // Encode data with padding
        result.append(data)
        let remainder = data.count % 32
        if remainder != 0 {
            result.append(Data(repeating: 0, count: 32 - remainder))
        }
        return result
    }
}
