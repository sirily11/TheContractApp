//
//  TransactionParameter.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import EvmCore
import Foundation

// MARK: - SolidityType Enum

/// Represents Solidity data types with type-safe enum
enum SolidityType: Codable, Hashable, Sendable {
    case address
    case bool
    case string
    case bytes
    case bytesN(Int)  // bytes1-bytes32
    case uint(Int)    // uint8, uint256, etc.
    case int(Int)     // int8, int256, etc.
    indirect case array(elementType: SolidityType, fixedSize: Int?)
    case tuple(components: [TupleComponent])

    struct TupleComponent: Codable, Hashable, Identifiable, Sendable {
        var id: UUID
        var name: String
        var type: SolidityType

        init(id: UUID = UUID(), name: String, type: SolidityType) {
            self.id = id
            self.name = name
            self.type = type
        }
    }

    // MARK: - Parsing from String

    /// Parse a Solidity type string into a SolidityType enum
    /// - Parameter string: Type string like "uint256", "address[]", "tuple", etc.
    /// - Throws: ParsingError if the type string is invalid
    init(parsing string: String) throws {
        let trimmed = string.trimmingCharacters(in: .whitespaces)

        // Check for array types
        if trimmed.hasSuffix("[]") {
            // Dynamic array
            let elementTypeString = String(trimmed.dropLast(2))
            let elementType = try SolidityType(parsing: elementTypeString)
            self = .array(elementType: elementType, fixedSize: nil)
            return
        } else if trimmed.contains("[") && trimmed.hasSuffix("]") {
            // Fixed-size array
            if let bracketIndex = trimmed.lastIndex(of: "[") {
                let elementTypeString = String(trimmed[..<bracketIndex])
                let sizeString = String(trimmed[trimmed.index(after: bracketIndex)..<trimmed.index(before: trimmed.endIndex)])

                guard let size = Int(sizeString), size > 0 else {
                    throw ParsingError.invalidArraySize(sizeString)
                }

                let elementType = try SolidityType(parsing: elementTypeString)
                self = .array(elementType: elementType, fixedSize: size)
                return
            }
        }

        // Check for basic types
        switch trimmed {
        case "address":
            self = .address
        case "bool":
            self = .bool
        case "string":
            self = .string
        case "bytes":
            self = .bytes
        case "tuple":
            // For tuple, components should be provided separately
            self = .tuple(components: [])
        default:
            // Check for sized types
            if trimmed.hasPrefix("bytes") {
                let sizeString = String(trimmed.dropFirst(5))
                guard let size = Int(sizeString), size >= 1, size <= 32 else {
                    throw ParsingError.invalidBytesSize(sizeString)
                }
                self = .bytesN(size)
            } else if trimmed.hasPrefix("uint") {
                let sizeString = String(trimmed.dropFirst(4))
                if sizeString.isEmpty {
                    self = .uint(256) // Default uint is uint256
                } else {
                    guard let size = Int(sizeString), size % 8 == 0, size >= 8, size <= 256 else {
                        throw ParsingError.invalidUintSize(sizeString)
                    }
                    self = .uint(size)
                }
            } else if trimmed.hasPrefix("int") {
                let sizeString = String(trimmed.dropFirst(3))
                if sizeString.isEmpty {
                    self = .int(256) // Default int is int256
                } else {
                    guard let size = Int(sizeString), size % 8 == 0, size >= 8, size <= 256 else {
                        throw ParsingError.invalidIntSize(sizeString)
                    }
                    self = .int(size)
                }
            } else {
                throw ParsingError.unknownType(trimmed)
            }
        }
    }

    // MARK: - Display String

    /// Convert the type to a display string (e.g., "uint256", "address[]")
    var displayString: String {
        switch self {
        case .address:
            return "address"
        case .bool:
            return "bool"
        case .string:
            return "string"
        case .bytes:
            return "bytes"
        case .bytesN(let size):
            return "bytes\(size)"
        case .uint(let size):
            return "uint\(size)"
        case .int(let size):
            return "int\(size)"
        case .array(let elementType, let fixedSize):
            if let size = fixedSize {
                return "\(elementType.displayString)[\(size)]"
            } else {
                return "\(elementType.displayString)[]"
            }
        case .tuple:
            return "tuple"
        }
    }

    // MARK: - Parsing Errors

    enum ParsingError: LocalizedError {
        case unknownType(String)
        case invalidArraySize(String)
        case invalidBytesSize(String)
        case invalidUintSize(String)
        case invalidIntSize(String)

        var errorDescription: String? {
            switch self {
            case .unknownType(let type):
                return "Unknown Solidity type: \(type)"
            case .invalidArraySize(let size):
                return "Invalid array size: \(size)"
            case .invalidBytesSize(let size):
                return "Invalid bytes size: \(size) (must be 1-32)"
            case .invalidUintSize(let size):
                return "Invalid uint size: \(size) (must be 8-256, multiple of 8)"
            case .invalidIntSize(let size):
                return "Invalid int size: \(size) (must be 8-256, multiple of 8)"
            }
        }
    }
}

// MARK: - TransactionParameter

/// Represents a parameter for a smart contract function call
struct TransactionParameter: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = .init()
    var name: String
    var type: SolidityType
    var value: AnyCodable

    init(id: UUID = UUID(), name: String, type: SolidityType, value: AnyCodable) {
        self.id = id
        self.name = name
        self.type = type
        self.value = value
    }

    /// Convenience initializer for parsing type from string
    init(id: UUID = UUID(), name: String, typeString: String, value: AnyCodable) throws {
        self.id = id
        self.name = name
        self.type = try SolidityType(parsing: typeString)
        self.value = value
    }
}

// MARK: - Sample Data for Previews

extension TransactionParameter {
    static let sampleTransfer: [TransactionParameter] = [
        TransactionParameter(
            name: "to",
            type: .address,
            value: .init("0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")
        ),
        TransactionParameter(
            name: "amount",
            type: .uint(256),
            value: .init("1000000000000000000")
        )
    ]

    static let sampleApprove: [TransactionParameter] = [
        TransactionParameter(
            name: "spender",
            type: .address,
            value: .init("0x1234567890abcdef1234567890abcdef12345678")
        ),
        TransactionParameter(
            name: "amount",
            type: .uint(256),
            value: .init("5000000000000000000")
        )
    ]

    static let sampleSwap: [TransactionParameter] = [
        TransactionParameter(
            name: "tokenIn",
            type: .address,
            value: .init("0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2")
        ),
        TransactionParameter(
            name: "tokenOut",
            type: .address,
            value: .init("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48")
        ),
        TransactionParameter(
            name: "amountIn",
            type: .uint(256),
            value: .init("2000000000000000000")
        ),
        TransactionParameter(
            name: "amountOutMin",
            type: .uint(256),
            value: .init("3000000000")
        ),
        TransactionParameter(
            name: "deadline",
            type: .uint(256),
            value: .init("1699999999")
        )
    ]

    // Sample with different types for testing
    static let sampleAllTypes: [TransactionParameter] = [
        TransactionParameter(name: "addr", type: .address, value: .init("0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")),
        TransactionParameter(name: "flag", type: .bool, value: .init(true)),
        TransactionParameter(name: "message", type: .string, value: .init("Hello, World!")),
        TransactionParameter(name: "amount", type: .uint(256), value: .init("1000000000000000000")),
        TransactionParameter(name: "balance", type: .int(256), value: .init("-500")),
        TransactionParameter(name: "data", type: .bytes, value: .init("0x1234")),
        TransactionParameter(name: "hash", type: .bytesN(32), value: .init("0x0000000000000000000000000000000000000000000000000000000000000000"))
    ]
}
