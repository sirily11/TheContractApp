import Foundation

/// Errors that can occur during import resolution.
enum ImportResolverError: Error {
    case maxDepthExceeded(String)
    case importFailed(path: String, error: String)
    case invalidRegex
}

/// Handles recursive resolution of Solidity import statements.
struct ImportResolver {
    /// Maximum recursion depth to prevent infinite loops.
    private let maxDepth: Int

    /// Regular expression for extracting import statements.
    private let importRegex: NSRegularExpression

    init(maxDepth: Int = 50) {
        self.maxDepth = maxDepth

        // Regex pattern matches all Solidity import variants:
        // - import "path";
        // - import {symbol} from "path";
        // - import * as name from "path";
        let pattern = #"import\s+(?:(?:\{[^}]*\}|\*\s+as\s+\w+|\w+)\s+from\s+)?["']([^"']+)["']"#

        do {
            self.importRegex = try NSRegularExpression(pattern: pattern, options: [])
        } catch {
            // This should never happen with a valid pattern
            fatalError("Failed to compile import regex: \(error)")
        }
    }

    // MARK: - Public API

    /// Resolves all imports in the input recursively.
    /// - Parameters:
    ///   - input: The compilation input
    ///   - callback: Callback function to fetch import contents
    /// - Returns: Updated input with all dependencies included
    func resolveImports(input: Input, callback: @escaping ImportCallback) async throws -> Input {
        var resolvedSources = input.sources
        var resolvedPaths = Set<String>()
        var contextStack: [String] = []

        // Resolve imports for each source file
        for (fileName, _) in input.sources {
            try await resolveFileImports(
                fileName: fileName,
                sources: &resolvedSources,
                resolvedPaths: &resolvedPaths,
                contextStack: &contextStack,
                callback: callback,
                currentDepth: 0
            )
        }

        // Return updated input
        return Input(
            language: input.language,
            sources: resolvedSources,
            settings: input.settings
        )
    }

    // MARK: - Private Methods

    /// Recursively resolves imports for a specific file.
    private func resolveFileImports(
        fileName: String,
        sources: inout [String: SourceIn],
        resolvedPaths: inout Set<String>,
        contextStack: inout [String],
        callback: @escaping ImportCallback,
        currentDepth: Int
    ) async throws {
        // Check if already resolved (cycle detection)
        if resolvedPaths.contains(fileName) {
            return
        }

        // Check max depth
        if currentDepth >= maxDepth {
            throw ImportResolverError.maxDepthExceeded(
                "Maximum import depth (\(maxDepth)) exceeded for file: \(fileName)"
            )
        }

        // Mark as resolved before processing to prevent cycles
        resolvedPaths.insert(fileName)

        // Push to context stack
        contextStack.append(fileName)
        defer { contextStack.removeLast() }

        // Get source content
        guard let source = sources[fileName] else {
            return
        }

        // Extract import statements
        let importPaths = extractImports(from: source.content)

        // Resolve each import
        for importPath in importPaths {
            // Resolve relative paths
            let absolutePath = resolveAbsolutePath(
                importPath: importPath,
                contextStack: contextStack
            )

            // Skip if already in sources (but still recurse to resolve its imports)
            let needsFetch = sources[absolutePath] == nil

            if needsFetch {
                // Fetch import using callback
                let result = callback(importPath)

                if let error = result.error {
                    throw ImportResolverError.importFailed(
                        path: importPath,
                        error: error
                    )
                }

                guard let contents = result.contents else {
                    throw ImportResolverError.importFailed(
                        path: importPath,
                        error: "Import callback returned neither contents nor error"
                    )
                }

                // Add to sources
                sources[absolutePath] = SourceIn(content: contents)
            }

            // Recursively resolve imports for this file
            try await resolveFileImports(
                fileName: absolutePath,
                sources: &sources,
                resolvedPaths: &resolvedPaths,
                contextStack: &contextStack,
                callback: callback,
                currentDepth: currentDepth + 1
            )
        }
    }

    /// Extracts import paths from Solidity source code.
    private func extractImports(from source: String) -> [String] {
        let nsSource = source as NSString
        let range = NSRange(location: 0, length: nsSource.length)

        let matches = importRegex.matches(in: source, options: [], range: range)

        return matches.compactMap { match in
            // The first capture group contains the import path
            guard match.numberOfRanges > 1 else { return nil }
            let pathRange = match.range(at: 1)
            guard pathRange.location != NSNotFound else { return nil }
            return nsSource.substring(with: pathRange)
        }
    }

    /// Resolves a relative import path to an absolute path.
    private func resolveAbsolutePath(
        importPath: String,
        contextStack: [String]
    ) -> String {
        // If path doesn't start with . or .., it's already absolute/package import
        if !importPath.hasPrefix(".") {
            return importPath
        }

        // Get current file's directory
        guard let currentFile = contextStack.last else {
            return importPath
        }

        let currentDir = (currentFile as NSString).deletingLastPathComponent

        // Join paths
        var fullPath = (currentDir as NSString).appendingPathComponent(importPath)

        // Normalize path (resolve .. and .)
        fullPath = (fullPath as NSString).standardizingPath

        return fullPath
    }
}
