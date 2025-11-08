import Foundation
import CryptoSwift
import Security

/// BIP39 mnemonic phrase implementation
public struct Mnemonic: BIP39Protocol {
    public let words: [String]
    public let wordlist: BIP39WordlistProtocol

    /// Generate a new random mnemonic
    /// - Parameters:
    ///   - language: The language for the wordlist (default: .english)
    ///   - wordCount: The number of words (default: .twentyFour)
    /// - Returns: A new mnemonic instance
    /// - Throws: BIP39Error if generation fails
    public static func generate(
        language: BIP39Language = .english,
        wordCount: WordCount = .twentyFour
    ) throws -> Mnemonic {
        // Generate random entropy
        let entropy = try generateEntropy(bytes: wordCount.entropyBytes)

        // Get wordlist
        let wordlist = getWordlist(for: language)

        // Generate mnemonic from entropy
        let words = try wordsFromEntropy(entropy, wordlist: wordlist)

        return try Mnemonic(words: words, language: language)
    }

    /// Initialize from existing words
    /// - Parameters:
    ///   - words: Array of mnemonic words
    ///   - language: The language for validation (default: .english)
    /// - Throws: BIP39Error if words are invalid
    public init(words: [String], language: BIP39Language = .english) throws {
        let wordlist = Self.getWordlist(for: language)

        // Validate word count
        guard WordCount(rawValue: words.count) != nil else {
            throw BIP39Error.invalidWordCount(words.count)
        }

        // Validate all words exist in wordlist
        for word in words {
            guard wordlist.index(of: word) != nil else {
                throw BIP39Error.invalidWord(word)
            }
        }

        self.words = words
        self.wordlist = wordlist

        // Validate checksum
        guard isValid() else {
            throw BIP39Error.invalidChecksum
        }
    }

    /// Derive a private key from the mnemonic
    /// - Parameters:
    ///   - derivePath: The derivation path (default: .ethereum)
    ///   - passphrase: Optional passphrase for additional security (default: "")
    /// - Returns: Private key as hex string with 0x prefix
    /// - Throws: BIP39Error if derivation fails
    public func privateKey(
        derivePath: DerivationPath = .ethereum,
        passphrase: String = ""
    ) throws -> String {
        // Generate seed from mnemonic
        let seed = try toSeed(passphrase: passphrase)

        // Derive key using BIP32
        let extendedKey = try BIP32.derive(seed: seed, path: derivePath.pathString)

        return extendedKey.toHexString()
    }

    /// Convert mnemonic to seed bytes
    /// - Parameter passphrase: Optional passphrase (default: "")
    /// - Returns: 64-byte seed
    /// - Throws: BIP39Error if conversion fails
    public func toSeed(passphrase: String = "") throws -> Data {
        // BIP39: seed = PBKDF2(mnemonic, "mnemonic" + passphrase, 2048 rounds, HMAC-SHA512)
        let mnemonicData = words.joined(separator: " ")
        let salt = "mnemonic" + passphrase

        do {
            let password = Array(mnemonicData.utf8)
            let saltBytes = Array(salt.utf8)

            let derivedKey = try PKCS5.PBKDF2(
                password: password,
                salt: saltBytes,
                iterations: 2048,
                keyLength: 64,
                variant: .sha2(.sha512)
            ).calculate()

            return Data(derivedKey)
        } catch {
            throw BIP39Error.seedGenerationFailed
        }
    }

    /// Validate the mnemonic checksum
    /// - Returns: true if valid, false otherwise
    public func isValid() -> Bool {
        do {
            // Convert words to entropy
            let entropyWithChecksum = try Self.entropyFromWords(words, wordlist: wordlist)

            // Calculate checksum
            let checksumBits = words.count / 3 // checksum is entropy_bits / 32
            let entropyBits = words.count * 11 - checksumBits

            let entropyBytes = entropyBits / 8
            let entropy = entropyWithChecksum.prefix(entropyBytes)

            // Calculate expected checksum
            let hash = entropy.sha256()
            let expectedChecksum = hash[0]

            // Extract actual checksum from entropy
            let actualChecksum = entropyWithChecksum[entropyBytes]

            // Compare checksums
            let checksumMask: UInt8 = UInt8((0xFF << (8 - checksumBits)) & 0xFF)

            return (expectedChecksum & checksumMask) == (actualChecksum & checksumMask)
        } catch {
            return false
        }
    }

    // MARK: - Private Helpers

    /// Generate cryptographically secure random entropy
    private static func generateEntropy(bytes: Int) throws -> Data {
        var entropy = Data(count: bytes)
        let result = entropy.withUnsafeMutableBytes { ptr in
            SecRandomCopyBytes(kSecRandomDefault, bytes, ptr.baseAddress!)
        }

        guard result == errSecSuccess else {
            throw BIP39Error.cryptographicFailure("Failed to generate random bytes")
        }

        return entropy
    }

    /// Get wordlist for a specific language
    private static func getWordlist(for language: BIP39Language) -> BIP39WordlistProtocol {
        switch language {
        case .english:
            return EnglishWordlist.shared
        }
    }

    /// Convert entropy to mnemonic words
    private static func wordsFromEntropy(_ entropy: Data, wordlist: BIP39WordlistProtocol) throws -> [String] {
        guard entropy.count >= 16 && entropy.count <= 32 && entropy.count % 4 == 0 else {
            throw BIP39Error.invalidEntropy
        }

        // Calculate checksum
        let hash = entropy.sha256()
        let checksumBits = entropy.count / 4

        // Combine entropy and checksum
        var bits = Data(entropy)
        bits.append(hash[0])

        // Convert to 11-bit indices
        let totalBits = entropy.count * 8 + checksumBits
        let wordCount = totalBits / 11

        var words: [String] = []

        for i in 0..<wordCount {
            let bitPosition = i * 11
            let index = extractBits(from: bits, start: bitPosition, count: 11)

            guard let word = wordlist.word(at: Int(index)) else {
                throw BIP39Error.cryptographicFailure("Invalid word index: \(index)")
            }

            words.append(word)
        }

        return words
    }

    /// Convert mnemonic words to entropy
    private static func entropyFromWords(_ words: [String], wordlist: BIP39WordlistProtocol) throws -> Data {
        var bits: UInt64 = 0
        var bitsCollected = 0
        var result = Data()

        for word in words {
            guard let index = wordlist.index(of: word) else {
                throw BIP39Error.invalidWord(word)
            }

            bits = (bits << 11) | UInt64(index)
            bitsCollected += 11

            while bitsCollected >= 8 {
                let byte = UInt8((bits >> (bitsCollected - 8)) & 0xFF)
                result.append(byte)
                bitsCollected -= 8
            }
        }

        // Add remaining bits
        if bitsCollected > 0 {
            let byte = UInt8((bits << (8 - bitsCollected)) & 0xFF)
            result.append(byte)
        }

        return result
    }

    /// Extract bits from data
    private static func extractBits(from data: Data, start: Int, count: Int) -> UInt16 {
        var result: UInt16 = 0

        for i in 0..<count {
            let bitPosition = start + i
            let byteIndex = bitPosition / 8
            let bitIndex = 7 - (bitPosition % 8)

            if byteIndex < data.count {
                let byte = data[byteIndex]
                let bit = (byte >> bitIndex) & 1
                result = (result << 1) | UInt16(bit)
            }
        }

        return result
    }
}

// MARK: - Convenience Extensions

extension Mnemonic {
    /// Initialize from a space-separated phrase string
    public init(phrase: String, language: BIP39Language = .english) throws {
        let words = phrase.split(separator: " ").map { String($0).lowercased() }
        try self.init(words: words, language: language)
    }

    /// Get the mnemonic as a space-separated phrase
    public var phrase: String {
        return words.joined(separator: " ")
    }

    /// Initialize without checksum validation (for testing or recovery of non-standard mnemonics)
    /// - Parameters:
    ///   - words: Array of mnemonic words
    ///   - language: The language for validation (default: .english)
    ///   - validateChecksum: Whether to validate checksum (default: true)
    /// - Throws: BIP39Error if words are invalid
    public init(words: [String], language: BIP39Language = .english, validateChecksum: Bool) throws {
        let wordlist = Self.getWordlist(for: language)

        // Validate word count
        guard WordCount(rawValue: words.count) != nil else {
            throw BIP39Error.invalidWordCount(words.count)
        }

        // Validate all words exist in wordlist
        for word in words {
            guard wordlist.index(of: word) != nil else {
                throw BIP39Error.invalidWord(word)
            }
        }

        self.words = words
        self.wordlist = wordlist

        // Optionally validate checksum
        if validateChecksum {
            guard isValid() else {
                throw BIP39Error.invalidChecksum
            }
        }
    }
}
