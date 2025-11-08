import Foundation
import BigInt

/// Protocol for BIP32 hierarchical deterministic key derivation
public protocol BIP32Protocol {
    /// Derive a master key from a seed
    /// - Parameter seed: 64-byte seed (typically from BIP39)
    /// - Returns: Extended private key
    /// - Throws: BIP32Error if derivation fails
    static func deriveMasterKey(from seed: Data) throws -> ExtendedPrivateKey

    /// Derive a child key from a parent key
    /// - Parameters:
    ///   - parent: Parent extended private key
    ///   - index: Child index (use index >= 2^31 for hardened derivation)
    /// - Returns: Child extended private key
    /// - Throws: BIP32Error if derivation fails
    static func deriveChild(from parent: ExtendedPrivateKey, index: UInt32) throws -> ExtendedPrivateKey

    /// Derive a key following a complete derivation path
    /// - Parameters:
    ///   - seed: 64-byte seed
    ///   - path: Derivation path (e.g., "m/44'/60'/0'/0/0")
    /// - Returns: Derived extended private key
    /// - Throws: BIP32Error if derivation fails
    static func derive(seed: Data, path: String) throws -> ExtendedPrivateKey
}

/// Represents an extended private key in BIP32
public struct ExtendedPrivateKey {
    /// The private key bytes (32 bytes)
    public let key: Data

    /// The chain code (32 bytes)
    public let chainCode: Data

    /// Derivation depth
    public let depth: UInt8

    /// Parent fingerprint
    public let parentFingerprint: UInt32

    /// Child index
    public let childIndex: UInt32

    public init(
        key: Data,
        chainCode: Data,
        depth: UInt8 = 0,
        parentFingerprint: UInt32 = 0,
        childIndex: UInt32 = 0
    ) {
        self.key = key
        self.chainCode = chainCode
        self.depth = depth
        self.parentFingerprint = parentFingerprint
        self.childIndex = childIndex
    }

    /// Convert private key to hex string with 0x prefix
    public func toHexString() -> String {
        return "0x" + key.map { String(format: "%02x", $0) }.joined()
    }
}
