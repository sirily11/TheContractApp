import Foundation

public struct AnyCodable: Codable, @unchecked Sendable, Equatable, Hashable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable value cannot be decoded"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let int8 as Int8:
            try container.encode(int8)
        case let int16 as Int16:
            try container.encode(int16)
        case let int32 as Int32:
            try container.encode(int32)
        case let int64 as Int64:
            try container.encode(int64)
        case let uint as UInt:
            try container.encode(uint)
        case let uint8 as UInt8:
            try container.encode(uint8)
        case let uint16 as UInt16:
            try container.encode(uint16)
        case let uint32 as UInt32:
            try container.encode(uint32)
        case let uint64 as UInt64:
            try container.encode(uint64)
        case let float as Float:
            try container.encode(float)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        case let encodable as Encodable:
            try encodable.encode(to: encoder)
        default:
            let context = EncodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "AnyCodable value cannot be encoded"
            )
            throw EncodingError.invalidValue(value, context)
        }
    }

    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case (is NSNull, is NSNull):
            return true
        case (let lhsBool as Bool, let rhsBool as Bool):
            return lhsBool == rhsBool
        case (let lhsInt as Int, let rhsInt as Int):
            return lhsInt == rhsInt
        case (let lhsInt8 as Int8, let rhsInt8 as Int8):
            return lhsInt8 == rhsInt8
        case (let lhsInt16 as Int16, let rhsInt16 as Int16):
            return lhsInt16 == rhsInt16
        case (let lhsInt32 as Int32, let rhsInt32 as Int32):
            return lhsInt32 == rhsInt32
        case (let lhsInt64 as Int64, let rhsInt64 as Int64):
            return lhsInt64 == rhsInt64
        case (let lhsUInt as UInt, let rhsUInt as UInt):
            return lhsUInt == rhsUInt
        case (let lhsUInt8 as UInt8, let rhsUInt8 as UInt8):
            return lhsUInt8 == rhsUInt8
        case (let lhsUInt16 as UInt16, let rhsUInt16 as UInt16):
            return lhsUInt16 == rhsUInt16
        case (let lhsUInt32 as UInt32, let rhsUInt32 as UInt32):
            return lhsUInt32 == rhsUInt32
        case (let lhsUInt64 as UInt64, let rhsUInt64 as UInt64):
            return lhsUInt64 == rhsUInt64
        case (let lhsFloat as Float, let rhsFloat as Float):
            return lhsFloat == rhsFloat
        case (let lhsDouble as Double, let rhsDouble as Double):
            return lhsDouble == rhsDouble
        case (let lhsString as String, let rhsString as String):
            return lhsString == rhsString
        case (let lhsArray as [Any], let rhsArray as [Any]):
            guard lhsArray.count == rhsArray.count else { return false }
            return zip(lhsArray, rhsArray).allSatisfy { AnyCodable($0) == AnyCodable($1) }
        case (let lhsDict as [String: Any], let rhsDict as [String: Any]):
            guard lhsDict.count == rhsDict.count else { return false }
            return lhsDict.allSatisfy { key, lhsValue in
                guard let rhsValue = rhsDict[key] else { return false }
                return AnyCodable(lhsValue) == AnyCodable(rhsValue)
            }
        default:
            return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch value {
        case is NSNull:
            hasher.combine(0)
        case let bool as Bool:
            hasher.combine(bool)
        case let int as Int:
            hasher.combine(int)
        case let int8 as Int8:
            hasher.combine(int8)
        case let int16 as Int16:
            hasher.combine(int16)
        case let int32 as Int32:
            hasher.combine(int32)
        case let int64 as Int64:
            hasher.combine(int64)
        case let uint as UInt:
            hasher.combine(uint)
        case let uint8 as UInt8:
            hasher.combine(uint8)
        case let uint16 as UInt16:
            hasher.combine(uint16)
        case let uint32 as UInt32:
            hasher.combine(uint32)
        case let uint64 as UInt64:
            hasher.combine(uint64)
        case let float as Float:
            hasher.combine(float)
        case let double as Double:
            hasher.combine(double)
        case let string as String:
            hasher.combine(string)
        case let array as [Any]:
            hasher.combine(array.count)
            for element in array {
                AnyCodable(element).hash(into: &hasher)
            }
        case let dictionary as [String: Any]:
            hasher.combine(dictionary.count)
            // Sort keys for consistent hashing
            for key in dictionary.keys.sorted() {
                hasher.combine(key)
                if let value = dictionary[key] {
                    AnyCodable(value).hash(into: &hasher)
                }
            }
        default:
            // For types we can't hash, use a sentinel value
            hasher.combine(Int.min)
        }
    }

    /// Converts the wrapped value to a string representation
    public func toString() -> String {
        switch value {
        case is NSNull:
            return "null"
        case let bool as Bool:
            return String(bool)
        case let int as Int:
            return String(int)
        case let int8 as Int8:
            return String(int8)
        case let int16 as Int16:
            return String(int16)
        case let int32 as Int32:
            return String(int32)
        case let int64 as Int64:
            return String(int64)
        case let uint as UInt:
            return String(uint)
        case let uint8 as UInt8:
            return String(uint8)
        case let uint16 as UInt16:
            return String(uint16)
        case let uint32 as UInt32:
            return String(uint32)
        case let uint64 as UInt64:
            return String(uint64)
        case let float as Float:
            return String(float)
        case let double as Double:
            return String(double)
        case let string as String:
            return string
        case let array as [Any]:
            let elements = array.map { AnyCodable($0).toString() }
            return "[\(elements.joined(separator: ", "))]"
        case let dictionary as [String: Any]:
            let pairs = dictionary.map { key, value in
                "\"\(key)\": \(AnyCodable(value).toString())"
            }.sorted()
            return "{\(pairs.joined(separator: ", "))}"
        default:
            return String(describing: value)
        }
    }
}
