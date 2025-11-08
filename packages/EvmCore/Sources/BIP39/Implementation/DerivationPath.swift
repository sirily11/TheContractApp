import Foundation

/// BIP32/BIP44 derivation path options
public enum DerivationPath {
    /// Standard Ethereum path: m/44'/60'/0'/0/0
    case ethereum

    /// Custom derivation path
    case custom(String)

    /// Get the path string
    public var pathString: String {
        switch self {
        case .ethereum:
            return "m/44'/60'/0'/0/0"
        case .custom(let path):
            return path
        }
    }

    /// Parse a derivation path string into components
    /// - Returns: Array of child indices (with hardened flag)
    /// - Throws: BIP32Error if path is invalid
    func parse() throws -> [ChildIndex] {
        let pathString = self.pathString

        // Remove "m/" prefix if present
        let components: [String]
        if pathString.hasPrefix("m/") {
            components = String(pathString.dropFirst(2)).split(separator: "/").map(String.init)
        } else if pathString.hasPrefix("M/") {
            components = String(pathString.dropFirst(2)).split(separator: "/").map(String.init)
        } else {
            throw BIP32Error.invalidPath(pathString)
        }

        var indices: [ChildIndex] = []
        for component in components {
            // Check if hardened (ends with ')
            let isHardened = component.hasSuffix("'")
            let numberString = isHardened ? String(component.dropLast()) : component

            guard let index = UInt32(numberString) else {
                throw BIP32Error.invalidPath("Invalid index: \(component)")
            }

            // Hardened indices start at 2^31
            let finalIndex = isHardened ? (index + 0x80000000) : index
            indices.append(ChildIndex(index: finalIndex, hardened: isHardened))
        }

        return indices
    }
}

/// Represents a child index in BIP32 derivation
public struct ChildIndex {
    public let index: UInt32
    public let hardened: Bool

    public init(index: UInt32, hardened: Bool) {
        self.index = index
        self.hardened = hardened
    }
}

// Default parameter values
extension DerivationPath {
    /// Default derivation path for Ethereum
    public static var `default`: DerivationPath {
        return .ethereum
    }
}
