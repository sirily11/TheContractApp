import Foundation

/// Errors that can occur during BIP39 operations
public enum BIP39Error: Error, LocalizedError {
    case invalidWordCount(Int)
    case invalidWord(String)
    case invalidChecksum
    case invalidEntropy
    case seedGenerationFailed
    case keyDerivationFailed
    case cryptographicFailure(String)

    public var errorDescription: String? {
        switch self {
        case .invalidWordCount(let count):
            return "Invalid word count: \(count). Must be 12, 15, 18, 21, or 24."
        case .invalidWord(let word):
            return "Invalid word in mnemonic: '\(word)'"
        case .invalidChecksum:
            return "Invalid mnemonic checksum"
        case .invalidEntropy:
            return "Invalid entropy length"
        case .seedGenerationFailed:
            return "Failed to generate seed from mnemonic"
        case .keyDerivationFailed:
            return "Failed to derive key"
        case .cryptographicFailure(let message):
            return "Cryptographic operation failed: \(message)"
        }
    }
}

/// Errors that can occur during BIP32 operations
public enum BIP32Error: Error, LocalizedError {
    case invalidSeed
    case invalidPath(String)
    case invalidIndex(UInt32)
    case invalidKey
    case derivationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidSeed:
            return "Invalid seed for BIP32 derivation"
        case .invalidPath(let path):
            return "Invalid derivation path: '\(path)'"
        case .invalidIndex(let index):
            return "Invalid child index: \(index)"
        case .invalidKey:
            return "Invalid extended key"
        case .derivationFailed(let message):
            return "Key derivation failed: \(message)"
        }
    }
}
