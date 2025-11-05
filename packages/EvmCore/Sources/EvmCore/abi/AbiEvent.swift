import Foundation

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
