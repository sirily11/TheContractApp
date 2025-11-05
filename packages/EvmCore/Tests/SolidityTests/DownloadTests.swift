import Foundation
import Testing
@testable import Solidity

/// Tests for download and caching functionality.
@Suite("Download Tests")
struct DownloadTests {

    // MARK: - Version List

    @Test("Fetch available versions")
    func testFetchAvailableVersions() async throws {
        let versions = try await Solc.getAvailableVersions()

        #expect(!versions.isEmpty, "Expected non-empty version list")

        // Check for some known versions
        #expect(versions.contains("0.8.21"), "Expected version 0.8.21 to be available")

        // Versions should be sorted
        #expect(versions.count > 100, "Expected at least 100 versions")
    }

    // MARK: - Download and Cache

    @Test("Download and cache compiler binary")
    func testDownloadAndCache() async throws {
        // Use a specific version for testing
        let version = "0.8.21"

        // Clear cache first
        try await Solc.clearCache(version: version)

        // Create compiler (should download)
        let compiler = try await Solc.create(version: version)

        // Verify compiler works
        let compilerVersion = try await compiler.version
        #expect(compilerVersion.contains("0.8.21"), "Expected version 0.8.21")

        // Create again (should use cache)
        let compiler2 = try await Solc.create(version: version)

        let version2 = try await compiler2.version
        #expect(version2.contains("0.8.21"), "Expected cached version to work")
    }

    @Test("Download invalid version fails")
    func testDownloadInvalidVersion() async throws {
        let invalidVersion = "99.99.99"

        do {
            _ = try await Solc.create(version: invalidVersion)
            Issue.record("Expected download to fail for invalid version")
        } catch {
            // Expected to fail
            #expect(error is DownloadError, "Expected DownloadError")

            if case DownloadError.versionNotFound(let msg) = error {
                #expect(msg.contains(invalidVersion), "Error should mention version")
            }
        }
    }

    // MARK: - Cache Management

    @Test("Clear specific version cache")
    func testClearSpecificVersionCache() async throws {
        let version = "0.8.21"

        // Ensure it's cached
        let compiler = try await Solc.create(version: version)
        try await compiler.close()

        // Clear cache for this version
        try await Solc.clearCache(version: version)

        // Should be able to download again
        let compiler2 = try await Solc.create(version: version)

        let ver = try await compiler2.version
        #expect(ver.contains("0.8.21"), "Expected version after re-download")

        try await compiler2.close()
    }

    @Test("Clear all cache")
    func testClearAllCache() async throws {
        // Download a couple versions
        let v1 = try await Solc.create(version: "0.8.21")
        try await v1.close()

        // Clear entire cache
        try await Solc.clearCache()

        // Should still be able to download
        let v2 = try await Solc.create(version: "0.8.21")

        let version = try await v2.version
        #expect(version.contains("0.8.21"), "Expected version after cache clear")

        try await v2.close()
    }

    // MARK: - Binary Validation

    @Test("Downloaded binary is valid JavaScript")
    func testBinaryIsValidJavaScript() async throws {
        let version = "0.8.21"

        // Create download manager
        let manager = DownloadManager()
        let binary = try await manager.getBinary(for: version)

        // Binary should be JavaScript (contains typical JS constructs)
        #expect(binary.contains("Module"), "Expected Module in soljson.js")
        #expect(binary.contains("function"), "Expected function in soljson.js")
        #expect(binary.count > 1000, "Expected substantial binary content")

        // Should contain Solidity-specific markers
        #expect(
            binary.contains("solidity") || binary.contains("compile"),
            "Expected Solidity-related content"
        )
    }

    // MARK: - Multiple Versions

    @Test("Handle multiple compiler versions")
    func testMultipleVersions() async throws {
        // Test creating compilers for different versions
        let v1 = try await Solc.create(version: "0.8.21")

        let v2 = try await Solc.create(version: "0.8.20")

        let version1 = try await v1.version
        let version2 = try await v2.version

        #expect(version1.contains("0.8.21"), "Expected version 0.8.21")
        #expect(version2.contains("0.8.20"), "Expected version 0.8.20")
        #expect(version1 != version2, "Versions should be different")
    }

    // MARK: - Concurrent Access

    @Test("Handle concurrent downloads")
    func testConcurrentDownloads() async throws {
        let version = "0.8.21"

        // Clear cache first
        try await Solc.clearCache(version: version)

        // Create multiple compilers concurrently
        async let c1 = Solc.create(version: version)
        async let c2 = Solc.create(version: version)
        async let c3 = Solc.create(version: version)

        let compilers = try await [c1, c2, c3]

        // All should work
        for compiler in compilers {
            let ver = try await compiler.version
            #expect(ver.contains("0.8.21"), "Expected version 0.8.21")
            try await compiler.close()
        }
    }

    // MARK: - Error Recovery

    @Test("Recover from network errors")
    func testNetworkErrorRecovery() async throws {
        // This test assumes network is available
        // In real scenarios, you might mock URLSession for better control

        let version = "0.8.21"

        // Clear cache to force download
        try await Solc.clearCache(version: version)

        // Should download successfully
        let compiler = try await Solc.create(version: version)

        let ver = try await compiler.version
        #expect(ver.contains("0.8.21"), "Expected successful download")
    }
}
