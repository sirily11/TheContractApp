import CryptoSwift
import Foundation
import libsecp256k1

/// A signer implementation that uses a secp256k1 private key for signing operations.
///
/// This signer performs actual cryptographic signing using ECDSA with the secp256k1 curve,
/// which is the standard signing algorithm for Ethereum transactions.
public struct PrivateKeySigner: Signer {
    public let address: Address
    private let privateKey: Data

    /// Initialize with a private key
    /// - Parameter privateKey: The private key data (32 bytes)
    /// - Throws: `SignerError.invalidPrivateKey` if the key is invalid
    public init(privateKey: Data) throws {
        guard privateKey.count == 32 else {
            throw SignerError.invalidPrivateKey
        }

        // Validate the private key using secp256k1
        guard let ctx = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY)) else {
            throw SignerError.invalidPrivateKey
        }
        defer { secp256k1_context_destroy(ctx) }

        let privateKeyPtr = (privateKey as NSData).bytes.assumingMemoryBound(to: UInt8.self)
        guard secp256k1_ec_seckey_verify(ctx, privateKeyPtr) == 1 else {
            throw SignerError.invalidPrivateKey
        }

        self.privateKey = privateKey

        // Derive the Ethereum address from the private key
        self.address = try Self.generateAddress(from: privateKey)
    }

    /// Convenience initializer with hex string private key
    /// - Parameter hexPrivateKey: Hex string of the private key (with or without 0x prefix)
    /// - Throws: `SignerError.invalidPrivateKey` if the key is invalid
    public init(hexPrivateKey: String) throws {
        let cleanHex =
            hexPrivateKey.hasPrefix("0x")
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
        guard let privateKey = Data.randomOfLength(32) else {
            throw SignerError.invalidPrivateKey
        }
        return try PrivateKeySigner(privateKey: privateKey)
    }

    /// Signs a message using the private key with Ethereum's signing scheme
    /// - Parameter message: The message to sign (will be hashed with keccak256)
    /// - Returns: The signature (65 bytes: r + s + v)
    public func sign(message: Data) async throws -> Data {
        guard let ctx = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY)) else {
            throw SignerError.signingFailed(
                NSError(domain: "PrivateKeySigner", code: -1,
                       userInfo: [NSLocalizedDescriptionKey: "Invalid context"]))
        }

        defer {
            secp256k1_context_destroy(ctx)
        }

        let msgData = message.sha3(.keccak256)
        let msg = (msgData as NSData).bytes.assumingMemoryBound(to: UInt8.self)
        let privateKeyPtr = (privateKey as NSData).bytes.assumingMemoryBound(to: UInt8.self)
        let signaturePtr = UnsafeMutablePointer<secp256k1_ecdsa_recoverable_signature>.allocate(capacity: 1)
        defer {
            signaturePtr.deallocate()
        }
        guard secp256k1_ecdsa_sign_recoverable(ctx, signaturePtr, msg, privateKeyPtr, nil, nil) == 1 else {
            throw SignerError.signingFailed(
                NSError(domain: "PrivateKeySigner", code: -1,
                       userInfo: [NSLocalizedDescriptionKey: "Recoverable ECDSA signature creation failed"]))
        }

        let outputPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
        defer {
            outputPtr.deallocate()
        }
        var recid: Int32 = 0
        secp256k1_ecdsa_recoverable_signature_serialize_compact(ctx, outputPtr, &recid, signaturePtr)

        let outputWithRecidPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: 65)
        defer {
            outputWithRecidPtr.deallocate()
        }
        outputWithRecidPtr.update(from: outputPtr, count: 64)
        outputWithRecidPtr.advanced(by: 64).pointee = UInt8(recid + 27)  // Convert to Ethereum format

        let signature = Data(bytes: outputWithRecidPtr, count: 65)

        return signature
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
            let recoveredAddress = try Self.recoverPublicKey(message: messageHash, signature: signature)

            return recoveredAddress.lowercased() == address.value.lowercased()
        } catch {
            return false
        }
    }

    // MARK: - Private Helper Methods

    /// Generate public key from private key
    private static func generatePublicKey(from privateKey: Data) throws -> Data {
        guard let ctx = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY)) else {
            throw SignerError.invalidPrivateKey
        }

        defer {
            secp256k1_context_destroy(ctx)
        }

        let privateKeyPtr = (privateKey as NSData).bytes.assumingMemoryBound(to: UInt8.self)
        guard secp256k1_ec_seckey_verify(ctx, privateKeyPtr) == 1 else {
            throw SignerError.invalidPrivateKey
        }

        let publicKeyPtr = UnsafeMutablePointer<secp256k1_pubkey>.allocate(capacity: 1)
        defer {
            publicKeyPtr.deallocate()
        }
        guard secp256k1_ec_pubkey_create(ctx, publicKeyPtr, privateKeyPtr) == 1 else {
            throw SignerError.signingFailed(
                NSError(domain: "PrivateKeySigner", code: -1,
                       userInfo: [NSLocalizedDescriptionKey: "Public key could not be created"]))
        }

        var publicKeyLength = 65
        let outputPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: publicKeyLength)
        defer {
            outputPtr.deallocate()
        }
        secp256k1_ec_pubkey_serialize(ctx, outputPtr, &publicKeyLength, publicKeyPtr, UInt32(SECP256K1_EC_UNCOMPRESSED))

        let publicKey = Data(bytes: outputPtr, count: publicKeyLength).subdata(in: 1 ..< publicKeyLength)

        return publicKey
    }

    /// Generate Ethereum address from private key
    private static func generateAddress(from privateKey: Data) throws -> Address {
        let publicKey = try generatePublicKey(from: privateKey)
        let hash = publicKey.sha3(.keccak256)
        let addressData = hash.subdata(in: 12 ..< hash.count)
        let checksummedAddress = toChecksumAddress(addressData.toHexString())
        return try Address(checksummedAddress)
    }

    /// Apply EIP-55 checksum encoding to an address
    private static func toChecksumAddress(_ address: String) -> String {
        // Remove 0x prefix if present
        let addr = address.hasPrefix("0x") ? String(address.dropFirst(2)) : address
        let lowercaseAddr = addr.lowercased()

        // Hash the lowercase address
        let hash = Data(lowercaseAddr.utf8).sha3(.keccak256)

        var checksummed = "0x"
        for (i, char) in lowercaseAddr.enumerated() {
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

    /// Recover public key (as address) from signature
    private static func recoverPublicKey(message: Data, signature: Data) throws -> String {
        if signature.count != 65 || message.count != 32 {
            throw SignerError.signingFailed(
                NSError(domain: "PrivateKeySigner", code: -1,
                       userInfo: [NSLocalizedDescriptionKey: "Bad arguments"]))
        }

        guard let ctx = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY)) else {
            throw SignerError.signingFailed(
                NSError(domain: "PrivateKeySigner", code: -1,
                       userInfo: [NSLocalizedDescriptionKey: "Invalid context"]))
        }
        defer { secp256k1_context_destroy(ctx) }

        // get recoverable signature
        let signaturePtr = UnsafeMutablePointer<secp256k1_ecdsa_recoverable_signature>.allocate(capacity: 1)
        defer { signaturePtr.deallocate() }

        let serializedSignature = Data(signature[0 ..< 64])
        var v = Int32(signature[64])
        if v >= 27, v <= 30 {
            v -= 27
        } else if v >= 31, v <= 34 {
            v -= 31
        } else if v >= 35, v <= 38 {
            v -= 35
        }

        try serializedSignature.withUnsafeBytes {
            guard secp256k1_ecdsa_recoverable_signature_parse_compact(ctx, signaturePtr, $0.bindMemory(to: UInt8.self).baseAddress!, v) == 1 else {
                throw SignerError.signingFailed(
                    NSError(domain: "PrivateKeySigner", code: -1,
                           userInfo: [NSLocalizedDescriptionKey: "Recoverable ECDSA signature parse failed"]))
            }
        }
        let pubkey = UnsafeMutablePointer<secp256k1_pubkey>.allocate(capacity: 1)
        defer { pubkey.deallocate() }

        try message.withUnsafeBytes {
            guard secp256k1_ecdsa_recover(ctx, pubkey, signaturePtr, $0.bindMemory(to: UInt8.self).baseAddress!) == 1 else {
                throw SignerError.signingFailed(
                    NSError(domain: "PrivateKeySigner", code: -1,
                           userInfo: [NSLocalizedDescriptionKey: "Signature failure"]))
            }
        }
        var size = 65
        var rv = Data(count: size)
        _ = rv.withUnsafeMutableBytes {
            secp256k1_ec_pubkey_serialize(ctx, $0.bindMemory(to: UInt8.self).baseAddress!, &size, pubkey, UInt32(SECP256K1_EC_UNCOMPRESSED))
        }
        return "0x\(rv[1...].sha3(.keccak256).toHexString().suffix(40))"
    }
}

// MARK: - Data Extensions

extension Data {
    /// Generate random data of specified length
    static func randomOfLength(_ length: Int) -> Data? {
        var data = Data(count: length)
        let result = data.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, length, $0.baseAddress!)
        }
        return result == errSecSuccess ? data : nil
    }
}
