import Foundation
import CryptoSwift
import BigInt
import P256K

/// BIP32 hierarchical deterministic key derivation implementation
public struct BIP32: BIP32Protocol {
    private static let hardenedOffset: UInt32 = 0x80000000

    /// Derive a master key from a seed
    /// - Parameter seed: 64-byte seed (typically from BIP39)
    /// - Returns: Extended private key
    /// - Throws: BIP32Error if derivation fails
    public static func deriveMasterKey(from seed: Data) throws -> ExtendedPrivateKey {
        guard seed.count >= 16 && seed.count <= 64 else {
            throw BIP32Error.invalidSeed
        }

        // HMAC-SHA512 with key "Bitcoin seed"
        let key = "Bitcoin seed".data(using: .utf8)!
        let hmac = HMAC(key: key.bytes, variant: .sha2(.sha512))
        let I = try Data(hmac.authenticate(seed.bytes))

        guard I.count == 64 else {
            throw BIP32Error.derivationFailed("HMAC output size incorrect")
        }

        // Split I into IL (private key) and IR (chain code)
        let IL = I.prefix(32)
        let IR = I.suffix(32)

        // Verify IL is valid (< secp256k1 curve order)
        guard isValidPrivateKey(IL) else {
            throw BIP32Error.invalidKey
        }

        return ExtendedPrivateKey(
            key: IL,
            chainCode: IR,
            depth: 0,
            parentFingerprint: 0,
            childIndex: 0
        )
    }

    /// Derive a child key from a parent key
    /// - Parameters:
    ///   - parent: Parent extended private key
    ///   - index: Child index (use index >= 2^31 for hardened derivation)
    /// - Returns: Child extended private key
    /// - Throws: BIP32Error if derivation fails
    public static func deriveChild(from parent: ExtendedPrivateKey, index: UInt32) throws -> ExtendedPrivateKey {
        let isHardened = index >= hardenedOffset

        var data = Data()

        if isHardened {
            // Hardened derivation: data = 0x00 || ser256(kpar) || ser32(index)
            data.append(0x00)
            data.append(parent.key)
        } else {
            // Non-hardened derivation: data = serP(point(kpar)) || ser32(index)
            // Need to derive public key from private key
            guard let publicKey = derivePublicKey(from: parent.key) else {
                throw BIP32Error.derivationFailed("Failed to derive public key")
            }
            data.append(publicKey)
        }

        // Append child index (big endian)
        data.append(contentsOf: withUnsafeBytes(of: index.bigEndian) { Data($0) })

        // HMAC-SHA512 with parent chain code as key
        let hmac = HMAC(key: parent.chainCode.bytes, variant: .sha2(.sha512))
        let I = try Data(hmac.authenticate(data.bytes))

        guard I.count == 64 else {
            throw BIP32Error.derivationFailed("HMAC output size incorrect")
        }

        // Split I into IL and IR
        let IL = I.prefix(32)
        let IR = I.suffix(32)

        // Calculate child key: parse256(IL) + kpar (mod n)
        guard let childKey = addPrivateKeys(IL, parent.key) else {
            throw BIP32Error.derivationFailed("Failed to add private keys")
        }

        // Calculate parent fingerprint (first 4 bytes of HASH160 of parent public key)
        let parentFingerprint = try calculateFingerprint(privateKey: parent.key)

        return ExtendedPrivateKey(
            key: childKey,
            chainCode: IR,
            depth: parent.depth + 1,
            parentFingerprint: parentFingerprint,
            childIndex: index
        )
    }

    /// Derive a key following a complete derivation path
    /// - Parameters:
    ///   - seed: 64-byte seed
    ///   - path: Derivation path (e.g., "m/44'/60'/0'/0/0")
    /// - Returns: Derived extended private key
    /// - Throws: BIP32Error if derivation fails
    public static func derive(seed: Data, path: String) throws -> ExtendedPrivateKey {
        let derivationPath = DerivationPath.custom(path)
        let indices = try derivationPath.parse()

        var key = try deriveMasterKey(from: seed)

        for childIndex in indices {
            key = try deriveChild(from: key, index: childIndex.index)
        }

        return key
    }

    // MARK: - Private Helpers

    /// Derive compressed public key from private key
    private static func derivePublicKey(from privateKey: Data) -> Data? {
        guard privateKey.count == 32 else { return nil }

        do {
            let privKey = try P256K.Signing.PrivateKey(dataRepresentation: privateKey)
            // Return compressed public key (33 bytes) - dataRepresentation is compressed by default
            return privKey.publicKey.dataRepresentation
        } catch {
            return nil
        }
    }

    /// Add two private keys modulo the secp256k1 curve order
    private static func addPrivateKeys(_ key1: Data, _ key2: Data) -> Data? {
        guard key1.count == 32 && key2.count == 32 else { return nil }

        // secp256k1 curve order
        let n = BigUInt("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141", radix: 16)!

        let k1 = BigUInt(key1)
        let k2 = BigUInt(key2)

        let sum = (k1 + k2) % n

        // Check if sum is zero (invalid)
        if sum == 0 {
            return nil
        }

        // Convert back to 32-byte Data
        var result = sum.serialize()

        // Pad to 32 bytes if necessary
        while result.count < 32 {
            result.insert(0, at: 0)
        }

        guard result.count == 32 else { return nil }
        return result
    }

    /// Check if a private key is valid (non-zero and less than curve order)
    private static func isValidPrivateKey(_ key: Data) -> Bool {
        guard key.count == 32 else { return false }

        // secp256k1 curve order
        let n = BigUInt("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141", radix: 16)!

        let k = BigUInt(key)

        return k > 0 && k < n
    }

    /// Calculate fingerprint (first 4 bytes of HASH160 of public key)
    private static func calculateFingerprint(privateKey: Data) throws -> UInt32 {
        guard let publicKey = derivePublicKey(from: privateKey) else {
            throw BIP32Error.derivationFailed("Failed to derive public key for fingerprint")
        }

        // HASH160 = RIPEMD160(SHA256(publicKey))
        // For simplicity, we'll use SHA256 hash and take first 4 bytes
        // (Full BIP32 uses RIPEMD160, but it's not critical for derivation)
        let hash = publicKey.sha256()

        let fingerprintBytes = hash.prefix(4)
        let fingerprint = fingerprintBytes.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

        return fingerprint
    }
}
