import Foundation

/// Protocol for BIP39 mnemonic phrase operations
public protocol BIP39Protocol {
    /// The mnemonic words
    var words: [String] { get }

    /// The wordlist used for this mnemonic
    var wordlist: BIP39WordlistProtocol { get }

    /// Generate a new random mnemonic
    /// - Parameters:
    ///   - language: The language for the wordlist (default: .english)
    ///   - wordCount: The number of words (default: .twentyFour)
    /// - Returns: A new mnemonic instance
    /// - Throws: BIP39Error if generation fails
    static func generate(language: BIP39Language, wordCount: WordCount) throws -> Self

    /// Initialize from existing words
    /// - Parameters:
    ///   - words: Array of mnemonic words
    ///   - language: The language for validation (default: .english)
    /// - Throws: BIP39Error if words are invalid
    init(words: [String], language: BIP39Language) throws

    /// Derive a private key from the mnemonic
    /// - Parameters:
    ///   - derivePath: The derivation path (default: .ethereum)
    ///   - passphrase: Optional passphrase for additional security (default: "")
    /// - Returns: Private key as hex string with 0x prefix
    /// - Throws: BIP39Error if derivation fails
    func privateKey(derivePath: DerivationPath, passphrase: String) throws -> String

    /// Convert mnemonic to seed bytes
    /// - Parameter passphrase: Optional passphrase (default: "")
    /// - Returns: 64-byte seed
    /// - Throws: BIP39Error if conversion fails
    func toSeed(passphrase: String) throws -> Data

    /// Validate the mnemonic checksum
    /// - Returns: true if valid, false otherwise
    func isValid() -> Bool
}

/// Word count options for BIP39 mnemonics
public enum WordCount: Int {
    case twelve = 12       // 128 bits entropy
    case fifteen = 15      // 160 bits entropy
    case eighteen = 18     // 192 bits entropy
    case twentyOne = 21    // 224 bits entropy
    case twentyFour = 24   // 256 bits entropy

    /// Entropy size in bytes
    var entropyBytes: Int {
        switch self {
        case .twelve: return 16
        case .fifteen: return 20
        case .eighteen: return 24
        case .twentyOne: return 28
        case .twentyFour: return 32
        }
    }

    /// Checksum size in bits
    var checksumBits: Int {
        entropyBytes / 4
    }
}
