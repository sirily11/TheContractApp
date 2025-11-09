import Testing
import Foundation
@testable import BIP39

/// Tests for BIP39 error types
@Suite("BIP39 Errors Tests")
struct BIP39ErrorsTests {

    // MARK: - BIP39Error Tests

    @Test("BIP39Error.invalidWordCount error description")
    func testInvalidWordCountError() {
        let error = BIP39Error.invalidWordCount(10)
        #expect(error.errorDescription == "Invalid word count: 10. Must be 12, 15, 18, 21, or 24.")
    }

    @Test("BIP39Error.invalidWord error description")
    func testInvalidWordError() {
        let error = BIP39Error.invalidWord("foobar")
        #expect(error.errorDescription == "Invalid word in mnemonic: 'foobar'")
    }

    @Test("BIP39Error.invalidChecksum error description")
    func testInvalidChecksumError() {
        let error = BIP39Error.invalidChecksum
        #expect(error.errorDescription == "Invalid mnemonic checksum")
    }

    @Test("BIP39Error.invalidEntropy error description")
    func testInvalidEntropyError() {
        let error = BIP39Error.invalidEntropy
        #expect(error.errorDescription == "Invalid entropy length")
    }

    @Test("BIP39Error.seedGenerationFailed error description")
    func testSeedGenerationFailedError() {
        let error = BIP39Error.seedGenerationFailed
        #expect(error.errorDescription == "Failed to generate seed from mnemonic")
    }

    @Test("BIP39Error.keyDerivationFailed error description")
    func testKeyDerivationFailedError() {
        let error = BIP39Error.keyDerivationFailed
        #expect(error.errorDescription == "Failed to derive key")
    }

    @Test("BIP39Error.cryptographicFailure error description")
    func testCryptographicFailureError() {
        let error = BIP39Error.cryptographicFailure("HMAC failed")
        #expect(error.errorDescription == "Cryptographic operation failed: HMAC failed")
    }

    @Test("BIP39Error conforms to Error protocol")
    func testBIP39ErrorIsError() {
        let error: Error = BIP39Error.invalidChecksum
        #expect(error is BIP39Error)
    }

    @Test("BIP39Error conforms to LocalizedError protocol")
    func testBIP39ErrorIsLocalizedError() {
        let error: LocalizedError = BIP39Error.invalidChecksum
        #expect(error.errorDescription != nil)
    }

    // MARK: - BIP32Error Tests

    @Test("BIP32Error.invalidSeed error description")
    func testInvalidSeedError() {
        let error = BIP32Error.invalidSeed
        #expect(error.errorDescription == "Invalid seed for BIP32 derivation")
    }

    @Test("BIP32Error.invalidPath error description")
    func testInvalidPathError() {
        let error = BIP32Error.invalidPath("m/invalid/path")
        #expect(error.errorDescription == "Invalid derivation path: 'm/invalid/path'")
    }

    @Test("BIP32Error.invalidIndex error description")
    func testInvalidIndexError() {
        let error = BIP32Error.invalidIndex(4294967295)
        #expect(error.errorDescription == "Invalid child index: 4294967295")
    }

    @Test("BIP32Error.invalidKey error description")
    func testInvalidKeyError() {
        let error = BIP32Error.invalidKey
        #expect(error.errorDescription == "Invalid extended key")
    }

    @Test("BIP32Error.derivationFailed error description")
    func testDerivationFailedError() {
        let error = BIP32Error.derivationFailed("Point at infinity")
        #expect(error.errorDescription == "Key derivation failed: Point at infinity")
    }

    @Test("BIP32Error conforms to Error protocol")
    func testBIP32ErrorIsError() {
        let error: Error = BIP32Error.invalidSeed
        #expect(error is BIP32Error)
    }

    @Test("BIP32Error conforms to LocalizedError protocol")
    func testBIP32ErrorIsLocalizedError() {
        let error: LocalizedError = BIP32Error.invalidSeed
        #expect(error.errorDescription != nil)
    }

    // MARK: - Error throwing tests

    @Test("Throwing BIP39Error.invalidWordCount")
    func testThrowingInvalidWordCount() throws {
        func throwError() throws {
            throw BIP39Error.invalidWordCount(13)
        }

        #expect(throws: BIP39Error.self) {
            try throwError()
        }
    }

    @Test("Throwing BIP32Error.invalidPath")
    func testThrowingInvalidPath() throws {
        func throwError() throws {
            throw BIP32Error.invalidPath("bad/path")
        }

        #expect(throws: BIP32Error.self) {
            try throwError()
        }
    }
}
