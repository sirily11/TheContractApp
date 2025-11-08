import Testing
import Foundation

@testable import BIP39
@testable import EvmCore

// MARK: - Test Data Models

struct TestVector: Codable {
    let mnemonic: String
    let privateKey: String
    let address: String
}

// MARK: - Tests

@Suite("BIP39 Tests")
struct BIP39Tests {

    @Test("Validate all test vectors from words.json")
    func testAllVectorsFromFile() throws {
        // Get the path to the words.json file from bundle resources
        guard let jsonURL = Bundle.module.url(forResource: "words", withExtension: "json") else {
            Issue.record("Could not find words.json in test bundle")
            return
        }

        // Read and decode the JSON file
        let jsonData = try Data(contentsOf: jsonURL)
        let vectors = try JSONDecoder().decode([TestVector].self, from: jsonData)

        #expect(vectors.count > 0, "Should have test vectors in words.json")
        print("📝 Testing \(vectors.count) mnemonic vectors...")

        var failedCount = 0
        var successCount = 0

        // Test each vector
        for (index, vector) in vectors.enumerated() {
            do {
                // Create mnemonic from the phrase
                // Note: We skip checksum validation because the test vectors are generated mnemonics
                // that may not have valid BIP39 checksums. The important validation is that
                // mnemonic -> seed -> private key -> address derivation works correctly.
                let words = vector.mnemonic.split(separator: " ").map { String($0).lowercased() }
                let mnemonic = try Mnemonic(words: words, validateChecksum: false)

                // Derive private key using default Ethereum path (m/44'/60'/0'/0/0)
                let derivedPrivateKey = try mnemonic.privateKey(derivePath: .ethereum)

                // Normalize both private keys for comparison (lowercase, with 0x prefix)
                let expectedPrivateKey = vector.privateKey.lowercased()
                let actualPrivateKey = derivedPrivateKey.lowercased()

                // Check if private keys match
                #expect(
                    actualPrivateKey == expectedPrivateKey,
                    "Vector \(index): Private key mismatch\nMnemonic: \(vector.mnemonic)\nExpected: \(expectedPrivateKey)\nActual: \(actualPrivateKey)"
                )

                // Derive address from private key
                let signer = try PrivateKeySigner(hexPrivateKey: derivedPrivateKey)
                let derivedAddress = signer.address.value

                // Normalize addresses for comparison (case-insensitive)
                let expectedAddress = vector.address.lowercased()
                let actualAddress = derivedAddress.lowercased()

                // Check if addresses match
                #expect(
                    actualAddress == expectedAddress,
                    "Vector \(index): Address mismatch\nMnemonic: \(vector.mnemonic)\nPrivate Key: \(derivedPrivateKey)\nExpected: \(expectedAddress)\nActual: \(actualAddress)"
                )

                successCount += 1

            } catch {
                failedCount += 1
                Issue.record("Vector \(index) failed: \(vector.mnemonic) - Error: \(error)")
            }
        }

        print("✅ Successfully validated \(successCount)/\(vectors.count) test vectors")
        if failedCount > 0 {
            print("❌ Failed: \(failedCount) vectors")
        }
    }

    @Test("Validate first test vector individually")
    func testFirstVector() throws {
        // Test the first vector individually for easier debugging
        let words = "extra female protect salad balance soccer match private remain verify camera scissors".split(separator: " ").map { String($0) }
        let mnemonic = try Mnemonic(words: words, validateChecksum: false)
        let privateKey = try mnemonic.privateKey(derivePath: .ethereum)

        #expect(
            privateKey.lowercased() == "0xe8fb0023174bbe9504cc74942231d4ec53f2a0b71a3f97bbe5be91968e8e3e44",
            "First vector private key should match"
        )

        let signer = try PrivateKeySigner(hexPrivateKey: privateKey)
        let address = signer.address.value.lowercased()

        #expect(
            address == "0xe7cf373c3d9132ebe88c0eb3fddeec27c9a7911d",
            "First vector address should match"
        )
    }

    @Test("Validate mnemonic validation works")
    func testMnemonicValidation() throws {
        // Test that a generated mnemonic has valid checksum
        let generatedMnemonic = try Mnemonic.generate(wordCount: .twelve)
        #expect(generatedMnemonic.isValid(), "Generated mnemonic should have valid checksum")

        // Can derive key from generated mnemonic
        let privateKey = try generatedMnemonic.privateKey(derivePath: .ethereum)
        #expect(privateKey.hasPrefix("0x"), "Private key should have 0x prefix")
        #expect(privateKey.count == 66, "Private key should be 66 characters (0x + 64 hex)")

        // Invalid word count should throw
        #expect(throws: BIP39Error.self) {
            try Mnemonic(phrase: "extra female protect")
        }

        // Invalid word should throw
        #expect(throws: BIP39Error.self) {
            try Mnemonic(phrase: "invalidword word here test test test test test test test test test")
        }
    }

    @Test("Validate seed generation is deterministic")
    func testSeedDeterminism() throws {
        let words = "extra female protect salad balance soccer match private remain verify camera scissors".split(separator: " ").map { String($0) }
        let mnemonic1 = try Mnemonic(words: words, validateChecksum: false)
        let mnemonic2 = try Mnemonic(words: words, validateChecksum: false)

        let seed1 = try mnemonic1.toSeed()
        let seed2 = try mnemonic2.toSeed()

        #expect(seed1 == seed2, "Seeds from same mnemonic should be identical")

        let privateKey1 = try mnemonic1.privateKey(derivePath: .ethereum)
        let privateKey2 = try mnemonic2.privateKey(derivePath: .ethereum)

        #expect(privateKey1 == privateKey2, "Private keys from same mnemonic should be identical")
    }

    @Test("Validate different derivation paths produce different keys")
    func testDifferentDerivationPaths() throws {
        let words = "extra female protect salad balance soccer match private remain verify camera scissors".split(separator: " ").map { String($0) }
        let mnemonic = try Mnemonic(words: words, validateChecksum: false)

        // Derive keys with different paths
        let ethereumKey = try mnemonic.privateKey(derivePath: .ethereum) // m/44'/60'/0'/0/0
        let customPath1 = try mnemonic.privateKey(derivePath: .custom("m/44'/60'/0'/0/1")) // Different index
        let customPath2 = try mnemonic.privateKey(derivePath: .custom("m/44'/60'/0'/1/0")) // Different change

        // All keys should be different
        #expect(ethereumKey != customPath1, "Different paths should produce different keys")
        #expect(ethereumKey != customPath2, "Different paths should produce different keys")
        #expect(customPath1 != customPath2, "Different paths should produce different keys")
    }
}
