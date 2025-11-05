import Foundation

/// A signer implementation for Anvil test network that relies on Anvil's implicit signing.
///
/// Anvil automatically signs transactions sent via `eth_sendTransaction` using the managed
/// test accounts, so we don't need to implement cryptographic signing ourselves.
/// This is appropriate for testing but should not be used in production.
public struct AnvilSigner: Signer {
    public let address: Address

    /// Initialize with an Anvil test account address
    /// - Parameter address: The address of one of Anvil's test accounts
    public init(address: Address) {
        self.address = address
    }

    /// Convenience initializer with address string
    /// - Parameter addressString: Hex string of the address (with or without 0x prefix)
    public init(addressString: String) throws {
        self.address = try Address(fromHexString: addressString)
    }

    /// Not used in Anvil testing - Anvil handles signing via eth_sendTransaction
    public func sign(message: Data) async throws -> Data {
        throw SignerError.unsupportedOperation("AnvilSigner uses implicit signing via eth_sendTransaction")
    }

    /// Not used in Anvil testing
    public func verify(address: Address, message: Data, signature: Data) async throws -> Bool {
        throw SignerError.unsupportedOperation("AnvilSigner uses implicit signing via eth_sendTransaction")
    }
}

/// Errors that can occur during signing operations
public enum SignerError: Error, LocalizedError {
    case unsupportedOperation(String)
    case invalidPrivateKey
    case signingFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .unsupportedOperation(let message):
            return "Unsupported operation: \(message)"
        case .invalidPrivateKey:
            return "Invalid private key"
        case .signingFailed(let error):
            return "Signing failed: \(error.localizedDescription)"
        }
    }
}

/// Anvil's default test accounts with known addresses
public struct AnvilAccounts {
    /// First Anvil test account (has 10000 ETH by default)
    public static let account0 = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

    /// Second Anvil test account
    public static let account1 = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"

    /// Third Anvil test account
    public static let account2 = "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"

    /// All default Anvil test accounts
    public static let allAccounts = [
        account0, account1, account2,
        "0x90F79bf6EB2c4f870365E785982E1f101E93b906",
        "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65",
        "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc",
        "0x976EA74026E726554dB657fA54763abd0C3a0aa9",
        "0x14dC79964da2C08b23698B3D3cc7Ca32193d9955",
        "0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f",
        "0xa0Ee7A142d267C1f36714E4a8F75612F20a79720"
    ]
}
