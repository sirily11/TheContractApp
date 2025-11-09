import Testing
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
}
