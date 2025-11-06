import Foundation
import CryptoSwift
import P256K

/// A signer implementation that uses a secp256k1 private key for signing operations.
///
/// This signer performs actual cryptographic signing using ECDSA with the secp256k1 curve,
/// which is the standard signing algorithm for Ethereum transactions.
public struct PrivateKeySigner: Signer {
    public let address: Address
    private let privateKey: P256K.Signing.PrivateKey

    /// Initialize with a private key
    /// - Parameter privateKey: The private key data (32 bytes)
    /// - Throws: `SignerError.invalidPrivateKey` if the key is invalid
    public init(privateKey: Data) throws {
        guard privateKey.count == 32 else {
            throw SignerError.invalidPrivateKey
        }

        do {
            self.privateKey = try P256K.Signing.PrivateKey(dataRepresentation: privateKey)
        } catch {
            throw SignerError.invalidPrivateKey
        }

        // Derive the Ethereum address from the private key
        self.address = try Self.deriveAddress(from: self.privateKey)
    }

    /// Convenience initializer with hex string private key
    /// - Parameter hexPrivateKey: Hex string of the private key (with or without 0x prefix)
    /// - Throws: `SignerError.invalidPrivateKey` if the key is invalid
    public init(hexPrivateKey: String) throws {
        let cleanHex = hexPrivateKey.hasPrefix("0x")
            ? String(hexPrivateKey.dropFirst(2))
            : hexPrivateKey

        // Convert hex string to Data using CryptoSwift
        let keyData = Data(hex: cleanHex)
        guard keyData.count == 32 else {
            throw SignerError.invalidPrivateKey
        }

        try self.init(privateKey: keyData)
    }

    /// Generates a new random private key signer
    /// - Returns: A new PrivateKeySigner with a randomly generated private key
    public static func random() throws -> PrivateKeySigner {
        let privateKey = try P256K.Signing.PrivateKey()
        return try PrivateKeySigner(privateKey: privateKey.dataRepresentation)
    }

    /// Signs a message using the private key with Ethereum's signing scheme
    /// - Parameter message: The message to sign (will be hashed with keccak256)
    /// - Returns: The signature (65 bytes: r + s + v)
    public func sign(message: Data) async throws -> Data {
        do {
            // Hash the message with keccak256
            let messageHash = message.sha3(.keccak256)

            // Create recovery private key for signing with recovery
            let recoveryKey = try P256K.Recovery.PrivateKey(dataRepresentation: privateKey.dataRepresentation)

            // Sign the message hash
            let signature = try recoveryKey.signature(for: messageHash)

            // Get compact representation and recovery ID
            let compactSig = try signature.compactRepresentation

            // Convert to Ethereum format (r + s + v)
            let r = compactSig.signature.prefix(32)
            let s = compactSig.signature.dropFirst(32).prefix(32)
            let v = UInt8(compactSig.recoveryId + 27) // Ethereum uses 27/28 instead of 0/1

            var ethereumSig = Data()
            ethereumSig.append(r)
            ethereumSig.append(s)
            ethereumSig.append(v)

            return ethereumSig

        } catch let error as SignerError {
            throw error
        } catch {
            throw SignerError.signingFailed(error)
        }
    }

    /// Verifies a signature
    /// - Parameters:
    ///   - address: The address that allegedly signed the message
    ///   - message: The original message
    ///   - signature: The signature to verify (65 bytes: r + s + v)
    /// - Returns: True if the signature is valid for the given address and message
    public func verify(address: Address, message: Data, signature: Data) async throws -> Bool {
        guard signature.count == 65 else {
            return false
        }

        do {
            // Hash the message
            let messageHash = message.sha3(.keccak256)

            // Recover the address from the signature
            let recoveredAddress = try Self.recoverAddress(from: signature, messageHash: messageHash)

            return recoveredAddress.value.lowercased() == address.value.lowercased()
        } catch {
            return false
        }
    }

    // MARK: - Private Helper Methods

    /// Derives an Ethereum address from a private key
    private static func deriveAddress(from privateKey: P256K.Signing.PrivateKey) throws -> Address {
        // Get the public key in uncompressed format (65 bytes: 0x04 + x + y)
        // The publicKey.dataRepresentation returns compressed format by default (33 bytes)
        // We need to use combine with uncompressed format to get the full 65-byte key
        let publicKey = privateKey.publicKey
        var publicKeyData = try publicKey.combine([], format: .uncompressed).dataRepresentation

        // If the public key starts with 0x04 (uncompressed format marker), remove it
        // Ethereum address derivation requires only the 64-byte key (x, y coordinates)
        if publicKeyData.count == 65 && publicKeyData.first == 0x04 {
            publicKeyData = publicKeyData.dropFirst()
        }

        // Hash the 64-byte public key with keccak256
        let hash = Array(publicKeyData.sha3(.keccak256))

        // Take the last 20 bytes as the address
        let addressBytes = hash.suffix(20)

        // Apply EIP-55 checksum encoding
        let addressHex = "0x" + toChecksumAddress(addressBytes)

        return try Address(fromHexString: addressHex)
    }

    /// Applies EIP-55 checksum encoding to an address
    /// - Parameter addressBytes: The 20-byte address
    /// - Returns: Checksummed hex string (without 0x prefix)
    private static func toChecksumAddress(_ addressBytes: ArraySlice<UInt8>) -> String {
        // Convert to lowercase hex
        let lowercaseHex = addressBytes.map { String(format: "%02x", $0) }.joined()

        // Hash the lowercase address
        let hashData = Data(lowercaseHex.utf8)
        let hash = hashData.sha3(.keccak256)

        // Apply checksum: capitalize hex digits where hash byte >= 8
        var checksummed = ""
        for (i, char) in lowercaseHex.enumerated() {
            let hashByte = hash[i / 2]
            let hashNibble = (i % 2 == 0) ? (hashByte >> 4) : (hashByte & 0x0f)

            if char.isLetter && hashNibble >= 8 {
                checksummed.append(char.uppercased())
            } else {
                checksummed.append(char)
            }
        }

        return checksummed
    }

    /// Recovers an Ethereum address from a signature and message hash
    private static func recoverAddress(from signature: Data, messageHash: Data) throws -> Address {
        guard signature.count == 65 else {
            throw SignerError.signingFailed(NSError(domain: "PrivateKeySigner", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid signature length"]))
        }

        // Extract r, s, v from Ethereum signature format
        let r = signature.prefix(32)
        let s = signature.dropFirst(32).prefix(32)
        let v = signature.last!

        // Convert v from Ethereum format (27/28) to recovery ID (0/1)
        let recoveryId = Int32(v >= 27 ? v - 27 : v)

        // Create compact signature (r + s)
        var compactSig = Data()
        compactSig.append(r)
        compactSig.append(s)

        // Create P256K recoverable signature
        let recoverySignature = try P256K.Recovery.ECDSASignature(
            compactRepresentation: compactSig,
            recoveryId: recoveryId
        )

        // Recover the public key (returns compressed format - 33 bytes)
        let recoveredPublicKey = try P256K.Recovery.PublicKey(messageHash, signature: recoverySignature)

        // Convert to Signing.PublicKey to use combine method for uncompressed format
        let compressedData = recoveredPublicKey.dataRepresentation
        let signingPublicKey = try P256K.Signing.PublicKey(dataRepresentation: compressedData, format: .compressed)

        // Get uncompressed format (65 bytes: 0x04 + x + y)
        var publicKeyData = try signingPublicKey.combine([], format: .uncompressed).dataRepresentation
        if publicKeyData.count == 65 && publicKeyData.first == 0x04 {
            publicKeyData = publicKeyData.dropFirst()
        }

        // Hash the 64-byte public key with keccak256
        let hash = Array(publicKeyData.sha3(CryptoSwift.SHA3.Variant.keccak256))

        // Take the last 20 bytes as the address
        let addressBytes = hash.suffix(20)

        // Apply EIP-55 checksum encoding
        let addressHex = "0x" + toChecksumAddress(addressBytes)

        return try Address(fromHexString: addressHex)
    }
}

