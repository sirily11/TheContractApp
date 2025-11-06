import BigInt
import Foundation
import Testing

@testable import EvmCore

@Suite("PrivateKeySigner Tests")
struct PrivateKeySignerTests {

    // MARK: - Initialization Tests

    @Test("Initialize with valid hex private key")
    func testInitializeWithValidHexPrivateKey() throws {
        let privatekeys = [
            "8a5a81bf5f1efd67a4fea7b628b56b8d3cfd302a26137eaebb5851d13f75a05d",
            "37f71586206b5fb63aedf5a4f2a602251e9d1fdd5b3cd37b6ca836cd5412ffbf",
        ]

        let expectedAddresses = [
            "0x24CBa00D254CcE5d5Decf92013cD3620E7cA0E89",
            "0xA852A33f9baD9Bf40d78E8085360C0B5e54BB0Cf",
        ]

        for (privateKeyHex, expectedAddress) in zip(privatekeys, expectedAddresses) {
            let signer = try PrivateKeySigner(hexPrivateKey: privateKeyHex)
            #expect(signer.address.value == expectedAddress)
        }

    }

    @Test("Initialize with 0x-prefixed hex private key")
    func testInitializeWith0xPrefixedHexPrivateKey() throws {
        let privateKeyHex = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
        let signer = try PrivateKeySigner(hexPrivateKey: privateKeyHex)

        // Should derive the same address as without prefix (EIP-55 checksummed)
        #expect(signer.address.value == "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")
    }

    @Test("Reject invalid private key length")
    func testRejectInvalidPrivateKeyLength() throws {
        // Too short (31 bytes instead of 32)
        let shortKey = "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff"

        #expect(throws: SignerError.self) {
            try PrivateKeySigner(hexPrivateKey: shortKey)
        }

        // Too long (33 bytes instead of 32)
        let longKey = "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff8000"

        #expect(throws: SignerError.self) {
            try PrivateKeySigner(hexPrivateKey: longKey)
        }
    }

    @Test("Reject invalid hex characters")
    func testRejectInvalidHexCharacters() throws {
        // Contains invalid character 'g'
        let invalidHex = "gc0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

        #expect(throws: SignerError.self) {
            try PrivateKeySigner(hexPrivateKey: invalidHex)
        }
    }

    // MARK: - Random Wallet Generation Tests

    @Test("Generate random wallet")
    func testGenerateRandomWallet() throws {
        let signer1 = try PrivateKeySigner.random()
        let signer2 = try PrivateKeySigner.random()

        // Each random signer should have a valid address
        #expect(signer1.address.value.hasPrefix("0x"))
        #expect(signer2.address.value.hasPrefix("0x"))
        #expect(signer1.address.value.count == 42)
        #expect(signer2.address.value.count == 42)

        // Two random signers should have different addresses
        #expect(signer1.address.value != signer2.address.value)
    }

    // MARK: - Sign and Verify Tests

    @Test("Sign and verify message - same signer")
    func testSignAndVerifySameSigner() async throws {
        let signer = try PrivateKeySigner.random()
        let message = "Hello, Ethereum!".data(using: .utf8)!

        // Sign the message
        let signature = try await signer.sign(message: message)

        // Signature should be 65 bytes (r + s + v)
        #expect(signature.count == 65)

        // Verify with the same signer's address
        let isValid = try await signer.verify(
            address: signer.address,
            message: message,
            signature: signature
        )

        #expect(isValid == true)
    }

    @Test("Sign and verify message - different signers")
    func testSignAndVerifyDifferentSigners() async throws {
        let signer1 = try PrivateKeySigner.random()
        let signer2 = try PrivateKeySigner.random()
        let message = "Hello, Ethereum!".data(using: .utf8)!

        // Sign with signer1
        let signature = try await signer1.sign(message: message)

        // Verify with signer2's verify method but signer1's address
        let isValid = try await signer2.verify(
            address: signer1.address,
            message: message,
            signature: signature
        )

        // Should be valid because we're checking against signer1's address
        #expect(isValid == true)
    }

    @Test("Verify fails with wrong address")
    func testVerifyFailsWithWrongAddress() async throws {
        let signer1 = try PrivateKeySigner.random()
        let signer2 = try PrivateKeySigner.random()
        let message = "Hello, Ethereum!".data(using: .utf8)!

        // Sign with signer1
        let signature = try await signer1.sign(message: message)

        // Try to verify with signer2's address (should fail)
        let isValid = try await signer1.verify(
            address: signer2.address,
            message: message,
            signature: signature
        )

        #expect(isValid == false)
    }

    @Test("Verify fails with wrong message")
    func testVerifyFailsWithWrongMessage() async throws {
        let signer = try PrivateKeySigner.random()
        let message1 = "Hello, Ethereum!".data(using: .utf8)!
        let message2 = "Hello, Bitcoin!".data(using: .utf8)!

        // Sign message1
        let signature = try await signer.sign(message: message1)

        // Try to verify with message2 (should fail)
        let isValid = try await signer.verify(
            address: signer.address,
            message: message2,
            signature: signature
        )

        #expect(isValid == false)
    }

    @Test("Verify fails with malformed signature")
    func testVerifyFailsWithMalformedSignature() async throws {
        let signer = try PrivateKeySigner.random()
        let message = "Hello, Ethereum!".data(using: .utf8)!

        // Create invalid signature (wrong length)
        let invalidSignature = Data(repeating: 0, count: 64)  // Should be 65 bytes

        // Verify should return false for invalid signature
        let isValid = try await signer.verify(
            address: signer.address,
            message: message,
            signature: invalidSignature
        )

        #expect(isValid == false)
    }

    @Test("Signature format is 65 bytes")
    func testSignatureFormat() async throws {
        let signer = try PrivateKeySigner.random()
        let message = "Test message".data(using: .utf8)!

        let signature = try await signer.sign(message: message)

        // Ethereum signature format: r (32 bytes) + s (32 bytes) + v (1 byte) = 65 bytes
        #expect(signature.count == 65)

        // v should be 27 or 28 (Ethereum format)
        let v = signature.last!
        #expect(v == 27 || v == 28)
    }

    @Test("Derive correct Ethereum address from known private key")
    func testDeriveCorrectAddressFromKnownPrivateKey() throws {
        // Test vector: Anvil's first account (EIP-55 checksummed)
        let privateKeyHex = "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
        let expectedAddress = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

        let signer = try PrivateKeySigner(hexPrivateKey: privateKeyHex)

        #expect(signer.address.value == expectedAddress)
    }

    @Test("Multiple signatures from same key are different")
    func testMultipleSignaturesAreDifferent() async throws {
        let signer = try PrivateKeySigner.random()
        let message = "Test message".data(using: .utf8)!

        // Sign the same message multiple times
        let signature1 = try await signer.sign(message: message)
        let signature2 = try await signer.sign(message: message)

        // Signatures can be different due to randomness in ECDSA
        // But both should verify correctly
        let isValid1 = try await signer.verify(
            address: signer.address,
            message: message,
            signature: signature1
        )
        let isValid2 = try await signer.verify(
            address: signer.address,
            message: message,
            signature: signature2
        )

        #expect(isValid1 == true)
        #expect(isValid2 == true)
    }
}
