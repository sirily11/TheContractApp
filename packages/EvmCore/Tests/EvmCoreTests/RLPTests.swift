import Testing
import Foundation
import BigInt
@testable import EvmCore

/// Tests for RLP encoding
@Suite("RLP Tests")
struct RLPTests {

    // MARK: - Data Encoding Tests

    @Test("Encode empty data")
    func testEncodeEmptyData() {
        let data = Data()
        let encoded = RLP.encode(data)

        #expect(encoded == Data([0x80]))
    }

    @Test("Encode single byte less than 0x80")
    func testEncodeSingleByteLow() {
        let data = Data([0x00])
        let encoded = RLP.encode(data)

        // Single byte < 0x80 encodes as itself
        #expect(encoded == Data([0x00]))
    }

    @Test("Encode single byte equal to 0x7f")
    func testEncodeSingleByte0x7f() {
        let data = Data([0x7f])
        let encoded = RLP.encode(data)

        #expect(encoded == Data([0x7f]))
    }

    @Test("Encode single byte equal to 0x80")
    func testEncodeSingleByte0x80() {
        let data = Data([0x80])
        let encoded = RLP.encode(data)

        // Single byte >= 0x80 needs prefix
        #expect(encoded == Data([0x81, 0x80]))
    }

    @Test("Encode short data (less than 55 bytes)")
    func testEncodeShortData() {
        let data = Data([0x01, 0x02, 0x03])
        let encoded = RLP.encode(data)

        // 0x80 + length(3) = 0x83, followed by data
        #expect(encoded == Data([0x83, 0x01, 0x02, 0x03]))
    }

    @Test("Encode data of exactly 55 bytes")
    func testEncode55ByteData() {
        let data = Data(repeating: 0xff, count: 55)
        let encoded = RLP.encode(data)

        // 0x80 + 55 = 0xb7, followed by data
        #expect(encoded[0] == 0xb7)
        #expect(encoded.count == 56) // prefix + 55 bytes
    }

    @Test("Encode long data (more than 55 bytes)")
    func testEncodeLongData() {
        let data = Data(repeating: 0xaa, count: 56)
        let encoded = RLP.encode(data)

        // Long encoding: 0xb7 + length_of_length, length, data
        #expect(encoded[0] == 0xb8) // 0xb7 + 1 (length of length is 1 byte)
        #expect(encoded[1] == 56) // length is 56
        #expect(encoded.count == 58) // 0xb8 + 1 byte length + 56 bytes data
    }

    @Test("Encode very long data (256 bytes)")
    func testEncodeVeryLongData() {
        let data = Data(repeating: 0xbb, count: 256)
        let encoded = RLP.encode(data)

        // 0xb7 + 2 (length requires 2 bytes), length bytes, data
        #expect(encoded[0] == 0xb9) // 0xb7 + 2
        #expect(encoded.count == 259) // prefix + 2 length bytes + 256 data bytes
    }

    // MARK: - String Encoding Tests

    @Test("Encode empty string")
    func testEncodeEmptyString() {
        let encoded = RLP.encode("")
        #expect(encoded == Data([0x80]))
    }

    @Test("Encode hex string with 0x prefix")
    func testEncodeHexStringWithPrefix() {
        let hexString = "0x0102030405"
        let encoded = RLP.encode(hexString)

        // Should encode as data: [0x85, 0x01, 0x02, 0x03, 0x04, 0x05]
        #expect(encoded == Data([0x85, 0x01, 0x02, 0x03, 0x04, 0x05]))
    }

    @Test("Encode hex string without 0x prefix")
    func testEncodeHexStringWithoutPrefix() {
        let hexString = "aabbcc"
        let encoded = RLP.encode(hexString)

        #expect(encoded == Data([0x83, 0xaa, 0xbb, 0xcc]))
    }

    @Test("Encode single hex character (odd length)")
    func testEncodeOddLengthHex() {
        let hexString = "0xf"
        let encoded = RLP.encode(hexString)

        // Should pad to 0x0f
        #expect(encoded == Data([0x0f]))
    }

    // MARK: - BigInt Encoding Tests

    @Test("Encode BigInt zero")
    func testEncodeBigIntZero() {
        let number = BigInt(0)
        let encoded = RLP.encode(number)

        #expect(encoded == Data([0x80]))
    }

    @Test("Encode BigInt small number")
    func testEncodeBigIntSmall() {
        let number = BigInt(127)
        let encoded = RLP.encode(number)

        #expect(encoded == Data([0x7f]))
    }

    @Test("Encode BigInt large number")
    func testEncodeBigIntLarge() {
        let number = BigInt(1000)
        let encoded = RLP.encode(number)

        // 1000 = 0x03e8
        #expect(encoded == Data([0x82, 0x03, 0xe8]))
    }

    @Test("Encode BigInt very large number")
    func testEncodeBigIntVeryLarge() {
        let number = BigInt("1000000000000000000") // 1 ETH in wei
        let encoded = RLP.encode(number)

        #expect(encoded.count > 0)
        #expect(encoded[0] == 0x88) // 0x80 + 8 bytes
    }

    @Test("Encode BigInt odd-length hex")
    func testEncodeBigIntOddHex() {
        let number = BigInt(15) // 0xf - odd length
        let encoded = RLP.encode(number)

        #expect(encoded == Data([0x0f]))
    }

    // MARK: - Array/List Encoding Tests

    @Test("Encode empty array")
    func testEncodeEmptyArray() {
        let array: [Any] = []
        let encoded = RLP.encode(array)

        #expect(encoded == Data([0xc0]))
    }

    @Test("Encode array with one element")
    func testEncodeArrayOneElement() {
        let array: [Any] = [Data([0x01])]
        let encoded = RLP.encode(array)

        // List with one element: 0xc0 + length(1) = 0xc1, then element 0x01
        #expect(encoded == Data([0xc1, 0x01]))
    }

    @Test("Encode array with multiple elements")
    func testEncodeArrayMultipleElements() {
        let array: [Any] = [Data([0x01]), Data([0x02]), Data([0x03])]
        let encoded = RLP.encode(array)

        // Each element encodes as itself (< 0x80), so total is 3 bytes
        // 0xc0 + 3 = 0xc3, followed by elements
        #expect(encoded == Data([0xc3, 0x01, 0x02, 0x03]))
    }

    @Test("Encode nested array")
    func testEncodeNestedArray() {
        let innerArray: [Any] = [Data([0x01])]
        let outerArray: [Any] = [innerArray]
        let encoded = RLP.encode(outerArray)

        // Inner array: [0xc1, 0x01]
        // Outer array: [0xc2, 0xc1, 0x01]
        #expect(encoded == Data([0xc2, 0xc1, 0x01]))
    }

    @Test("Encode array with strings")
    func testEncodeArrayWithStrings() {
        let array: [Any] = ["0x01", "0x02"]
        let encoded = RLP.encode(array)

        #expect(encoded[0] == 0xc2) // List prefix
    }

    @Test("Encode array with BigInts")
    func testEncodeArrayWithBigInts() {
        let array: [Any] = [BigInt(1), BigInt(2), BigInt(3)]
        let encoded = RLP.encode(array)

        #expect(encoded == Data([0xc3, 0x01, 0x02, 0x03]))
    }

    @Test("Encode array with mixed types")
    func testEncodeArrayMixedTypes() {
        let array: [Any] = [Data([0x01]), BigInt(2), "0x03"]
        let encoded = RLP.encode(array)

        #expect(encoded == Data([0xc3, 0x01, 0x02, 0x03]))
    }

    @Test("Encode long array (more than 55 bytes)")
    func testEncodeLongArray() {
        // Create array of 60 elements, each encoding to 1 byte
        var array: [Any] = []
        for i in 0..<60 {
            array.append(Data([UInt8(i % 128)]))
        }

        let encoded = RLP.encode(array)

        // Total encoded items = 60 bytes
        // 0xf7 + 1 (length_of_length) = 0xf8, then length (60 = 0x3c)
        #expect(encoded[0] == 0xf8)
        #expect(encoded[1] == 60)
    }

    // MARK: - Edge Cases

    @Test("Encode data with all zeros")
    func testEncodeAllZeros() {
        let data = Data(repeating: 0x00, count: 10)
        let encoded = RLP.encode(data)

        #expect(encoded[0] == 0x8a) // 0x80 + 10
        #expect(encoded.count == 11)
    }

    @Test("Encode data with all 0xFF")
    func testEncodeAllOnes() {
        let data = Data(repeating: 0xff, count: 10)
        let encoded = RLP.encode(data)

        #expect(encoded[0] == 0x8a) // 0x80 + 10
        #expect(encoded.count == 11)
    }

    @Test("Encode unsupported type falls back to empty")
    func testEncodeUnsupportedType() {
        struct UnsupportedType {}
        let encoded = RLP.encode(UnsupportedType())

        // Should encode as empty data
        #expect(encoded == Data([0x80]))
    }

    // MARK: - Real-world Examples

    @Test("Encode transaction-like array")
    func testEncodeTransactionLikeArray() {
        // Simplified transaction structure
        let transaction: [Any] = [
            BigInt(0), // nonce
            BigInt(20000000000), // gasPrice
            BigInt(21000), // gasLimit
            "0x1234567890123456789012345678901234567890", // to
            BigInt(1000000000000000000), // value (1 ETH)
            "0x", // data (empty)
        ]

        let encoded = RLP.encode(transaction)

        #expect(encoded.count > 0)
        #expect(encoded[0] >= 0xc0) // Should be a list
    }

    @Test("Encode address")
    func testEncodeAddress() {
        let address = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
        let encoded = RLP.encode(address)

        // 20-byte address: 0x80 + 20 = 0x94
        #expect(encoded[0] == 0x94)
        #expect(encoded.count == 21)
    }

    @Test("Encode chain ID")
    func testEncodeChainId() {
        let chainId = BigInt(1) // Ethereum mainnet
        let encoded = RLP.encode(chainId)

        #expect(encoded == Data([0x01]))
    }

    @Test("Encode large value in wei")
    func testEncodeLargeWeiValue() {
        // 100 ETH in wei
        let weiValue = BigInt("100000000000000000000")
        let encoded = RLP.encode(weiValue)

        #expect(encoded.count > 0)
    }
}
