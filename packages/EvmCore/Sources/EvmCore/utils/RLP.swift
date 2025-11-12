import Foundation
import BigInt

/// RLP (Recursive Length Prefix) encoding utilities for Ethereum transaction serialization
public struct RLP {
    /// Encodes a value to RLP format
    /// - Parameter value: The value to encode (Data, String, BigInt, [Any])
    /// - Returns: RLP encoded data
    public static func encode(_ value: Any) -> Data {
        if let data = value as? Data {
            return encodeData(data)
        } else if let string = value as? String {
            // Convert hex string to data
            let cleanHex = string.hasPrefix("0x") ? String(string.dropFirst(2)) : string
            if cleanHex.isEmpty {
                return encodeData(Data())
            }
            let data = Data(hex: cleanHex)
            return encodeData(data)
        } else if let number = value as? BigInt {
            // Convert BigInt to minimal byte representation
            if number == 0 {
                return encodeData(Data())
            }
            let hex = String(number, radix: 16)
            let paddedHex = hex.count % 2 == 0 ? hex : "0" + hex
            let data = Data(hex: paddedHex)
            return encodeData(data)
        } else if let array = value as? [Any] {
            return encodeList(array)
        } else {
            // Fallback: empty data
            return encodeData(Data())
        }
    }

    /// Encodes raw data to RLP format
    private static func encodeData(_ data: Data) -> Data {
        if data.count == 1 && data[0] < 0x80 {
            // Single byte less than 0x80: encode as itself
            return data
        } else if data.count <= 55 {
            // 0-55 bytes: [0x80 + length, data...]
            var result = Data([0x80 + UInt8(data.count)])
            result.append(data)
            return result
        } else {
            // More than 55 bytes: [0xb7 + length_of_length, length, data...]
            let lengthBytes = encodeLength(data.count)
            var result = Data([0xb7 + UInt8(lengthBytes.count)])
            result.append(lengthBytes)
            result.append(data)
            return result
        }
    }

    /// Encodes a list to RLP format
    private static func encodeList(_ list: [Any]) -> Data {
        // Encode all items in the list
        var encodedItems = Data()
        for item in list {
            encodedItems.append(encode(item))
        }

        if encodedItems.count <= 55 {
            // 0-55 bytes: [0xc0 + length, items...]
            var result = Data([0xc0 + UInt8(encodedItems.count)])
            result.append(encodedItems)
            return result
        } else {
            // More than 55 bytes: [0xf7 + length_of_length, length, items...]
            let lengthBytes = encodeLength(encodedItems.count)
            var result = Data([0xf7 + UInt8(lengthBytes.count)])
            result.append(lengthBytes)
            result.append(encodedItems)
            return result
        }
    }

    /// Encodes an integer length as minimal big-endian bytes
    private static func encodeLength(_ length: Int) -> Data {
        var result = Data()
        var value = length
        while value > 0 {
            result.insert(UInt8(value & 0xff), at: 0)
            value >>= 8
        }
        return result
    }
}
