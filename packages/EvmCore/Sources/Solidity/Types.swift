import Foundation

// MARK: - Compilation Input Types

/// Represents a Solidity compilation input.
public struct Input: Codable, Sendable {
    /// Programming language (typically "Solidity").
    public var language: String

    /// Map of source file names to their content.
    public var sources: [String: SourceIn]

    /// Compiler settings and configuration.
    public var settings: Settings

    public init(language: String = "Solidity", sources: [String: SourceIn], settings: Settings) {
        self.language = language
        self.sources = sources
        self.settings = settings
    }
}

/// Represents a single source file input.
public struct SourceIn: Codable, Sendable {
    /// Optional Keccak256 hash of the content.
    public var keccak256: String?

    /// The actual Solidity source code.
    public var content: String

    public init(content: String, keccak256: String? = nil) {
        self.content = content
        self.keccak256 = keccak256
    }
}

/// Compiler settings and configuration.
public struct Settings: Codable, Sendable {
    /// Import path remappings.
    public var remappings: [String]?

    /// Optimizer configuration.
    public var optimizer: Optimizer?

    /// Target EVM version (e.g., "byzantium", "istanbul").
    public var evmVersion: String?

    /// Specifies which outputs to generate.
    /// Format: [fileName: [contractName: [outputType]]]
    public var outputSelection: [String: [String: [String]]]

    public init(
        remappings: [String]? = nil,
        optimizer: Optimizer? = nil,
        evmVersion: String? = nil,
        outputSelection: [String: [String: [String]]]
    ) {
        self.remappings = remappings
        self.optimizer = optimizer
        self.evmVersion = evmVersion
        self.outputSelection = outputSelection
    }
}

/// Optimizer configuration.
public struct Optimizer: Codable, Sendable {
    /// Whether optimization is enabled.
    public var enabled: Bool

    /// Number of optimization runs (typically 200).
    public var runs: Int

    public init(enabled: Bool = false, runs: Int = 200) {
        self.enabled = enabled
        self.runs = runs
    }
}

// MARK: - Compilation Output Types

/// Represents the output of a Solidity compilation.
public struct Output: Codable, Sendable {
    /// Compilation errors and warnings.
    public var errors: [CompilationError]?

    /// Source-level outputs (AST, etc.).
    public var sources: [String: SourceOut]?

    /// Compiled contracts organized by file and contract name.
    /// Format: [fileName: [contractName: Contract]]
    public var contracts: [String: [String: Contract]]?

    public init(
        errors: [CompilationError]? = nil,
        sources: [String: SourceOut]? = nil,
        contracts: [String: [String: Contract]]? = nil
    ) {
        self.errors = errors
        self.sources = sources
        self.contracts = contracts
    }
}

/// Represents a compilation error or warning.
public struct CompilationError: Codable, Sendable {
    /// Location in source code where the error occurred.
    public var sourceLocation: SourceLocation?

    /// Error type (e.g., "TypeError", "ParserError").
    public var type: String?

    /// Compiler component that generated the error.
    public var component: String?

    /// Severity level ("error", "warning", "info").
    public var severity: String?

    /// Error message.
    public var message: String?

    /// Human-readable formatted message.
    public var formattedMessage: String?
}

/// Represents a location in source code.
public struct SourceLocation: Codable, Sendable {
    /// Source file name.
    public var file: String?

    /// Start byte position.
    public var start: Int?

    /// End byte position.
    public var end: Int?
}

/// Source-level compilation output.
public struct SourceOut: Codable, Sendable {
    /// Source file ID.
    public var id: Int?

    /// Abstract Syntax Tree (raw JSON).
    public var ast: AnyCodable?

    /// Legacy AST format (raw JSON).
    public var legacyAST: AnyCodable?
}

/// Represents a compiled contract.
public struct Contract: Codable, Sendable {
    /// Contract ABI (array of ABI items as raw JSON).
    public var abi: [AnyCodable]?

    /// Contract metadata.
    public var metadata: String?

    /// User documentation (raw JSON).
    public var userdoc: AnyCodable?

    /// Developer documentation (raw JSON).
    public var devdoc: AnyCodable?

    /// Intermediate representation.
    public var ir: String?

    /// EVM-specific outputs.
    public var evm: EVM?

    /// WebAssembly outputs.
    public var ewasm: EWASM?
}

/// EVM bytecode and metadata.
public struct EVM: Codable, Sendable {
    /// Assembly code.
    public var assembly: String?

    /// Legacy assembly format (raw JSON).
    public var legacyAssembly: AnyCodable?

    /// Deployment bytecode.
    public var bytecode: Bytecode?

    /// Runtime bytecode.
    public var deployedBytecode: Bytecode?

    /// Function selector mappings.
    public var methodIdentifiers: [String: String]?

    /// Gas cost estimates (raw JSON).
    public var gasEstimates: [String: [String: String]]?
}

/// Bytecode representation.
public struct Bytecode: Codable, Sendable {
    /// Hex-encoded bytecode.
    public var object: String?

    /// Human-readable opcodes.
    public var opcodes: String?

    /// Source mapping for debugging.
    public var sourceMap: String?

    /// Library link references.
    /// Format: [fileName: [libraryName: [LinkReference]]]
    public var linkReferences: [String: [String: [LinkReference]]]?
}

/// Represents a library link reference in bytecode.
public struct LinkReference: Codable, Sendable {
    /// Start position in bytecode.
    public var start: Int

    /// Length of the reference.
    public var length: Int
}

/// WebAssembly outputs.
public struct EWASM: Codable, Sendable {
    /// WebAssembly text format.
    public var wast: String?

    /// WebAssembly binary format.
    public var wasm: String?
}

// MARK: - Import Resolution Types

/// Result of an import resolution callback.
public struct ImportResult: Sendable {
    /// File contents if import was successful.
    public var contents: String?

    /// Error message if import failed.
    public var error: String?

    public init(contents: String? = nil, error: String? = nil) {
        self.contents = contents
        self.error = error
    }
}

/// Callback function type for resolving imports.
public typealias ImportCallback = @Sendable (String) -> ImportResult

/// Additional options for compilation.
public struct CompileOptions: Sendable {
    /// Callback to resolve import statements.
    public var importCallback: ImportCallback?

    public init(importCallback: ImportCallback? = nil) {
        self.importCallback = importCallback
    }
}

// MARK: - Download Types

/// Represents the remote version list from binaries.soliditylang.org.
struct VersionList: Codable {
    /// Available compiler builds.
    var builds: [Build]

    /// Map of version to filename.
    var releases: [String: String]
}

/// Represents a single compiler build.
struct Build: Codable {
    /// Download path/filename.
    var path: String

    /// Version number.
    var version: String

    /// Build identifier.
    var build: String

    /// Full version string.
    var longVersion: String

    /// Keccak256 hash.
    var keccak256: String

    /// SHA256 hash.
    var sha256: String
}

// MARK: - AnyCodable Helper

/// Type-erased Codable wrapper for dynamic JSON values.
public struct AnyCodable: Codable, @unchecked Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unable to decode value"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Unable to encode value"
                )
            )
        }
    }
}
