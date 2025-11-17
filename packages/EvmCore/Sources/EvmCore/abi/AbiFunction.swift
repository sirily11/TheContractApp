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

        // Encode each argument
        var encodedParams = ""
        for (index, arg) in args.enumerated() {
            let param = inputs[index]
            let encoded = try encodeParameter(value: arg, type: param.type)
            encodedParams += encoded
        }

        return selector + encodedParams
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
        return param.type
    }

    private func encodeParameter(value: Any, type: String) throws -> String {
        // Handle different Solidity types
        switch type {
        case "address":
            return try encodeAddress(value)
        case let t where t.hasPrefix("uint"):
            return try encodeUint(value, bits: parseIntegerBits(t))
        case let t where t.hasPrefix("int"):
            return try encodeInt(value, bits: parseIntegerBits(t))
        case "bool":
            return try encodeBool(value)
        case "string":
            return try encodeString(value)
        case "bytes":
            return try encodeBytes(value)
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

    private func encodeString(_ value: Any) throws -> String {
        guard let str = value as? String else {
            throw AbiEncodingError.invalidValue(expected: "string", got: String(describing: value))
        }

        // Dynamic types require offset encoding - simplified for now
        guard let data = str.data(using: .utf8) else {
            throw AbiEncodingError.invalidValue(expected: "string", got: str)
        }

        return data.toHexString()
    }

    private func encodeBytes(_ value: Any) throws -> String {
        if let data = value as? Data {
            return data.toHexString()
        } else if let hex = value as? String {
            return hex.stripHexPrefix()
        } else {
            throw AbiEncodingError.invalidValue(expected: "bytes", got: String(describing: value))
        }
    }

    private func encodeFixedBytes(_ value: Any, size: Int) throws -> String {
        let hex = try encodeBytes(value)
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
