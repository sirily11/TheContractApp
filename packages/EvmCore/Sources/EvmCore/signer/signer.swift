import Foundation

public struct Address {
    public let value: String

    public init(fromHexString value: String) throws {
        // Basic validation: check if it's a valid hex string
        let cleanValue = value.hasPrefix("0x") ? value : "0x" + value

        // Ethereum addresses should be 42 characters (0x + 40 hex chars)
        guard cleanValue.count == 42 else {
            throw AddressError.invalidLength(
                "Address must be 40 hex characters (got \(cleanValue.count - 2))")
        }

        // Validate hex characters
        let hexChars = Set("0123456789abcdefABCDEF")
        let addressChars = String(cleanValue.dropFirst(2))
        guard addressChars.allSatisfy({ hexChars.contains($0) }) else {
            throw AddressError.invalidCharacters("Address contains invalid hex characters")
        }

        // Preserve the case (EIP-55 checksum encoding)
        self.value = cleanValue
    }

    /// Convenience initializer that accepts a hex string
    public init(_ value: String) throws {
        try self.init(fromHexString: value)
    }
}

/// Errors related to address operations
public enum AddressError: Error, LocalizedError {
    case invalidLength(String)
    case invalidCharacters(String)

    public var errorDescription: String? {
        switch self {
        case .invalidLength(let message):
            return "Invalid address length: \(message)"
        case .invalidCharacters(let message):
            return "Invalid address characters: \(message)"
        }
    }
}

public protocol Signer {
    /// The address associated with this signer
    var address: Address { get }

    /// Signs a message using the signer
    /// - Parameter message: The message to sign (will be hashed with keccak256)
    /// - Returns: The signature (65 bytes: r + s + v)
    func sign(message: Data) async throws -> Data

    /// Verifies a signature using the signer
    /// - Parameter address: The address to verify
    /// - Parameter message: The message to verify
    /// - Parameter signature: The signature to verify
    /// - Returns: True if the signature is valid, false otherwise
    func verify(address: Address, message: Data, signature: Data) async throws -> Bool
}
