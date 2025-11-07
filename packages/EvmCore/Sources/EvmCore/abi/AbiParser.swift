import Foundation

// MARK: - ABI Data Models

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

/// Represents a wrapped ABI format where the ABI array is nested under an "abi" key
struct WrappedAbi: Codable {
    let abi: [AbiItem]
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

        // Try to decode as wrapped object with "abi" key
        if let wrappedAbi = try? decoder.decode(WrappedAbi.self, from: data) {
            self.init(items: wrappedAbi.abi)
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

    /// Converts the ABI to wrapped JSON string format with "abi" key
    /// - Parameter prettyPrinted: Whether to format the JSON
    /// - Returns: JSON string representation in wrapped format
    public func toWrappedJsonString(prettyPrinted: Bool = false) throws -> String {
        let wrapped = WrappedAbi(abi: items)
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        let data = try encoder.encode(wrapped)
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
