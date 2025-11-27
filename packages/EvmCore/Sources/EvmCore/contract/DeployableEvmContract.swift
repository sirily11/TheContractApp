import BigInt
import Foundation
import Solidity

/// A contract that can be deployed to the blockchain
public struct DeployableEvmContract: DeployableContract {
    public let sourceCode: String?
    public let contractName: String?
    public let bytecode: String?
    public let abi: [AbiItem]
    public let evmSigner: EvmClientWithSigner
    public let compiler: SolidityCompiler?

    /// Computed property that returns the signer from evmSigner
    public var signer: Signer {
        return evmSigner.signer
    }

    /// Initialize with source code (will be compiled during deployment)
    /// - Parameters:
    ///   - sourceCode: Solidity source code
    ///   - contractName: Name of the contract to deploy (required for source compilation)
    ///   - abi: Contract ABI
    ///   - evmSigner: EVM client with signer for the deployment transaction
    ///   - compiler: Solidity compiler instance for compiling source code
    public init(
        sourceCode: String,
        contractName: String,
        abi: [AbiItem],
        evmSigner: EvmClientWithSigner,
        compiler: SolidityCompiler
    ) {
        self.sourceCode = sourceCode
        self.contractName = contractName
        self.bytecode = nil
        self.abi = abi
        self.evmSigner = evmSigner
        self.compiler = compiler
    }

    /// Initialize with bytecode (already compiled)
    /// - Parameters:
    ///   - bytecode: Compiled contract bytecode (hex string)
    ///   - abi: Contract ABI
    ///   - evmSigner: EVM client with signer for the deployment transaction
    public init(bytecode: String, abi: [AbiItem], evmSigner: EvmClientWithSigner) {
        self.sourceCode = nil
        self.contractName = nil
        self.bytecode = bytecode
        self.abi = abi
        self.evmSigner = evmSigner
        self.compiler = nil
    }

    /// Deploy the contract to the blockchain
    /// - Parameters:
    ///   - constructorArgs: Arguments for the constructor
    ///   - importCallback: Optional callback for resolving imports (used during compilation)
    ///   - value: Value to send with deployment
    ///   - gasLimit: Optional gas limit
    ///   - gasPrice: Optional gas price (in gwei)
    /// - Returns: A deployed contract instance
    public func deploy(
        constructorArgs: [AnyCodable],
        importCallback: ImportCallback?,
        value: TransactionValue,
        gasLimit: GasLimit?,
        gasPrice: Gwei?
    ) async throws -> (Contract, String) {
        // Get the bytecode (either provided or compile from source)
        let deployBytecode: String
        if let bytecode = self.bytecode {
            deployBytecode = bytecode
        } else if let sourceCode = self.sourceCode,
            let contractName = self.contractName,
            let compiler = self.compiler
        {
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

        // Validate bytecode is not empty
        guard !deployBytecode.isEmpty && deployBytecode.stripHexPrefix().count > 0 else {
            throw DeploymentError.missingBytecode("Bytecode cannot be empty")
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
                throw DeploymentError.encodingFailed(
                    "Failed to encode constructor arguments: \(error)")
            }

            // Append encoded arguments to bytecode
            deployData += encodedArgs.stripHexPrefix()
        }

        // Send deployment transaction
        let pendingTransaction = try await evmSigner.signAndSendTransaction(
            params: .init(
                from: signer.address.value,
                to: nil,
                gas: gasLimit,
                gasPrice: gasPrice,
                maxFeePerGas: nil,
                maxPriorityFeePerGas: nil,
                value: value,
                data: deployData,
                nonce: nil
            )
        )
        let receipt = try await pendingTransaction.wait()

        // Extract contract address
        guard let contractAddressHex = receipt.contractAddress else {
            throw DeploymentError.missingContractAddress("Contract address not found in receipt")
        }

        let contractAddress = try Address(fromHexString: contractAddressHex)

        // Create and return deployed contract instance
        return (EvmContract(
            address: contractAddress,
            abi: abi,
            evmSigner: evmSigner
        ), receipt.transactionHash)
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
                let errorMessages = criticalErrors.compactMap { $0.formattedMessage ?? $0.message }
                    .joined(separator: "\n")
                throw DeploymentError.compilationFailed("Compilation errors:\n\(errorMessages)")
            }
        }

        // Extract bytecode
        guard let contracts = output.contracts,
            let fileContracts = contracts["contract.sol"],
            let contract = fileContracts[contractName],
            let evm = contract.evm,
            let bytecode = evm.bytecode,
            let bytecodeObject = bytecode.object
        else {
            throw DeploymentError.compilationFailed(
                "Failed to extract bytecode from compilation output")
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
    // Separate static and dynamic parameters
    var staticParts: [Data] = []
    var dynamicParts: [Data] = []
    var dynamicOffsets: [Int] = []

    // First pass: identify static vs dynamic and calculate offsets
    var currentOffset = calculateHeadSize(params: inputs)

    for (param, arg) in zip(inputs, args) {
        if isDynamicType(param.type, components: param.components) {
            // For dynamic types, static part is the offset
            dynamicOffsets.append(currentOffset)
            let dynamicData = try encodeParameter(param: param, value: arg)
            dynamicParts.append(dynamicData)
            currentOffset += dynamicData.count
            staticParts.append(Data())  // Placeholder, will be replaced with offset
        } else {
            // For static types, encode directly
            let staticData = try encodeParameter(param: param, value: arg)
            staticParts.append(staticData)
            dynamicOffsets.append(-1)  // Not a dynamic type
        }
    }

    // Second pass: replace dynamic placeholders with actual offsets
    for i in 0..<staticParts.count {
        if dynamicOffsets[i] >= 0 {
            staticParts[i] = encodeUInt(BigInt(dynamicOffsets[i]))
        }
    }

    // Combine static and dynamic parts
    var encoded = Data()
    for part in staticParts {
        encoded.append(part)
    }
    for part in dynamicParts {
        encoded.append(part)
    }

    return "0x" + encoded.map { String(format: "%02x", $0) }.joined()
}

/// Calculate the head size for a list of parameters
private func calculateHeadSize(params: [AbiParameter]) -> Int {
    var size = 0
    for param in params {
        if isDynamicType(param.type, components: param.components) {
            // Dynamic types take 32 bytes for offset in head
            size += 32
        } else if param.type == "tuple", let components = param.components {
            // Static tuple: sum of component sizes
            size += calculateHeadSize(params: components)
        } else if let (_, arraySize) = parseFixedArraySize(param.type) {
            // Fixed array of static types
            size += 32 * arraySize
        } else {
            // Static types take 32 bytes
            size += 32
        }
    }
    return size
}

/// Parse fixed array size from type string like "uint256[5]"
private func parseFixedArraySize(_ type: String) -> (elementType: String, size: Int)? {
    guard let match = type.range(of: #"\[(\d+)\]$"#, options: .regularExpression) else {
        return nil
    }

    let elementType = String(type[..<match.lowerBound])
    let sizeStr = String(type[match]).dropFirst().dropLast() // Remove [ and ]
    guard let size = Int(sizeStr) else {
        return nil
    }

    return (elementType, size)
}

/// Check if a type is dynamic (requires offset encoding)
private func isDynamicType(_ type: String, components: [AbiParameter]? = nil) -> Bool {
    // Dynamic types: string, bytes
    if type == "string" || type == "bytes" {
        return true
    }

    // Dynamic arrays (T[])
    if type.hasSuffix("[]") {
        return true
    }

    // Fixed-size arrays of dynamic types (T[k] where T is dynamic)
    if let (elementType, _) = parseFixedArraySize(type) {
        return isDynamicType(elementType, components: components)
    }

    // Tuples containing dynamic types
    if type == "tuple" || type.hasPrefix("tuple["), let components = components {
        return components.contains { isDynamicType($0.type, components: $0.components) }
    }

    return false
}

// MARK: - Master Parameter Encoding

/// Encode a parameter value based on its ABI parameter definition
private func encodeParameter(param: AbiParameter, value: Any) throws -> Data {
    let type = param.type

    // Handle tuples (structs)
    if type == "tuple" {
        guard let components = param.components else {
            throw DeploymentError.encodingFailed("Tuple without components")
        }
        return try encodeTuple(value: value, components: components)
    }

    // Handle tuple arrays (e.g., "tuple[]", "tuple[3]")
    if type.hasPrefix("tuple[") {
        return try encodeTupleArray(value: value, param: param)
    }

    // Handle dynamic arrays (T[])
    if type.hasSuffix("[]") {
        let elementType = String(type.dropLast(2))
        return try encodeDynamicArray(value: value, elementType: elementType, elementComponents: param.components)
    }

    // Handle fixed arrays (T[k])
    if let (elementType, size) = parseFixedArraySize(type) {
        return try encodeFixedArray(value: value, elementType: elementType, size: size, elementComponents: param.components)
    }

    // Handle dynamic types
    if type == "string" {
        if let str = value as? String {
            return encodeStringData(str)
        }
        throw DeploymentError.encodingFailed("Invalid string value")
    }

    if type == "bytes" {
        if let data = value as? Data {
            return encodeBytesData(data)
        } else if let hex = value as? String {
            return encodeBytesData(Data(hex: hex.stripHexPrefix()))
        }
        throw DeploymentError.encodingFailed("Invalid bytes value")
    }

    // Handle static types
    return try encodeStaticParameter(type: type, value: value)
}

// MARK: - Array Encoding

/// Encode a dynamic array (T[])
private func encodeDynamicArray(value: Any, elementType: String, elementComponents: [AbiParameter]?) throws -> Data {
    guard let array = value as? [Any] else {
        throw DeploymentError.encodingFailed("Expected array for dynamic array type")
    }

    // Encode length prefix
    var result = encodeUInt(BigInt(array.count))

    // Check if element type is dynamic
    let elementIsDynamic = isDynamicType(elementType, components: elementComponents)

    if elementIsDynamic {
        // Dynamic elements: encode offsets in head, then data in tail
        var offsets: [Int] = []
        var tails: [Data] = []
        var currentOffset = array.count * 32

        for element in array {
            offsets.append(currentOffset)
            let elementParam = AbiParameter(name: "", type: elementType, components: elementComponents)
            let encoded = try encodeParameter(param: elementParam, value: element)
            tails.append(encoded)
            currentOffset += encoded.count
        }

        // Append offsets
        for offset in offsets {
            result.append(encodeUInt(BigInt(offset)))
        }

        // Append data
        for tail in tails {
            result.append(tail)
        }
    } else {
        // Static elements: encode each element directly
        for element in array {
            let elementParam = AbiParameter(name: "", type: elementType, components: elementComponents)
            result.append(try encodeParameter(param: elementParam, value: element))
        }
    }

    return result
}

/// Encode a fixed-size array (T[k])
private func encodeFixedArray(value: Any, elementType: String, size: Int, elementComponents: [AbiParameter]?) throws -> Data {
    guard let array = value as? [Any] else {
        throw DeploymentError.encodingFailed("Expected array for fixed array type")
    }

    guard array.count == size else {
        throw DeploymentError.encodingFailed("Expected array of size \(size), got \(array.count)")
    }

    // Check if element type is dynamic
    let elementIsDynamic = isDynamicType(elementType, components: elementComponents)

    if elementIsDynamic {
        // Fixed array of dynamic types: similar to dynamic array but without length prefix
        var offsets: [Int] = []
        var tails: [Data] = []
        var currentOffset = size * 32

        for element in array {
            offsets.append(currentOffset)
            let elementParam = AbiParameter(name: "", type: elementType, components: elementComponents)
            let encoded = try encodeParameter(param: elementParam, value: element)
            tails.append(encoded)
            currentOffset += encoded.count
        }

        var result = Data()
        for offset in offsets {
            result.append(encodeUInt(BigInt(offset)))
        }
        for tail in tails {
            result.append(tail)
        }
        return result
    } else {
        // Fixed array of static types: encode each element directly
        var result = Data()
        for element in array {
            let elementParam = AbiParameter(name: "", type: elementType, components: elementComponents)
            result.append(try encodeParameter(param: elementParam, value: element))
        }
        return result
    }
}

// MARK: - Tuple Encoding

/// Encode a tuple (struct)
private func encodeTuple(value: Any, components: [AbiParameter]) throws -> Data {
    guard let values = value as? [Any] else {
        throw DeploymentError.encodingFailed("Expected array of values for tuple")
    }

    guard values.count == components.count else {
        throw DeploymentError.encodingFailed("Tuple component count mismatch: expected \(components.count), got \(values.count)")
    }

    // Check if tuple contains any dynamic types
    let hasDynamicComponents = components.contains { isDynamicType($0.type, components: $0.components) }

    if hasDynamicComponents {
        // Dynamic tuple: head (static values + offsets) + tail (dynamic data)
        var head = Data()
        var tail = Data()
        var currentOffset = calculateHeadSize(params: components)

        for (component, val) in zip(components, values) {
            if isDynamicType(component.type, components: component.components) {
                // Add offset to head
                head.append(encodeUInt(BigInt(currentOffset)))

                // Add data to tail
                let encoded = try encodeParameter(param: component, value: val)
                tail.append(encoded)
                currentOffset += encoded.count
            } else {
                // Add static value to head
                head.append(try encodeParameter(param: component, value: val))
            }
        }

        return head + tail
    } else {
        // Static tuple: encode all components sequentially
        var result = Data()
        for (component, val) in zip(components, values) {
            result.append(try encodeParameter(param: component, value: val))
        }
        return result
    }
}

/// Encode a tuple array (tuple[] or tuple[k])
private func encodeTupleArray(value: Any, param: AbiParameter) throws -> Data {
    guard let components = param.components else {
        throw DeploymentError.encodingFailed("Tuple array without components")
    }

    let type = param.type

    // Check if it's a dynamic or fixed tuple array
    if type == "tuple[]" {
        return try encodeDynamicArray(value: value, elementType: "tuple", elementComponents: components)
    } else if let (_, size) = parseFixedArraySize(type) {
        return try encodeFixedArray(value: value, elementType: "tuple", size: size, elementComponents: components)
    } else {
        throw DeploymentError.encodingFailed("Unsupported tuple array type: \(type)")
    }
}

/// Encode a static parameter (fixed size)
private func encodeStaticParameter(type: String, value: Any) throws -> Data {
    if type.starts(with: "uint") {
        if let bigInt = value as? BigInt {
            return encodeUInt(bigInt)
        } else if let int = value as? Int {
            return encodeUInt(BigInt(int))
        } else if let uint = value as? UInt {
            return encodeUInt(BigInt(uint))
        } else if let string = value as? String {
            // Support string values for uint types (e.g., "1000000")
            if let bigInt = BigInt(string) {
                return encodeUInt(bigInt)
            }
        }
        throw DeploymentError.encodingFailed("Invalid uint value")
    }

    if type.starts(with: "int") {
        if let bigInt = value as? BigInt {
            return encodeInt(bigInt)
        } else if let int = value as? Int {
            return encodeInt(BigInt(int))
        } else if let string = value as? String {
            // Support string values for int types (e.g., "-1000000")
            if let bigInt = BigInt(string) {
                return encodeInt(bigInt)
            }
        }
        throw DeploymentError.encodingFailed("Invalid int value")
    }

    if type == "address" {
        if let addressStr = value as? String {
            let addr = try Address(fromHexString: addressStr)
            return encodeAddress(addr)
        } else if let addr = value as? Address {
            return encodeAddress(addr)
        }
        throw DeploymentError.encodingFailed("Invalid address value")
    }

    if type == "bool" {
        if let bool = value as? Bool {
            return encodeBool(bool)
        }
        throw DeploymentError.encodingFailed("Invalid bool value")
    }

    // Handle fixed bytes (bytes1, bytes2, ..., bytes32)
    if type.starts(with: "bytes") {
        let sizeStr = type.dropFirst(5)  // Remove "bytes" prefix
        if let size = Int(sizeStr), size >= 1, size <= 32 {
            return try encodeFixedBytes(value: value, size: size)
        }
    }

    throw DeploymentError.encodingFailed("Unsupported static parameter type: \(type)")
}

/// Encode a dynamic parameter (variable size)
private func encodeDynamicParameter(type: String, value: Any) throws -> Data {
    if type == "string" {
        if let str = value as? String {
            return encodeStringData(str)
        }
        throw DeploymentError.encodingFailed("Invalid string value")
    }

    if type == "bytes" {
        if let data = value as? Data {
            return encodeBytesData(data)
        } else if let hex = value as? String {
            let data = Data(hex: hex.stripHexPrefix())
            return encodeBytesData(data)
        }
        throw DeploymentError.encodingFailed("Invalid bytes value")
    }

    // Handle dynamic arrays (e.g., uint256[], address[], etc.)
    if type.hasSuffix("[]") {
        guard let array = value as? [Any] else {
            throw DeploymentError.encodingFailed("Expected array for type \(type)")
        }

        // Extract element type (remove the [] suffix)
        let elementType = String(type.dropLast(2))

        // Encode array length
        var encoded = encodeUInt(BigInt(array.count))

        // Encode each element
        for element in array {
            let elementData: Data
            // Check if element type is static or dynamic
            if isDynamicType(elementType) {
                elementData = try encodeDynamicParameter(type: elementType, value: element)
            } else {
                elementData = try encodeStaticParameter(type: elementType, value: element)
            }
            encoded.append(elementData)
        }

        return encoded
    }

    throw DeploymentError.encodingFailed("Unsupported dynamic parameter type: \(type)")
}

// MARK: - Encoding Helper Functions

private func encodeUInt(_ value: BigInt) -> Data {
    let hex = String(value, radix: 16)
    let paddedHex = String(repeating: "0", count: 64 - hex.count) + hex
    return Data(hex: paddedHex)
}

private func encodeInt(_ value: BigInt) -> Data {
    if value >= 0 {
        return encodeUInt(value)
    } else {
        // Two's complement for negative numbers
        // For 256-bit signed integer, negative value n is represented as 2^256 + n
        let maxUint256 = BigInt(2).power(256)
        let twosComplement = maxUint256 + value
        return encodeUInt(twosComplement)
    }
}

private func encodeAddress(_ address: Address) -> Data {
    let hex = address.value.stripHexPrefix()
    let data = Data(hex: hex)
    // Pad to 32 bytes
    return Data(repeating: 0, count: 32 - data.count) + data
}

private func encodeBool(_ value: Bool) -> Data {
    return encodeUInt(value ? 1 : 0)
}

private func encodeFixedBytes(value: Any, size: Int) throws -> Data {
    var bytes: Data
    if let data = value as? Data {
        bytes = data
    } else if let hex = value as? String {
        bytes = Data(hex: hex.stripHexPrefix())
    } else if let byteArray = value as? [UInt8] {
        bytes = Data(byteArray)
    } else {
        throw DeploymentError.encodingFailed("Invalid bytes\(size) value")
    }

    guard bytes.count <= size else {
        throw DeploymentError.encodingFailed("bytes\(size) value too large: \(bytes.count) bytes")
    }

    // Right-pad to 32 bytes
    var result = bytes
    if result.count < size {
        result.append(Data(repeating: 0, count: size - result.count))
    }
    result.append(Data(repeating: 0, count: 32 - size))
    return result
}

private func encodeStringData(_ value: String) -> Data {
    let data = value.data(using: .utf8)!
    return encodeBytesData(data)
}

private func encodeBytesData(_ data: Data) -> Data {
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
                throw ContractError.encodingFailed(
                    NSError(domain: "Expected array for type \(type)", code: -1))
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
            } else if let string = value as? String {
                // Support string values for uint types (e.g., "1000000")
                if let bigInt = BigInt(string) {
                    return encodeUInt(bigInt)
                }
            }
            throw ContractError.encodingFailed(NSError(domain: "Invalid uint value", code: -1))

        case let t where t.starts(with: "int"):
            if let bigInt = value as? BigInt {
                return encodeInt(bigInt)
            } else if let int = value as? Int {
                return encodeInt(BigInt(int))
            } else if let string = value as? String {
                // Support string values for int types (e.g., "-1000000")
                if let bigInt = BigInt(string) {
                    return encodeInt(bigInt)
                }
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
            throw ContractError.encodingFailed(
                NSError(domain: "Unsupported type: \(baseType)", code: -1))
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
