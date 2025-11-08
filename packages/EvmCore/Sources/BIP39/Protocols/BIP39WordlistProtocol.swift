import Foundation

/// Protocol for BIP39 wordlist implementations
public protocol BIP39WordlistProtocol {
    /// The complete list of BIP39 words
    /// Must contain exactly 2048 words
    var words: [String] { get }

    /// Get the index of a word in the wordlist
    /// - Parameter word: The word to look up
    /// - Returns: The index of the word, or nil if not found
    func index(of word: String) -> Int?

    /// Get a word at a specific index
    /// - Parameter index: The index (0-2047)
    /// - Returns: The word at the index, or nil if index is out of bounds
    func word(at index: Int) -> String?
}

/// Language options for BIP39 wordlists
public enum BIP39Language {
    case english
    // Future: .chinese, .spanish, .french, etc.
}
