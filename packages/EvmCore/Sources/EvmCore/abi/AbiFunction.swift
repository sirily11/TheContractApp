import Foundation
import CryptoSwift
import BigInt

// MARK: - ABI Data Models

/// Represents an ABI parameter
public struct AbiParameter: Codable, Equatable {
    public let name: String
    public let type: String
    public let indexed: Bool?
    public let components: [AbiParameter]?
    public let internalType: String?

    enum CodingKeys: String, CodingKey {
        case name, type, indexed, components
        case internalType = "internalType"
    }

    public init(
        name: String, type: String, indexed: Bool? = nil, components: [AbiParameter]? = nil,
        internalType: String? = nil
    ) {
        self.name = name
        self.type = type
        self.indexed = indexed
        self.components = components
        self.internalType = internalType
    }
}

/// Represents the state mutability of a function
public enum StateMutability: String, Codable {
    case pure
    case view
    case nonpayable
    case payable
}

/// Represents a function in a contract ABI with type-safe properties
public struct AbiFunction: Codable, Equatable, Identifiable {
    public var id: String { signature() }

    public let name: String
    public let inputs: [AbiParameter]
    public let outputs: [AbiParameter]
    public let stateMutability: StateMutability
    public let constant: Bool?
    public let payable: Bool?

    public init(
        name: String,
        inputs: [AbiParameter] = [],
        outputs: [AbiParameter] = [],
        stateMutability: StateMutability,
        constant: Bool? = nil,
        payable: Bool? = nil
    ) {
        self.name = name
        self.inputs = inputs
        self.outputs = outputs
        self.stateMutability = stateMutability
        self.constant = constant
        self.payable = payable
    }

    /// Convert this function to a generic AbiItem
    public func toAbiItem() -> AbiItem {
        AbiItem(
            type: .function,
            name: name,
            inputs: inputs,
            outputs: outputs,
            stateMutability: stateMutability,
            anonymous: nil,
            constant: constant,
            payable: payable
        )
    }

    /// Create an AbiFunction from an AbiItem if it represents a function
    /// - Parameter item: The AbiItem to convert
    /// - Throws: AbiParserError if the item is not a function or missing required fields
    public static func from(item: AbiItem) throws -> AbiFunction {
        guard item.type == .function else {
            throw AbiParserError.invalidItemType(expected: .function, got: item.type)
        }
        guard let name = item.name else {
            throw AbiParserError.missingRequiredField("name")
        }
        guard let stateMutability = item.stateMutability else {
            throw AbiParserError.missingRequiredField("stateMutability")
        }

        return AbiFunction(
            name: name,
            inputs: item.inputs ?? [],
            outputs: item.outputs ?? [],
            stateMutability: stateMutability,
            constant: item.constant,
            payable: item.payable
        )
    }
}

// MARK: - ABI Encoding/Decoding

extension AbiFunction {
    /// Calculate the function signature string (e.g., "transfer(address,uint256)")
    public func signature() -> String {
        let paramTypes = inputs.map { formatType($0) }.joined(separator: ",")
        return "\(name)(\(paramTypes))"
    }

    /// Calculate the function selector (first 4 bytes of keccak256 hash of signature)
    public func selector() throws -> String {
        let sig = signature()
        guard let sigData = sig.data(using: .utf8) else {
            throw AbiEncodingError.invalidSignature
        }

        let hash = sigData.sha3(.keccak256)
        let selector = hash.prefix(4)
        return "0x" + selector.toHexString()
    }

    /// Encode a function call with the given arguments
    /// - Parameter args: Array of arguments matching the function inputs
    /// - Returns: Hex string of encoded call data (selector + encoded params)
    public func encodeCall(args: [Any]) throws -> String {
        guard args.count == inputs.count else {
            throw AbiEncodingError.argumentCountMismatch(
                expected: inputs.count,
                got: args.count
            )
        }

        let selector = try selector()

        // If no arguments, return just the selector
        if args.isEmpty {
            return selector
        }

        // ABI encoding has two sections:
        // 1. Head: contains static values or offsets to dynamic data
        // 2. Tail: contains the actual dynamic data

        var headParts: [String] = []
        var tailParts: [String] = []

        // Calculate the starting offset for dynamic data
        // Each parameter takes 32 bytes (64 hex chars) in the head
        var currentTailOffset = calculateHeadSize(params: inputs)

        for (index, arg) in args.enumerated() {
            let param = inputs[index]

            if isDynamicType(param.type, components: param.components) {
                // For dynamic types, put offset in head and data in tail
                let offsetHex = String(currentTailOffset, radix: 16)
                let paddedOffset = String(repeating: "0", count: 64 - offsetHex.count) + offsetHex
                headParts.append(paddedOffset)

                // Encode the dynamic data
                let dynamicData = try encodeParameter(value: arg, param: param)
                tailParts.append(dynamicData)

                // Update offset for next dynamic data (dynamicData length in bytes)
                currentTailOffset += dynamicData.count / 2
            } else {
                // For static types, encode directly in head
                let encoded = try encodeParameter(value: arg, param: param)
                headParts.append(encoded)
            }
        }

        return selector + headParts.joined() + tailParts.joined()
    }

    /// Calculate the head size for a list of parameters
    /// For static types, this is 32 bytes each
    /// For dynamic types, this is 32 bytes (for the offset)
    /// For static tuples, this is the sum of component sizes
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

    /// Check if a type is dynamic (variable length)
    /// - Parameters:
    ///   - type: The Solidity type string
    ///   - components: Optional components for tuple types
    /// - Returns: True if the type is dynamic (variable length)
    private func isDynamicType(_ type: String, components: [AbiParameter]? = nil) -> Bool {
        // Dynamic types: string, bytes
        if type == "string" || type == "bytes" {
            return true
        }

        // Dynamic array (ends with [])
        if type.hasSuffix("[]") {
            return true
        }

        // Fixed-size arrays of dynamic types (T[k] where T is dynamic)
        if let match = type.range(of: #"\[\d+\]$"#, options: .regularExpression) {
            let elementType = String(type[..<match.lowerBound])
            return isDynamicType(elementType, components: components)
        }

        // Tuples containing dynamic types
        if type == "tuple", let components = components {
            return components.contains { isDynamicType($0.type, components: $0.components) }
        }

        return false
    }

    /// Parse fixed array size from type string like "uint256[5]"
    /// - Parameter type: The type string with array notation
    /// - Returns: Tuple of (elementType, arraySize) or nil if not a fixed array
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

    /// Decode function return data
    /// - Parameter data: Hex string of return data
    /// - Returns: Decoded result as specified type
    public func decodeResult<T: Codable>(data: String) throws -> T {
        let cleanData = data.stripHexPrefix()

        guard outputs.count > 0 else {
            throw AbiEncodingError.noOutputs
        }

        // For now, we'll implement a basic decoder that handles simple types
        // A full implementation would need to handle all Solidity types

        // Single return value
        if outputs.count == 1 {
            let output = outputs[0]
            let decoded = try decodeParameter(data: cleanData, type: output.type, offset: 0)

            // Try to convert to expected type directly
            if let result = decoded as? T {
                return result
            }

            // Handle conversion for numeric types to BigInt
            if T.self == BigInt.self {
                if let uint = decoded as? UInt64 {
                    return BigInt(uint) as! T
                } else if let int = decoded as? Int64 {
                    return BigInt(int) as! T
                }
            }

            // For other types, wrap in array for JSON serialization
            let jsonData = try JSONSerialization.data(withJSONObject: [decoded])
            let array = try JSONDecoder().decode([T].self, from: jsonData)
            guard let result = array.first else {
                throw AbiEncodingError.decodingFailed("Failed to decode result")
            }
            return result
        }

        // Multiple return values - return as tuple/array
        var results: [Any] = []
        var offset = 0

        for output in outputs {
            let decoded = try decodeParameter(data: cleanData, type: output.type, offset: offset)
            results.append(decoded)
            offset += 64 // Each param takes 32 bytes (64 hex chars)
        }

        // Try to convert to expected type
        let jsonData = try JSONSerialization.data(withJSONObject: results)
        return try JSONDecoder().decode(T.self, from: jsonData)
    }

    // MARK: - Private Helpers

    private func formatType(_ param: AbiParameter) -> String {
        if param.type == "tuple", let components = param.components {
            let componentTypes = components.map { formatType($0) }.joined(separator: ",")
            return "(\(componentTypes))"
        }
        // Handle tuple arrays like "tuple[]"
        if param.type.hasPrefix("tuple") && param.type.contains("["), let components = param.components {
            let componentTypes = components.map { formatType($0) }.joined(separator: ",")
            let arraySuffix = String(param.type.dropFirst(5)) // Remove "tuple" prefix
            return "(\(componentTypes))\(arraySuffix)"
        }
        return param.type
    }

    // MARK: - Master Encoding Method

    /// Encode a parameter value based on its ABI parameter definition
    /// This is the main entry point for encoding any Solidity type
    private func encodeParameter(value: Any, param: AbiParameter) throws -> String {
        let type = param.type

        // Handle tuples (structs)
        if type == "tuple" {
            guard let components = param.components else {
                throw AbiEncodingError.unsupportedType("tuple without components")
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
            return try encodeStringDynamic(value)
        }
        if type == "bytes" {
            return try encodeBytesDynamic(value)
        }

        // Handle static types
        return try encodeStaticParameter(value: value, type: type)
    }

    // MARK: - Array Encoding

    /// Encode a dynamic array (T[])
    /// Format: length (32 bytes) + encoded elements
    private func encodeDynamicArray(value: Any, elementType: String, elementComponents: [AbiParameter]?) throws -> String {
        guard let array = value as? [Any] else {
            throw AbiEncodingError.invalidValue(expected: "array", got: String(describing: value))
        }

        // Encode length prefix (32 bytes)
        let lengthHex = String(array.count, radix: 16)
        var result = String(repeating: "0", count: 64 - lengthHex.count) + lengthHex

        // Check if element type is dynamic
        let elementIsDynamic = isDynamicType(elementType, components: elementComponents)

        if elementIsDynamic {
            // Dynamic elements: encode offsets in head, then data in tail
            var offsets: [Int] = []
            var tails: [String] = []
            var currentOffset = array.count * 32 // Start after all offset slots

            for element in array {
                offsets.append(currentOffset)
                let elementParam = AbiParameter(name: "", type: elementType, components: elementComponents)
                let encoded = try encodeParameter(value: element, param: elementParam)
                tails.append(encoded)
                currentOffset += encoded.count / 2 // Convert hex chars to bytes
            }

            // Append offsets
            for offset in offsets {
                let offsetHex = String(offset, radix: 16)
                result += String(repeating: "0", count: 64 - offsetHex.count) + offsetHex
            }

            // Append data
            for tail in tails {
                result += tail
            }
        } else {
            // Static elements: encode each element directly
            for element in array {
                let elementParam = AbiParameter(name: "", type: elementType, components: elementComponents)
                result += try encodeParameter(value: element, param: elementParam)
            }
        }

        return result
    }

    /// Encode a fixed-size array (T[k])
    private func encodeFixedArray(value: Any, elementType: String, size: Int, elementComponents: [AbiParameter]?) throws -> String {
        guard let array = value as? [Any] else {
            throw AbiEncodingError.invalidValue(expected: "array[\(size)]", got: String(describing: value))
        }

        guard array.count == size else {
            throw AbiEncodingError.invalidValue(expected: "array[\(size)]", got: "array[\(array.count)]")
        }

        // Check if element type is dynamic
        let elementIsDynamic = isDynamicType(elementType, components: elementComponents)

        if elementIsDynamic {
            // Fixed array of dynamic types: similar to dynamic array but without length prefix
            var offsets: [Int] = []
            var tails: [String] = []
            var currentOffset = size * 32

            for element in array {
                offsets.append(currentOffset)
                let elementParam = AbiParameter(name: "", type: elementType, components: elementComponents)
                let encoded = try encodeParameter(value: element, param: elementParam)
                tails.append(encoded)
                currentOffset += encoded.count / 2
            }

            var result = ""
            for offset in offsets {
                let offsetHex = String(offset, radix: 16)
                result += String(repeating: "0", count: 64 - offsetHex.count) + offsetHex
            }
            for tail in tails {
                result += tail
            }
            return result
        } else {
            // Fixed array of static types: encode each element directly
            var result = ""
            for element in array {
                let elementParam = AbiParameter(name: "", type: elementType, components: elementComponents)
                result += try encodeParameter(value: element, param: elementParam)
            }
            return result
        }
    }

    // MARK: - Tuple Encoding

    /// Encode a tuple (struct)
    /// Format: For static tuples, concatenate all encoded values
    ///         For dynamic tuples, use head (values/offsets) + tail (dynamic data)
    private func encodeTuple(value: Any, components: [AbiParameter]) throws -> String {
        guard let values = value as? [Any] else {
            throw AbiEncodingError.invalidValue(expected: "tuple (array of values)", got: String(describing: value))
        }

        guard values.count == components.count else {
            throw AbiEncodingError.argumentCountMismatch(expected: components.count, got: values.count)
        }

        // Check if tuple contains any dynamic types
        let hasDynamicComponents = components.contains { isDynamicType($0.type, components: $0.components) }

        if hasDynamicComponents {
            // Dynamic tuple: head (static values + offsets) + tail (dynamic data)
            var head = ""
            var tail = ""
            var currentOffset = calculateHeadSize(params: components)

            for (component, val) in zip(components, values) {
                if isDynamicType(component.type, components: component.components) {
                    // Add offset to head
                    let offsetHex = String(currentOffset, radix: 16)
                    head += String(repeating: "0", count: 64 - offsetHex.count) + offsetHex

                    // Add data to tail
                    let encoded = try encodeParameter(value: val, param: component)
                    tail += encoded
                    currentOffset += encoded.count / 2
                } else {
                    // Add static value to head
                    head += try encodeParameter(value: val, param: component)
                }
            }

            return head + tail
        } else {
            // Static tuple: encode all components sequentially
            var result = ""
            for (component, val) in zip(components, values) {
                result += try encodeParameter(value: val, param: component)
            }
            return result
        }
    }

    /// Encode a tuple array (tuple[] or tuple[k])
    private func encodeTupleArray(value: Any, param: AbiParameter) throws -> String {
        guard let components = param.components else {
            throw AbiEncodingError.unsupportedType("tuple array without components")
        }

        let type = param.type

        // Check if it's a dynamic or fixed tuple array
        if type == "tuple[]" {
            // Dynamic tuple array
            return try encodeDynamicArray(value: value, elementType: "tuple", elementComponents: components)
        } else if let (_, size) = parseFixedArraySize(type) {
            // Fixed tuple array
            return try encodeFixedArray(value: value, elementType: "tuple", size: size, elementComponents: components)
        } else {
            throw AbiEncodingError.unsupportedType(type)
        }
    }

    // MARK: - Static Type Encoding

    /// Encode a static (fixed-size) parameter
    private func encodeStaticParameter(value: Any, type: String) throws -> String {
        switch type {
        case "address":
            return try encodeAddress(value)
        case let t where t.hasPrefix("uint"):
            return try encodeUint(value, bits: parseIntegerBits(t))
        case let t where t.hasPrefix("int"):
            return try encodeInt(value, bits: parseIntegerBits(t))
        case "bool":
            return try encodeBool(value)
        case let t where t.hasPrefix("bytes") && t.count > 5:
            // Fixed bytes (bytes1, bytes32, etc.)
            return try encodeFixedBytes(value, size: parseFixedBytesSize(t))
        default:
            throw AbiEncodingError.unsupportedType(type)
        }
    }

    private func decodeParameter(data: String, type: String, offset: Int) throws -> Any {
        let start = offset
        let end = start + 64 // 32 bytes = 64 hex chars

        guard data.count >= end else {
            throw AbiEncodingError.insufficientData
        }

        let slice = String(data[data.index(data.startIndex, offsetBy: start)..<data.index(data.startIndex, offsetBy: end)])

        switch type {
        case "address":
            return try decodeAddress(slice)
        case let t where t.hasPrefix("uint"):
            return try decodeUint(slice)
        case let t where t.hasPrefix("int"):
            return try decodeInt(slice)
        case "bool":
            return try decodeBool(slice)
        case "string":
            return try decodeString(data, offset: offset)
        case "bytes":
            return try decodeDynamicBytes(data, offset: offset)
        default:
            throw AbiEncodingError.unsupportedType(type)
        }
    }

    // MARK: - Encoding Functions

    private func encodeAddress(_ value: Any) throws -> String {
        let addressString: String

        if let addr = value as? String {
            addressString = addr
        } else if let addr = value as? Address {
            addressString = addr.value
        } else {
            throw AbiEncodingError.invalidValue(expected: "address", got: String(describing: value))
        }

        let cleanAddress = addressString.stripHexPrefix()
        guard cleanAddress.count == 40 else {
            throw AbiEncodingError.invalidAddressLength
        }

        // Pad to 32 bytes (64 hex chars)
        return String(repeating: "0", count: 24) + cleanAddress
    }

    private func encodeUint(_ value: Any, bits: Int) throws -> String {
        let hexValue: String

        switch value {
        case let v as BigInt:
            hexValue = String(v, radix: 16)
        case let v as Int:
            hexValue = String(UInt64(v), radix: 16)
        case let v as UInt:
            hexValue = String(UInt64(v), radix: 16)
        case let v as UInt64:
            hexValue = String(v, radix: 16)
        case let v as String:
            guard let parsed = UInt64(v) else {
                throw AbiEncodingError.invalidValue(expected: "uint", got: v)
            }
            hexValue = String(parsed, radix: 16)
        default:
            throw AbiEncodingError.invalidValue(expected: "uint", got: String(describing: value))
        }

        // Pad to 32 bytes (64 hex chars)
        let padding = max(0, 64 - hexValue.count)
        return String(repeating: "0", count: padding) + hexValue
    }

    private func encodeInt(_ value: Any, bits: Int) throws -> String {
        // For simplicity, treating signed ints similar to unsigned
        // A full implementation would handle two's complement
        return try encodeUint(value, bits: bits)
    }

    private func encodeBool(_ value: Any) throws -> String {
        let boolValue: Bool

        if let v = value as? Bool {
            boolValue = v
        } else if let v = value as? Int {
            boolValue = v != 0
        } else {
            throw AbiEncodingError.invalidValue(expected: "bool", got: String(describing: value))
        }

        return String(repeating: "0", count: 63) + (boolValue ? "1" : "0")
    }

    /// Encode a string for dynamic ABI encoding
    /// Returns: length (32 bytes) + data (padded to 32-byte boundary)
    private func encodeStringDynamic(_ value: Any) throws -> String {
        guard let str = value as? String else {
            throw AbiEncodingError.invalidValue(expected: "string", got: String(describing: value))
        }

        guard let data = str.data(using: .utf8) else {
            throw AbiEncodingError.invalidValue(expected: "string", got: str)
        }

        // Encode length (32 bytes)
        let lengthHex = String(data.count, radix: 16)
        let paddedLength = String(repeating: "0", count: 64 - lengthHex.count) + lengthHex

        // Encode data with padding to 32-byte boundary
        let dataHex = data.toHexString()
        let paddingNeeded = (32 - (data.count % 32)) % 32
        let paddedData = dataHex + String(repeating: "0", count: paddingNeeded * 2)

        return paddedLength + paddedData
    }

    /// Encode bytes for dynamic ABI encoding
    /// Returns: length (32 bytes) + data (padded to 32-byte boundary)
    private func encodeBytesDynamic(_ value: Any) throws -> String {
        let data: Data
        if let d = value as? Data {
            data = d
        } else if let hex = value as? String {
            data = Data(hex: hex.stripHexPrefix())
        } else {
            throw AbiEncodingError.invalidValue(expected: "bytes", got: String(describing: value))
        }

        // Encode length (32 bytes)
        let lengthHex = String(data.count, radix: 16)
        let paddedLength = String(repeating: "0", count: 64 - lengthHex.count) + lengthHex

        // Encode data with padding to 32-byte boundary
        let dataHex = data.toHexString()
        let paddingNeeded = (32 - (data.count % 32)) % 32
        let paddedData = dataHex + String(repeating: "0", count: paddingNeeded * 2)

        return paddedLength + paddedData
    }

    private func encodeFixedBytes(_ value: Any, size: Int) throws -> String {
        let hex: String
        if let data = value as? Data {
            hex = data.toHexString()
        } else if let hexStr = value as? String {
            hex = hexStr.stripHexPrefix()
        } else {
            throw AbiEncodingError.invalidValue(expected: "bytes\(size)", got: String(describing: value))
        }

        guard hex.count <= size * 2 else {
            throw AbiEncodingError.invalidValue(expected: "bytes\(size)", got: hex)
        }

        // Pad to 32 bytes on the right
        let padding = 64 - hex.count
        return hex + String(repeating: "0", count: padding)
    }

    // MARK: - Decoding Functions

    private func decodeAddress(_ hex: String) throws -> String {
        // Address is last 20 bytes (40 hex chars)
        let cleanHex = hex.stripHexPrefix()
        guard cleanHex.count >= 40 else {
            throw AbiEncodingError.invalidAddressLength
        }

        let start = cleanHex.index(cleanHex.endIndex, offsetBy: -40)
        let address = String(cleanHex[start...])
        return "0x" + address
    }

    private func decodeUint(_ hex: String) throws -> UInt64 {
        let cleanHex = hex.stripHexPrefix()
        guard let value = UInt64(cleanHex, radix: 16) else {
            throw AbiEncodingError.invalidHexString
        }
        return value
    }

    private func decodeInt(_ hex: String) throws -> Int64 {
        // Simplified - a full implementation would handle two's complement
        let uint = try decodeUint(hex)
        return Int64(uint)
    }

    private func decodeBool(_ hex: String) throws -> Bool {
        let value = try decodeUint(hex)
        return value != 0
    }

    private func decodeString(_ data: String, offset: Int) throws -> String {
        // For a single return value that's a string, the data structure is:
        // 0-31: offset to string data (usually 0x20 = 32)
        // 32-63: length of string in bytes
        // 64+: actual string data (UTF-8 encoded, padded to 32-byte boundary)

        let cleanData = data.stripHexPrefix()

        // Read the offset (first 32 bytes)
        guard cleanData.count >= 64 else {
            throw AbiEncodingError.insufficientData
        }

        let offsetHex = String(cleanData.prefix(64))
        guard let dataOffset = UInt64(offsetHex, radix: 16) else {
            throw AbiEncodingError.invalidHexString
        }

        // Read the length at the offset position
        let lengthStart = Int(dataOffset) * 2 // Convert bytes to hex chars
        guard cleanData.count >= lengthStart + 64 else {
            throw AbiEncodingError.insufficientData
        }

        let lengthStartIndex = cleanData.index(cleanData.startIndex, offsetBy: lengthStart)
        let lengthEndIndex = cleanData.index(lengthStartIndex, offsetBy: 64)
        let lengthHex = String(cleanData[lengthStartIndex..<lengthEndIndex])

        guard let length = UInt64(lengthHex, radix: 16) else {
            throw AbiEncodingError.invalidHexString
        }

        // Read the actual string data
        let dataStart = lengthStart + 64
        let dataLength = Int(length) * 2 // Convert bytes to hex chars

        guard cleanData.count >= dataStart + dataLength else {
            throw AbiEncodingError.insufficientData
        }

        let dataStartIndex = cleanData.index(cleanData.startIndex, offsetBy: dataStart)
        let dataEndIndex = cleanData.index(dataStartIndex, offsetBy: dataLength)
        let stringHex = String(cleanData[dataStartIndex..<dataEndIndex])

        // Convert hex to bytes and then to string
        let stringData = Data(hex: stringHex)
        guard let result = String(data: stringData, encoding: .utf8) else {
            throw AbiEncodingError.decodingFailed("Failed to decode string from UTF-8")
        }

        return result
    }

    private func decodeDynamicBytes(_ data: String, offset: Int) throws -> Data {
        // Similar to string decoding but without UTF-8 conversion
        let cleanData = data.stripHexPrefix()

        // Read the offset (first 32 bytes)
        guard cleanData.count >= 64 else {
            throw AbiEncodingError.insufficientData
        }

        let offsetHex = String(cleanData.prefix(64))
        guard let dataOffset = UInt64(offsetHex, radix: 16) else {
            throw AbiEncodingError.invalidHexString
        }

        // Read the length at the offset position
        let lengthStart = Int(dataOffset) * 2
        guard cleanData.count >= lengthStart + 64 else {
            throw AbiEncodingError.insufficientData
        }

        let lengthStartIndex = cleanData.index(cleanData.startIndex, offsetBy: lengthStart)
        let lengthEndIndex = cleanData.index(lengthStartIndex, offsetBy: 64)
        let lengthHex = String(cleanData[lengthStartIndex..<lengthEndIndex])

        guard let length = UInt64(lengthHex, radix: 16) else {
            throw AbiEncodingError.invalidHexString
        }

        // Read the actual bytes data
        let dataStart = lengthStart + 64
        let dataLength = Int(length) * 2

        guard cleanData.count >= dataStart + dataLength else {
            throw AbiEncodingError.insufficientData
        }

        let dataStartIndex = cleanData.index(cleanData.startIndex, offsetBy: dataStart)
        let dataEndIndex = cleanData.index(dataStartIndex, offsetBy: dataLength)
        let bytesHex = String(cleanData[dataStartIndex..<dataEndIndex])

        return Data(hex: bytesHex)
    }

    // MARK: - Utility Functions

    private func parseIntegerBits(_ type: String) -> Int {
        let numStr = type.replacingOccurrences(of: "uint", with: "").replacingOccurrences(of: "int", with: "")
        return Int(numStr) ?? 256
    }

    private func parseFixedBytesSize(_ type: String) -> Int {
        let numStr = type.replacingOccurrences(of: "bytes", with: "")
        return Int(numStr) ?? 32
    }
}

// MARK: - Encoding Errors

public enum AbiEncodingError: Error, LocalizedError {
    case invalidSignature
    case argumentCountMismatch(expected: Int, got: Int)
    case unsupportedType(String)
    case invalidValue(expected: String, got: String)
    case invalidAddressLength
    case invalidHexString
    case insufficientData
    case noOutputs
    case decodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidSignature:
            return "Invalid function signature"
        case .argumentCountMismatch(let expected, let got):
            return "Argument count mismatch: expected \(expected), got \(got)"
        case .unsupportedType(let type):
            return "Unsupported type: \(type)"
        case .invalidValue(let expected, let got):
            return "Invalid value: expected \(expected), got \(got)"
        case .invalidAddressLength:
            return "Invalid address length"
        case .invalidHexString:
            return "Invalid hex string"
        case .insufficientData:
            return "Insufficient data for decoding"
        case .noOutputs:
            return "Function has no outputs to decode"
        case .decodingFailed(let message):
            return "Decoding failed: \(message)"
        }
    }
}

// MARK: - Helper Extensions

extension String {
    func stripHexPrefix() -> String {
        if self.hasPrefix("0x") || self.hasPrefix("0X") {
            return String(self.dropFirst(2))
        }
        return self
    }

    func ensureHexPrefix() -> String {
        if self.hasPrefix("0x") || self.hasPrefix("0X") {
            return self
        }
        return "0x" + self
    }
}

extension Data {
    func toHexString() -> String {
        return self.map { String(format: "%02x", $0) }.joined()
    }

    init(hex: String) {
        var data = Data()
        var hex = hex

        // Ensure even number of characters
        if hex.count % 2 != 0 {
            hex = "0" + hex
        }

        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            if let byte = UInt8(hex[index..<nextIndex], radix: 16) {
                data.append(byte)
            }
            index = nextIndex
        }

        self = data
    }
}
