import Testing
import Foundation
@testable import EvmCore

/// Tests for AnyCodable type
@Suite("AnyCodable Tests")
struct AnyCodableTests {

    // MARK: - Initialization Tests

    @Test("Initialize with string value")
    func testInitWithString() {
        let anyCodable = AnyCodable("hello")
        #expect(anyCodable.value as? String == "hello")
    }

    @Test("Initialize with int value")
    func testInitWithInt() {
        let anyCodable = AnyCodable(42)
        #expect(anyCodable.value as? Int == 42)
    }

    @Test("Initialize with bool value")
    func testInitWithBool() {
        let anyCodable = AnyCodable(true)
        #expect(anyCodable.value as? Bool == true)
    }

    @Test("Initialize with double value")
    func testInitWithDouble() {
        let anyCodable = AnyCodable(3.14)
        #expect(anyCodable.value as? Double == 3.14)
    }

    @Test("Initialize with array value")
    func testInitWithArray() {
        let anyCodable = AnyCodable([1, 2, 3])
        #expect(anyCodable.value as? [Int] != nil)
    }

    @Test("Initialize with dictionary value")
    func testInitWithDictionary() {
        let anyCodable = AnyCodable(["key": "value"])
        #expect(anyCodable.value as? [String: String] != nil)
    }

    // MARK: - Decoding Tests

    @Test("Decode null value")
    func testDecodeNull() throws {
        let json = "null"
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let anyCodable = try decoder.decode(AnyCodable.self, from: data)

        #expect(anyCodable.value is NSNull)
    }

    @Test("Decode boolean true")
    func testDecodeTrue() throws {
        let json = "true"
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let anyCodable = try decoder.decode(AnyCodable.self, from: data)

        #expect(anyCodable.value as? Bool == true)
    }

    @Test("Decode boolean false")
    func testDecodeFalse() throws {
        let json = "false"
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let anyCodable = try decoder.decode(AnyCodable.self, from: data)

        #expect(anyCodable.value as? Bool == false)
    }

    @Test("Decode integer")
    func testDecodeInt() throws {
        let json = "123"
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let anyCodable = try decoder.decode(AnyCodable.self, from: data)

        #expect(anyCodable.value as? Int == 123)
    }

    @Test("Decode negative integer")
    func testDecodeNegativeInt() throws {
        let json = "-456"
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let anyCodable = try decoder.decode(AnyCodable.self, from: data)

        #expect(anyCodable.value as? Int == -456)
    }

    @Test("Decode double")
    func testDecodeDouble() throws {
        let json = "3.14159"
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let anyCodable = try decoder.decode(AnyCodable.self, from: data)

        #expect(anyCodable.value as? Double == 3.14159)
    }

    @Test("Decode string")
    func testDecodeString() throws {
        let json = "\"hello world\""
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let anyCodable = try decoder.decode(AnyCodable.self, from: data)

        #expect(anyCodable.value as? String == "hello world")
    }

    @Test("Decode array")
    func testDecodeArray() throws {
        let json = "[1, 2, 3, 4, 5]"
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let anyCodable = try decoder.decode(AnyCodable.self, from: data)

        let array = anyCodable.value as? [Any]
        #expect(array?.count == 5)
    }

    @Test("Decode mixed array")
    func testDecodeMixedArray() throws {
        let json = "[1, \"hello\", true, null]"
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let anyCodable = try decoder.decode(AnyCodable.self, from: data)

        let array = anyCodable.value as? [Any]
        #expect(array?.count == 4)
    }

    @Test("Decode dictionary")
    func testDecodeDictionary() throws {
        let json = """
        {"name": "John", "age": 30, "active": true}
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let anyCodable = try decoder.decode(AnyCodable.self, from: data)

        let dict = anyCodable.value as? [String: Any]
        #expect(dict?["name"] as? String == "John")
        #expect(dict?["age"] as? Int == 30)
        #expect(dict?["active"] as? Bool == true)
    }

    @Test("Decode nested structure")
    func testDecodeNestedStructure() throws {
        let json = """
        {
            "user": {
                "name": "Alice",
                "scores": [95, 87, 92]
            }
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let anyCodable = try decoder.decode(AnyCodable.self, from: data)

        let dict = anyCodable.value as? [String: Any]
        let user = dict?["user"] as? [String: Any]
        #expect(user?["name"] as? String == "Alice")
    }

    // MARK: - Encoding Tests

    @Test("Encode null value")
    func testEncodeNull() throws {
        let anyCodable = AnyCodable(NSNull())
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)
        let json = String(data: data, encoding: .utf8)!

        #expect(json == "null")
    }

    @Test("Encode boolean")
    func testEncodeBool() throws {
        let anyCodable = AnyCodable(true)
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)
        let json = String(data: data, encoding: .utf8)!

        #expect(json == "true")
    }

    @Test("Encode integer")
    func testEncodeInt() throws {
        let anyCodable = AnyCodable(42)
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)
        let json = String(data: data, encoding: .utf8)!

        #expect(json == "42")
    }

    @Test("Encode Int8")
    func testEncodeInt8() throws {
        let anyCodable = AnyCodable(Int8(127))
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)
        let json = String(data: data, encoding: .utf8)!

        #expect(json == "127")
    }

    @Test("Encode Int16")
    func testEncodeInt16() throws {
        let anyCodable = AnyCodable(Int16(32767))
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)
        let json = String(data: data, encoding: .utf8)!

        #expect(json == "32767")
    }

    @Test("Encode Int32")
    func testEncodeInt32() throws {
        let anyCodable = AnyCodable(Int32(2147483647))
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)
        let json = String(data: data, encoding: .utf8)!

        #expect(json == "2147483647")
    }

    @Test("Encode Int64")
    func testEncodeInt64() throws {
        let anyCodable = AnyCodable(Int64(9223372036854775807))
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)
        let json = String(data: data, encoding: .utf8)!

        #expect(json == "9223372036854775807")
    }

    @Test("Encode UInt")
    func testEncodeUInt() throws {
        let anyCodable = AnyCodable(UInt(42))
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)
        let json = String(data: data, encoding: .utf8)!

        #expect(json == "42")
    }

    @Test("Encode UInt8")
    func testEncodeUInt8() throws {
        let anyCodable = AnyCodable(UInt8(255))
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)
        let json = String(data: data, encoding: .utf8)!

        #expect(json == "255")
    }

    @Test("Encode UInt16")
    func testEncodeUInt16() throws {
        let anyCodable = AnyCodable(UInt16(65535))
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)
        let json = String(data: data, encoding: .utf8)!

        #expect(json == "65535")
    }

    @Test("Encode UInt32")
    func testEncodeUInt32() throws {
        let anyCodable = AnyCodable(UInt32(4294967295))
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)
        let json = String(data: data, encoding: .utf8)!

        #expect(json == "4294967295")
    }

    @Test("Encode UInt64")
    func testEncodeUInt64() throws {
        let anyCodable = AnyCodable(UInt64(18446744073709551615))
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)

        // Just verify it doesn't throw
        #expect(data.count > 0)
    }

    @Test("Encode Float")
    func testEncodeFloat() throws {
        let anyCodable = AnyCodable(Float(3.14))
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)

        #expect(data.count > 0)
    }

    @Test("Encode Double")
    func testEncodeDouble() throws {
        let anyCodable = AnyCodable(Double(3.14159))
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)

        #expect(data.count > 0)
    }

    @Test("Encode string")
    func testEncodeString() throws {
        let anyCodable = AnyCodable("hello")
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)
        let json = String(data: data, encoding: .utf8)!

        #expect(json == "\"hello\"")
    }

    @Test("Encode array")
    func testEncodeArray() throws {
        let anyCodable = AnyCodable([1, 2, 3])
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)
        let json = String(data: data, encoding: .utf8)!

        #expect(json == "[1,2,3]")
    }

    @Test("Encode dictionary")
    func testEncodeDictionary() throws {
        let anyCodable = AnyCodable(["name": "John", "age": 30])
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(anyCodable)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("\"name\""))
        #expect(json.contains("\"age\""))
    }

    // MARK: - Round-trip Tests

    @Test("Round-trip encode and decode string")
    func testRoundTripString() throws {
        let original = "test string"
        let anyCodable = AnyCodable(original)

        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        #expect(decoded.value as? String == original)
    }

    @Test("Round-trip encode and decode number")
    func testRoundTripNumber() throws {
        let original = 12345
        let anyCodable = AnyCodable(original)

        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        #expect(decoded.value as? Int == original)
    }

    @Test("Round-trip encode and decode boolean")
    func testRoundTripBoolean() throws {
        let original = true
        let anyCodable = AnyCodable(original)

        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        #expect(decoded.value as? Bool == original)
    }

    @Test("Round-trip encode and decode array")
    func testRoundTripArray() throws {
        let original = [1, 2, 3, 4, 5]
        let anyCodable = AnyCodable(original)

        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        let array = decoded.value as? [Any]
        #expect(array?.count == 5)
    }

    @Test("Round-trip encode and decode complex structure")
    func testRoundTripComplexStructure() throws {
        let original: [String: Any] = [
            "string": "value",
            "number": 42,
            "bool": true,
            "array": [1, 2, 3],
            "nested": ["key": "value"]
        ]
        let anyCodable = AnyCodable(original)

        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        let dict = decoded.value as? [String: Any]
        #expect(dict?["string"] as? String == "value")
        #expect(dict?["number"] as? Int == 42)
        #expect(dict?["bool"] as? Bool == true)
    }

    // MARK: - Error Handling Tests

    @Test("Encoding unsupported type throws error")
    func testEncodeUnsupportedType() {
        struct UnsupportedType {}
        let anyCodable = AnyCodable(UnsupportedType())

        let encoder = JSONEncoder()

        #expect(throws: EncodingError.self) {
            _ = try encoder.encode(anyCodable)
        }
    }

    // MARK: - Edge Cases

    @Test("Encode empty array")
    func testEncodeEmptyArray() throws {
        let anyCodable = AnyCodable([])
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)
        let json = String(data: data, encoding: .utf8)!

        #expect(json == "[]")
    }

    @Test("Encode empty dictionary")
    func testEncodeEmptyDictionary() throws {
        let anyCodable = AnyCodable([:] as [String: Any])
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)
        let json = String(data: data, encoding: .utf8)!

        #expect(json == "{}")
    }

    @Test("Decode empty array")
    func testDecodeEmptyArray() throws {
        let json = "[]"
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let anyCodable = try decoder.decode(AnyCodable.self, from: data)

        let array = anyCodable.value as? [Any]
        #expect(array?.isEmpty == true)
    }

    @Test("Decode empty object")
    func testDecodeEmptyObject() throws {
        let json = "{}"
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let anyCodable = try decoder.decode(AnyCodable.self, from: data)

        let dict = anyCodable.value as? [String: Any]
        #expect(dict?.isEmpty == true)
    }

    @Test("Encode zero")
    func testEncodeZero() throws {
        let anyCodable = AnyCodable(0)
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)
        let json = String(data: data, encoding: .utf8)!

        #expect(json == "0")
    }

    @Test("Encode empty string")
    func testEncodeEmptyString() throws {
        let anyCodable = AnyCodable("")
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)
        let json = String(data: data, encoding: .utf8)!

        #expect(json == "\"\"")
    }
}
