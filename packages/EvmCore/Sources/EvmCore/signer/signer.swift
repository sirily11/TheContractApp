import Foundation

public struct Address {
    let value: String

    public init(fromHexString value: String) {
        self.value = value
    }
}

public protocol Signer {
    // Signs a message using the signer
    // - Parameter message: The message to sign
    // - Returns: The signed message
    func sign(message: Data) async throws -> Data

    // Verifies a signature using the signer
    // - Parameter address: The address to verify
    // - Parameter message: The message to verify
    // - Parameter signature: The signature to verify
    // - Returns: True if the signature is valid, false otherwise
    func verify(address: Address, message: Data, signature: Data) async throws -> Bool
}
