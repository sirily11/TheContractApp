import Foundation

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

/// Represents the type of an ABI item
public enum AbiItemType: String, Codable, Sendable {
    case function
    case constructor
    case receive
    case fallback
    case event
    case error
}

/// Represents a single ABI item (function, event, constructor, etc.)
public struct AbiItem: Codable, Equatable {
    public let type: AbiItemType
    public let name: String?
    public let inputs: [AbiParameter]?
    public let outputs: [AbiParameter]?
    public let stateMutability: StateMutability?
    public let anonymous: Bool?
    public let constant: Bool?
    public let payable: Bool?

    public init(
        type: AbiItemType,
        name: String? = nil,
        inputs: [AbiParameter]? = nil,
        outputs: [AbiParameter]? = nil,
        stateMutability: StateMutability? = nil,
        anonymous: Bool? = nil,
        constant: Bool? = nil,
        payable: Bool? = nil
    ) {
        self.type = type
        self.name = name
        self.inputs = inputs
        self.outputs = outputs
        self.stateMutability = stateMutability
        self.anonymous = anonymous
        self.constant = constant
        self.payable = payable
    }
}

/// Represents a function in a contract ABI with type-safe properties
public struct AbiFunction: Codable, Equatable {
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

/// Represents an event in a contract ABI with type-safe properties
public struct AbiEvent: Codable, Equatable {
    public let name: String
    public let inputs: [AbiParameter]
    public let anonymous: Bool

    public init(
        name: String,
        inputs: [AbiParameter] = [],
        anonymous: Bool = false
    ) {
        self.name = name
        self.inputs = inputs
        self.anonymous = anonymous
    }

    /// Convert this event to a generic AbiItem
    public func toAbiItem() -> AbiItem {
        AbiItem(
            type: .event,
            name: name,
            inputs: inputs,
            outputs: nil,
            stateMutability: nil,
            anonymous: anonymous,
            constant: nil,
            payable: nil
        )
    }

    /// Create an AbiEvent from an AbiItem if it represents an event
    /// - Parameter item: The AbiItem to convert
    /// - Throws: AbiParserError if the item is not an event or missing required fields
    public static func from(item: AbiItem) throws -> AbiEvent {
        guard item.type == .event else {
            throw AbiParserError.invalidItemType(expected: .event, got: item.type)
        }
        guard let name = item.name else {
            throw AbiParserError.missingRequiredField("name")
        }

        return AbiEvent(
            name: name,
            inputs: item.inputs ?? [],
            anonymous: item.anonymous ?? false
        )
    }
}

// MARK: - ABI Parser

/// Parses Ethereum contract ABIs from various sources
public class AbiParser {
    public let items: [AbiItem]

    // MARK: - Constructors

    /// Creates an ABI parser from an array of ABI items
    /// - Parameter items: Array of parsed ABI items
    public init(items: [AbiItem]) {
        self.items = items
    }

    /// Creates an ABI parser from a JSON string containing an ABI array
    /// - Parameter jsonString: JSON string representation of ABI array
    /// - Throws: Parsing errors if JSON is invalid
    public convenience init(fromJsonString jsonString: String) throws {
        guard let data = jsonString.data(using: .utf8) else {
            throw AbiParserError.invalidString
        }
        try self.init(fromData: data)
    }

    /// Creates an ABI parser from JSON data containing an ABI array
    /// - Parameter data: JSON data representation of ABI array
    /// - Throws: Parsing errors if JSON is invalid
    public convenience init(fromData data: Data) throws {
        let decoder = JSONDecoder()

        // Try to decode as array first (standard format)
        if let items = try? decoder.decode([AbiItem].self, from: data) {
            self.init(items: items)
            return
        }

        // Try to decode as single object
        if let item = try? decoder.decode(AbiItem.self, from: data) {
            self.init(items: [item])
            return
        }

        throw AbiParserError.invalidFormat
    }

    /// Creates an ABI parser from a file path
    /// - Parameter filePath: Path to JSON file containing ABI
    /// - Throws: File reading or parsing errors
    public convenience init(fromFile filePath: String) throws {
        let url = URL(fileURLWithPath: filePath)
        let data = try Data(contentsOf: url)
        try self.init(fromData: data)
    }

    /// Creates an ABI parser from a file URL
    /// - Parameter fileURL: URL to JSON file containing ABI
    /// - Throws: File reading or parsing errors
    public convenience init(fromFileURL fileURL: URL) throws {
        let data = try Data(contentsOf: fileURL)
        try self.init(fromData: data)
    }

    /// Creates an ABI parser from a single ABI object JSON string
    /// - Parameter objectString: JSON string of a single ABI item
    /// - Throws: Parsing errors if JSON is invalid
    public convenience init(fromObjectString objectString: String) throws {
        guard let data = objectString.data(using: .utf8) else {
            throw AbiParserError.invalidString
        }

        let decoder = JSONDecoder()
        let item = try decoder.decode(AbiItem.self, from: data)
        self.init(items: [item])
    }

    // MARK: - Query Methods

    /// Returns all functions in the ABI
    public var functions: [AbiItem] {
        items.filter { $0.type == .function }
    }

    /// Returns all events in the ABI
    public var events: [AbiItem] {
        items.filter { $0.type == .event }
    }

    /// Returns all errors in the ABI
    public var errors: [AbiItem] {
        items.filter { $0.type == .error }
    }

    /// Returns the constructor if present
    public var constructor: AbiItem? {
        items.first { $0.type == .constructor }
    }

    /// Finds a function by name
    /// - Parameter name: Name of the function
    /// - Returns: Array of matching functions (there can be overloads)
    public func function(named name: String) -> [AbiItem] {
        functions.filter { $0.name == name }
    }

    /// Finds an event by name
    /// - Parameter name: Name of the event
    /// - Returns: Array of matching events
    public func event(named name: String) -> [AbiItem] {
        events.filter { $0.name == name }
    }

    // MARK: - Strongly-Typed Query Methods

    /// Returns all functions as strongly-typed AbiFunction objects
    /// - Returns: Array of AbiFunction, skipping any invalid items
    public func typedFunctions() -> [AbiFunction] {
        functions.compactMap { try? AbiFunction.from(item: $0) }
    }

    /// Returns all events as strongly-typed AbiEvent objects
    /// - Returns: Array of AbiEvent, skipping any invalid items
    public func typedEvents() -> [AbiEvent] {
        events.compactMap { try? AbiEvent.from(item: $0) }
    }

    /// Finds a function by name and returns strongly-typed objects
    /// - Parameter name: Name of the function
    /// - Returns: Array of matching AbiFunction objects
    public func typedFunction(named name: String) -> [AbiFunction] {
        function(named: name).compactMap { try? AbiFunction.from(item: $0) }
    }

    /// Finds an event by name and returns strongly-typed objects
    /// - Parameter name: Name of the event
    /// - Returns: Array of matching AbiEvent objects
    public func typedEvent(named name: String) -> [AbiEvent] {
        event(named: name).compactMap { try? AbiEvent.from(item: $0) }
    }

    /// Converts the ABI back to JSON string
    /// - Parameter prettyPrinted: Whether to format the JSON
    /// - Returns: JSON string representation
    public func toJsonString(prettyPrinted: Bool = false) throws -> String {
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        let data = try encoder.encode(items)
        guard let string = String(data: data, encoding: .utf8) else {
            throw AbiParserError.encodingFailed
        }
        return string
    }

    /// Writes the ABI to a file
    /// - Parameters:
    ///   - filePath: Path to write the file
    ///   - prettyPrinted: Whether to format the JSON
    public func write(toFile filePath: String, prettyPrinted: Bool = true) throws {
        let jsonString = try toJsonString(prettyPrinted: prettyPrinted)
        guard let data = jsonString.data(using: .utf8) else {
            throw AbiParserError.encodingFailed
        }
        let url = URL(fileURLWithPath: filePath)
        try data.write(to: url)
    }
}

// MARK: - Convenience Extensions

extension AbiParser: CustomStringConvertible {
    public var description: String {
        """
        AbiParser:
          Functions: \(functions.count)
          Events: \(events.count)
          Errors: \(errors.count)
          Constructor: \(constructor != nil ? "Yes" : "No")
        """
    }
}
