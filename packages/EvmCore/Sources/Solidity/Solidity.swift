import Foundation

/// Main entry point for the Solidity compiler API.
public struct Solc {
    /// Shared download manager for caching compiler binaries.
    private static let downloadManager = DownloadManager()

    /// Creates a new Solidity compiler instance for a specific version.
    ///
    /// This method automatically downloads the compiler binary if not cached,
    /// then initializes a JavaScriptCore-based compiler instance.
    ///
    /// - Parameter version: The Solidity version (e.g., "0.8.21")
    /// - Returns: A compiler instance ready for compilation
    /// - Throws: `DownloadError` if the binary cannot be downloaded,
    ///           `CompilerError` if initialization fails
    ///
    /// Example:
    /// ```swift
    /// let compiler = try await Solc.create(version: "0.8.21")
    /// defer { try? await compiler.close() }
    ///
    /// let input = Input(
    ///     sources: [
    ///         "Contract.sol": SourceIn(content: "pragma solidity ^0.8.0; contract C {}")
    ///     ],
    ///     settings: Settings(
    ///         outputSelection: ["*": ["*": ["abi", "evm.bytecode"]]]
    ///     )
    /// )
    ///
    /// let output = try await compiler.compile(input, options: nil)
    /// ```
    public static func create(version: String) async throws -> SolidityCompiler {
        // Download or retrieve from cache
        let soljsonJS = try await downloadManager.getBinary(for: version)

        // Create compiler instance
        let compiler = try JSCoreCompiler.create(soljsonJS: soljsonJS)

        return compiler
    }

    /// Returns a list of all available Solidity compiler versions.
    ///
    /// This fetches the version list from binaries.soliditylang.org.
    /// The result is cached to avoid repeated network requests.
    ///
    /// - Returns: Array of version strings (e.g., ["0.8.21", "0.8.20", ...])
    /// - Throws: `DownloadError` if the version list cannot be fetched
    public static func getAvailableVersions() async throws -> [String] {
        try await downloadManager.getAvailableVersions()
    }

    /// Clears the cache for a specific version or all versions.
    ///
    /// - Parameter version: Optional version to clear. If nil, clears all cached binaries.
    /// - Throws: File system errors if cache cannot be cleared
    ///
    /// Example:
    /// ```swift
    /// // Clear a specific version
    /// try await Solc.clearCache(version: "0.8.21")
    ///
    /// // Clear all cached versions
    /// try await Solc.clearCache()
    /// ```
    public static func clearCache(version: String? = nil) async throws {
        try await downloadManager.clearCache(version: version)
    }

    // Private initializer to prevent instantiation
    private init() {}
}
