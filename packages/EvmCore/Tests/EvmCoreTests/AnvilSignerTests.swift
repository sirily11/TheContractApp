import Testing
import Foundation
@testable import EvmCore

@Suite("Anvil Signer Tests")
struct AnvilSignerTests {
    @Test("Verify Anvil account0 private key derives correct address")
    func testAccount0PrivateKeyDerivation() throws {
        // Use the known Anvil account0 private key
        let privateKey = AnvilAccounts.privateKey0
        let signer = try PrivateKeySigner(hexPrivateKey: privateKey)

        // Verify it derives to the expected address
        let expectedAddress = AnvilAccounts.account0
        #expect(signer.address.value.lowercased() == expectedAddress.lowercased())

        print("Derived address: \(signer.address.value)")
        print("Expected address: \(expectedAddress)")
    }

    @Test("Verify Anvil account1 private key derives correct address")
    func testAccount1PrivateKeyDerivation() throws {
        let privateKey = AnvilAccounts.privateKey1
        let signer = try PrivateKeySigner(hexPrivateKey: privateKey)

        let expectedAddress = AnvilAccounts.account1
        #expect(signer.address.value.lowercased() == expectedAddress.lowercased())
    }

    @Test("Verify Anvil account2 private key derives correct address")
    func testAccount2PrivateKeyDerivation() throws {
        let privateKey = AnvilAccounts.privateKey2
        let signer = try PrivateKeySigner(hexPrivateKey: privateKey)

        let expectedAddress = AnvilAccounts.account2
        #expect(signer.address.value.lowercased() == expectedAddress.lowercased())
    }

    // MARK: - AnvilSigner Tests

    @Test("Initialize AnvilSigner with Address")
    func testInitializeWithAddress() throws {
        let address = try Address(fromHexString: AnvilAccounts.account0)
        let signer = AnvilSigner(address: address)

        #expect(signer.address.value.lowercased() == AnvilAccounts.account0.lowercased())
    }

    @Test("Initialize AnvilSigner with address string")
    func testInitializeWithAddressString() throws {
        let signer = try AnvilSigner(addressString: AnvilAccounts.account1)

        #expect(signer.address.value.lowercased() == AnvilAccounts.account1.lowercased())
    }

    @Test("Initialize AnvilSigner with address string without 0x prefix")
    func testInitializeWithAddressStringNoPrefix() throws {
        let addressWithoutPrefix = String(AnvilAccounts.account0.dropFirst(2))
        let signer = try AnvilSigner(addressString: addressWithoutPrefix)

        #expect(signer.address.value.lowercased() == AnvilAccounts.account0.lowercased())
    }

    @Test("AnvilSigner sign method throws unsupported operation error")
    func testSignThrowsError() async throws {
        let signer = try AnvilSigner(addressString: AnvilAccounts.account0)
        let message = "Hello, World!".data(using: .utf8)!

        await #expect(throws: SignerError.self) {
            _ = try await signer.sign(message: message)
        }
    }

    @Test("AnvilSigner verify method throws unsupported operation error")
    func testVerifyThrowsError() async throws {
        let signer = try AnvilSigner(addressString: AnvilAccounts.account0)
        let address = try Address(fromHexString: AnvilAccounts.account0)
        let message = "Hello, World!".data(using: .utf8)!
        let signature = Data(repeating: 0, count: 65)

        await #expect(throws: SignerError.self) {
            _ = try await signer.verify(address: address, message: message, signature: signature)
        }
    }

    // MARK: - AnvilAccounts Tests

    @Test("AnvilAccounts has 10 accounts")
    func testAnvilAccountsCount() {
        #expect(AnvilAccounts.allAccounts.count == 10)
    }

    @Test("AnvilAccounts first three match individual constants")
    func testAnvilAccountsOrder() {
        #expect(AnvilAccounts.allAccounts[0] == AnvilAccounts.account0)
        #expect(AnvilAccounts.allAccounts[1] == AnvilAccounts.account1)
        #expect(AnvilAccounts.allAccounts[2] == AnvilAccounts.account2)
    }

    @Test("All Anvil accounts are valid addresses")
    func testAllAnvilAccountsValid() throws {
        for account in AnvilAccounts.allAccounts {
            // Should not throw
            _ = try Address(fromHexString: account)
        }
    }

    @Test("Anvil private keys are valid")
    func testAnvilPrivateKeysValid() throws {
        let privateKeys = [
            AnvilAccounts.privateKey0,
            AnvilAccounts.privateKey1,
            AnvilAccounts.privateKey2
        ]

        for privateKey in privateKeys {
            // Should not throw
            _ = try PrivateKeySigner(hexPrivateKey: privateKey)
        }
    }
}
