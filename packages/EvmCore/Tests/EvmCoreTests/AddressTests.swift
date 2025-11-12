import Testing
import Foundation
@testable import EvmCore

/// Tests for Address type and AddressError
@Suite("Address Tests")
struct AddressTests {

    // MARK: - Valid Address Tests

    @Test("Initialize with valid address with 0x prefix")
    func testInitWithValidAddressWithPrefix() throws {
        let address = try Address(fromHexString: "0x1234567890123456789012345678901234567890")
        #expect(address.value == "0x1234567890123456789012345678901234567890")
    }

    @Test("Initialize with valid address without 0x prefix")
    func testInitWithValidAddressWithoutPrefix() throws {
        let address = try Address(fromHexString: "1234567890123456789012345678901234567890")
        #expect(address.value == "0x1234567890123456789012345678901234567890")
    }

    @Test("Initialize with uppercase hex characters")
    func testInitWithUppercaseHex() throws {
        let address = try Address(fromHexString: "0xABCDEF1234567890ABCDEF1234567890ABCDEF12")
        #expect(address.value == "0xABCDEF1234567890ABCDEF1234567890ABCDEF12")
    }

    @Test("Initialize with lowercase hex characters")
    func testInitWithLowercaseHex() throws {
        let address = try Address(fromHexString: "0xabcdef1234567890abcdef1234567890abcdef12")
        #expect(address.value == "0xabcdef1234567890abcdef1234567890abcdef12")
    }

    @Test("Initialize with mixed case hex characters (EIP-55 checksum)")
    func testInitWithMixedCaseHex() throws {
        let address = try Address(fromHexString: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed")
        #expect(address.value == "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed")
    }

    @Test("Convenience initializer with string")
    func testConvenienceInitializer() throws {
        let address = try Address("0x1234567890123456789012345678901234567890")
        #expect(address.value == "0x1234567890123456789012345678901234567890")
    }

    @Test("Initialize with all zeros address")
    func testInitWithZeroAddress() throws {
        let address = try Address(fromHexString: "0x0000000000000000000000000000000000000000")
        #expect(address.value == "0x0000000000000000000000000000000000000000")
    }

    @Test("Initialize with all Fs address")
    func testInitWithMaxAddress() throws {
        let address = try Address(fromHexString: "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF")
        #expect(address.value == "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF")
    }

    // MARK: - Invalid Length Tests

    @Test("Throw error for address too short")
    func testAddressTooShort() {
        #expect(throws: AddressError.self) {
            _ = try Address(fromHexString: "0x12345")
        }
    }

    @Test("Throw error for address too long")
    func testAddressTooLong() {
        #expect(throws: AddressError.self) {
            _ = try Address(fromHexString: "0x12345678901234567890123456789012345678901234")
        }
    }

    @Test("Throw error for empty string")
    func testEmptyString() {
        #expect(throws: AddressError.self) {
            _ = try Address(fromHexString: "")
        }
    }

    @Test("Throw error for just 0x prefix")
    func testJustPrefix() {
        #expect(throws: AddressError.self) {
            _ = try Address(fromHexString: "0x")
        }
    }

    @Test("Throw error for one character short")
    func testOneCharShort() {
        #expect(throws: AddressError.self) {
            _ = try Address(fromHexString: "0x123456789012345678901234567890123456789")
        }
    }

    @Test("Throw error for one character long")
    func testOneCharLong() {
        #expect(throws: AddressError.self) {
            _ = try Address(fromHexString: "0x12345678901234567890123456789012345678901")
        }
    }

    // MARK: - Invalid Characters Tests

    @Test("Throw error for non-hex character 'G'")
    func testInvalidCharacterG() {
        #expect(throws: AddressError.self) {
            _ = try Address(fromHexString: "0x1234567890123456789012345678901234567G90")
        }
    }

    @Test("Throw error for non-hex character 'Z'")
    func testInvalidCharacterZ() {
        #expect(throws: AddressError.self) {
            _ = try Address(fromHexString: "0xZ234567890123456789012345678901234567890")
        }
    }

    @Test("Throw error for space character")
    func testInvalidCharacterSpace() {
        #expect(throws: AddressError.self) {
            _ = try Address(fromHexString: "0x1234567890123456 89012345678901234567890")
        }
    }

    @Test("Throw error for special character")
    func testInvalidCharacterSpecial() {
        #expect(throws: AddressError.self) {
            _ = try Address(fromHexString: "0x1234567890123456@89012345678901234567890")
        }
    }

    @Test("Throw error for dash character")
    func testInvalidCharacterDash() {
        #expect(throws: AddressError.self) {
            _ = try Address(fromHexString: "0x1234567890-23456789012345678901234567890")
        }
    }

    // MARK: - AddressError Description Tests

    @Test("AddressError.invalidLength error description contains message")
    func testInvalidLengthErrorDescription() {
        let error = AddressError.invalidLength("too short")
        #expect(error.errorDescription?.contains("too short") == true)
        #expect(error.errorDescription?.contains("Invalid address length") == true)
    }

    @Test("AddressError.invalidCharacters error description contains message")
    func testInvalidCharactersErrorDescription() {
        let error = AddressError.invalidCharacters("contains 'G'")
        #expect(error.errorDescription?.contains("contains 'G'") == true)
        #expect(error.errorDescription?.contains("Invalid address characters") == true)
    }

    // MARK: - Error Type Tests

    @Test("AddressError conforms to Error protocol")
    func testAddressErrorIsError() {
        let error: Error = AddressError.invalidLength("test")
        #expect(error is AddressError)
    }

    @Test("AddressError conforms to LocalizedError protocol")
    func testAddressErrorIsLocalizedError() {
        let error: LocalizedError = AddressError.invalidLength("test")
        #expect(error.errorDescription != nil)
    }

    // MARK: - Error Catching Tests

    @Test("Catch invalidLength error and extract message")
    func testCatchInvalidLengthError() {
        do {
            _ = try Address(fromHexString: "0x123")
            Issue.record("Should have thrown an error")
        } catch let AddressError.invalidLength(message) {
            #expect(message.contains("40 hex characters") == true)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("Catch invalidCharacters error")
    func testCatchInvalidCharactersError() {
        do {
            _ = try Address(fromHexString: "0xG234567890123456789012345678901234567890")
            Issue.record("Should have thrown an error")
        } catch AddressError.invalidCharacters {
            #expect(true)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - Case Preservation Tests (EIP-55)

    @Test("Preserve lowercase case")
    func testPreserveLowercase() throws {
        let input = "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd"
        let address = try Address(fromHexString: input)
        #expect(address.value == input)
    }

    @Test("Preserve uppercase case")
    func testPreserveUppercase() throws {
        let input = "0xABCDEFABCDEFABCDEFABCDEFABCDEFABCDEFABCD"
        let address = try Address(fromHexString: input)
        #expect(address.value == input)
    }

    @Test("Preserve mixed case (EIP-55 checksum)")
    func testPreserveMixedCase() throws {
        // Real Ethereum address with EIP-55 checksum
        let input = "0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359"
        let address = try Address(fromHexString: input)
        #expect(address.value == input)
    }

    // MARK: - Real-world Addresses

    @Test("Initialize with known Ethereum address (Vitalik's)")
    func testKnownAddress1() throws {
        let address = try Address(fromHexString: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")
        #expect(address.value.lowercased() == "0xd8da6bf26964af9d7eed9e03e53415d37aa96045")
    }

    @Test("Initialize with known Ethereum address (USDT contract)")
    func testKnownAddress2() throws {
        let address = try Address(fromHexString: "0xdAC17F958D2ee523a2206206994597C13D831ec7")
        #expect(address.value.lowercased() == "0xdac17f958d2ee523a2206206994597c13d831ec7")
    }

    @Test("Initialize with burn address")
    func testBurnAddress() throws {
        let address = try Address(fromHexString: "0x000000000000000000000000000000000000dEaD")
        #expect(address.value.lowercased() == "0x000000000000000000000000000000000000dead")
    }

    // MARK: - Prefix Handling

    @Test("Address without prefix gets 0x added")
    func testPrefixAdded() throws {
        let address = try Address(fromHexString: "1234567890123456789012345678901234567890")
        #expect(address.value.hasPrefix("0x"))
    }

    @Test("Address with 0X uppercase prefix throws error")
    func testUppercasePrefixThrowsError() {
        // The current implementation doesn't handle uppercase "0X" prefix
        // It will add "0x" making it too long
        #expect(throws: AddressError.self) {
            _ = try Address(fromHexString: "0X1234567890123456789012345678901234567890")
        }
    }

    // MARK: - Integration Tests

    @Test("Multiple valid addresses can be created")
    func testMultipleAddresses() throws {
        let addresses = [
            "0x1111111111111111111111111111111111111111",
            "0x2222222222222222222222222222222222222222",
            "0x3333333333333333333333333333333333333333"
        ]

        for addrString in addresses {
            let address = try Address(fromHexString: addrString)
            #expect(address.value.lowercased() == addrString.lowercased())
        }
    }

    @Test("Address can be used in collections")
    func testAddressInArray() throws {
        let address1 = try Address(fromHexString: "0x1111111111111111111111111111111111111111")
        let address2 = try Address(fromHexString: "0x2222222222222222222222222222222222222222")

        let addresses = [address1, address2]
        #expect(addresses.count == 2)
    }
}
