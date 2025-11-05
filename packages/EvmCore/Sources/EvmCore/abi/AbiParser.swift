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
public enum AbiItemType: String, Codable {
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

// MARK: - Errors

public enum AbiParserError: Error, LocalizedError {
    case invalidString
    case invalidFormat
    case encodingFailed
    case fileNotFound

    public var errorDescription: String? {
        switch self {
        case .invalidString:
            return "Invalid string encoding"
        case .invalidFormat:
            return "Invalid ABI format - must be a JSON array or object"
        case .encodingFailed:
            return "Failed to encode ABI to JSON"
        case .fileNotFound:
            return "ABI file not found"
        }
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
