//
//  SolidityVersionManager.swift
//  SmartContractApp
//
//  Created by Kiro on 11/12/25.
//

import Foundation
import Observation
import Solidity

// MARK: - Solidity Version Manager

/// Manages Solidity compiler versions, including fetching and caching
@Observable
final class SolidityVersionManager {
    // MARK: - Singleton

    static let shared = SolidityVersionManager()

    // MARK: - State Properties

    var availableVersions: [String] = []
    var isLoadingVersions: Bool = false
    var loadingError: String?

    // MARK: - Cache Properties

    private let cacheKey = "cached_solidity_versions"
    private let cacheTimestampKey = "cached_solidity_versions_timestamp"
    private let cacheExpirationInterval: TimeInterval = 24 * 60 * 60 // 24 hours

    // MARK: - Initialization

    private init() {
        // Load cached versions on initialization
        loadCachedVersions()
    }

    // MARK: - Public Methods

    /// Fetches available Solidity compiler versions
    /// Uses cache if available and not expired, otherwise fetches from network
    /// - Parameter forceRefresh: If true, ignores cache and fetches from network
    func fetchVersions(forceRefresh: Bool = false) async {
        // Check if we should use cache
        if !forceRefresh && !isCacheExpired() && !availableVersions.isEmpty {
            return
        }

        isLoadingVersions = true
        loadingError = nil

        do {
            let versions = try await Solc.getAvailableVersions()

            // Sort versions in descending order (newest first)
            let sortedVersions = versions.sorted { version1, version2 in
                compareVersions(version1, version2) > 0
            }

            await MainActor.run {
                self.availableVersions = sortedVersions
                self.isLoadingVersions = false
                self.cacheVersions(sortedVersions)
            }
        } catch {
            await MainActor.run {
                self.loadingError = error.localizedDescription
                self.isLoadingVersions = false

                // Fall back to cached versions if network fails
                if self.availableVersions.isEmpty {
                    self.loadCachedVersions()
                }
            }
        }
    }

    /// Returns the default/recommended Solidity version
    var defaultVersion: String {
        // Return the first version (newest) or fallback to known stable version
        availableVersions.first ?? "0.8.21"
    }

    /// Checks if a version is available
    func isVersionAvailable(_ version: String) -> Bool {
        availableVersions.contains(version)
    }

    // MARK: - Private Methods

    /// Loads cached versions from UserDefaults
    private func loadCachedVersions() {
        guard let cachedData = UserDefaults.standard.data(forKey: cacheKey),
              let cachedVersions = try? JSONDecoder().decode([String].self, from: cachedData) else {
            // If no cache, use a default list of known versions
            availableVersions = defaultVersionList()
            return
        }

        availableVersions = cachedVersions
    }

    /// Caches versions to UserDefaults
    private func cacheVersions(_ versions: [String]) {
        guard let encoded = try? JSONEncoder().encode(versions) else {
            return
        }

        UserDefaults.standard.set(encoded, forKey: cacheKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: cacheTimestampKey)
    }

    /// Checks if the cache is expired
    private func isCacheExpired() -> Bool {
        let lastCacheTime = UserDefaults.standard.double(forKey: cacheTimestampKey)

        guard lastCacheTime > 0 else {
            return true // No cache timestamp, consider expired
        }

        let currentTime = Date().timeIntervalSince1970
        return (currentTime - lastCacheTime) > cacheExpirationInterval
    }

    /// Returns a default list of known Solidity versions
    /// Used as fallback when cache is empty and network is unavailable
    private func defaultVersionList() -> [String] {
        [
            "0.8.28", "0.8.27", "0.8.26", "0.8.25", "0.8.24", "0.8.23", "0.8.22", "0.8.21",
            "0.8.20", "0.8.19", "0.8.18", "0.8.17", "0.8.16", "0.8.15", "0.8.14", "0.8.13",
            "0.8.12", "0.8.11", "0.8.10", "0.8.9", "0.8.8", "0.8.7", "0.8.6", "0.8.5",
            "0.8.4", "0.8.3", "0.8.2", "0.8.1", "0.8.0",
            "0.7.6", "0.7.5", "0.7.4", "0.7.3", "0.7.2", "0.7.1", "0.7.0",
            "0.6.12", "0.6.11", "0.6.10", "0.6.9", "0.6.8", "0.6.7", "0.6.6"
        ]
    }

    /// Compares two semantic version strings
    /// - Returns: 1 if version1 > version2, -1 if version1 < version2, 0 if equal
    private func compareVersions(_ version1: String, _ version2: String) -> Int {
        let components1 = version1.split(separator: ".").compactMap { Int($0) }
        let components2 = version2.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(components1.count, components2.count) {
            let v1 = i < components1.count ? components1[i] : 0
            let v2 = i < components2.count ? components2[i] : 0

            if v1 > v2 {
                return 1
            } else if v1 < v2 {
                return -1
            }
        }

        return 0
    }
}
