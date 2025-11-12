import Foundation
import Testing

@testable import EvmCore

@Suite("Address Encoding Test")
struct AddressEncodingTest {
    @Test("Verify address encoding to Data")
    func testAddressEncoding() throws {
        // Test address: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 (Anvil account 1)
        let addressString = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"

        let cleanAddress = addressString.hasPrefix("0x")
            ? String(addressString.dropFirst(2))
            : addressString

        print("Clean address: \(cleanAddress)")
        print("Length: \(cleanAddress.count)")

        let addressData = Data(hex: cleanAddress)

        print("Address as data (\(addressData.count) bytes): \(addressData.map { String(format: "%02x", $0) }.joined())")

        #expect(addressData.count == 20, "Address must be exactly 20 bytes")
        #expect(cleanAddress.count == 40, "Address hex string must be 40 characters")

        // Verify it matches the expected bytes
        let expected = "70997970c51812dc3a010c7d01b50e0d17dc79c8"
        let actual = addressData.map { String(format: "%02x", $0) }.joined()

        print("Expected: \(expected)")
        print("Actual:   \(actual)")

        #expect(actual.lowercased() == expected.lowercased())
    }
}
