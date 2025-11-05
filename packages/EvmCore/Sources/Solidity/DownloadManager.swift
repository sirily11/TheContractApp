import Foundation

/// Errors that can occur during download operations.
enum DownloadError: Error {
    case invalidURL(String)
    case networkError(Error)
    case httpError(statusCode: Int, message: String)
    case versionNotFound(String)
    case cacheError(String)
    case invalidResponse
}

/// Manages downloading and caching of Solidity compiler binaries.
actor DownloadManager {
    /// Base URL for Solidity compiler binaries.
    private static let baseURL = "https://binaries.soliditylang.org/bin"

    /// Cache directory for storing downloaded binaries.
    private let cacheDirectory: URL

    /// URLSession for network requests.
    private let session: URLSession

    /// Cached version list to avoid repeated network requests.
    private var cachedVersionList: VersionList?

    init(cacheDirectory: URL? = nil, session: URLSession = .shared) {
        // Use custom cache directory or default to system cache
        if let customDir = cacheDirectory {
            self.cacheDirectory = customDir
        } else {
            let defaultCache = FileManager.default.urls(
                for: .cachesDirectory,
                in: .userDomainMask
            ).first!
            self.cacheDirectory = defaultCache.appendingPathComponent("solc", isDirectory: true)
        }

        self.session = session
    }

    // MARK: - Public API

    /// Downloads or retrieves from cache the compiler binary for a specific version.
    /// - Parameter version: The Solidity version (e.g., "0.8.21")
    /// - Returns: The soljson.js content as a string
    func getBinary(for version: String) async throws -> String {
        // Check cache first
        if let cached = try? await loadFromCache(version: version) {
            return cached
        }

        // Resolve version to filename
        let filename = try await resolveVersion(version)

        // Download binary
        let binary = try await downloadBinary(filename: filename)

        // Save to cache (non-fatal if it fails)
        try? await saveToCache(version: version, content: binary)

        return binary
    }

    /// Fetches the list of available compiler versions.
    /// - Returns: Array of available version strings
    func getAvailableVersions() async throws -> [String] {
        let versionList = try await fetchVersionList()
        return Array(versionList.releases.keys).sorted()
    }

    /// Clears the cache for a specific version or all versions.
    /// - Parameter version: Optional version to clear. If nil, clears all cached binaries.
    func clearCache(version: String? = nil) async throws {
        let fileManager = FileManager.default

        if let specificVersion = version {
            let versionDir = cacheDirectory.appendingPathComponent(specificVersion, isDirectory: true)
            if fileManager.fileExists(atPath: versionDir.path) {
                try fileManager.removeItem(at: versionDir)
            }
        } else {
            if fileManager.fileExists(atPath: cacheDirectory.path) {
                try fileManager.removeItem(at: cacheDirectory)
            }
        }
    }

    // MARK: - Private Methods

    /// Fetches the version list from the remote server.
    private func fetchVersionList() async throws -> VersionList {
        // Return cached version list if available
        if let cached = cachedVersionList {
            return cached
        }

        guard let url = URL(string: "\(Self.baseURL)/list.json") else {
            throw DownloadError.invalidURL("\(Self.baseURL)/list.json")
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DownloadError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw DownloadError.httpError(
                statusCode: httpResponse.statusCode,
                message: "Failed to fetch version list"
            )
        }

        let versionList = try JSONDecoder().decode(VersionList.self, from: data)
        cachedVersionList = versionList
        return versionList
    }

    /// Resolves a version string to a filename.
    private func resolveVersion(_ version: String) async throws -> String {
        let versionList = try await fetchVersionList()

        guard let filename = versionList.releases[version] else {
            throw DownloadError.versionNotFound(
                "Version \(version) not found in release list"
            )
        }

        return filename
    }

    /// Downloads a compiler binary from the remote server.
    private func downloadBinary(filename: String) async throws -> String {
        guard let url = URL(string: "\(Self.baseURL)/\(filename)") else {
            throw DownloadError.invalidURL("\(Self.baseURL)/\(filename)")
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DownloadError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw DownloadError.httpError(
                statusCode: httpResponse.statusCode,
                message: "Failed to download binary: \(filename)"
            )
        }

        guard let content = String(data: data, encoding: .utf8) else {
            throw DownloadError.cacheError("Failed to decode binary as UTF-8")
        }

        return content
    }

    /// Loads a cached binary for a specific version.
    private func loadFromCache(version: String) async throws -> String {
        let filePath = getCachedBinaryPath(version: version)
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: filePath.path) else {
            throw DownloadError.cacheError("No cached binary for version \(version)")
        }

        return try String(contentsOf: filePath, encoding: .utf8)
    }

    /// Saves a binary to the cache.
    private func saveToCache(version: String, content: String) async throws {
        let fileManager = FileManager.default
        let versionDir = cacheDirectory.appendingPathComponent(version, isDirectory: true)

        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: versionDir.path) {
            try fileManager.createDirectory(
                at: versionDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        let filePath = getCachedBinaryPath(version: version)
        try content.write(to: filePath, atomically: true, encoding: .utf8)
    }

    /// Returns the file path for a cached binary.
    private func getCachedBinaryPath(version: String) -> URL {
        cacheDirectory
            .appendingPathComponent(version, isDirectory: true)
            .appendingPathComponent("soljson.js", isDirectory: false)
    }
}
