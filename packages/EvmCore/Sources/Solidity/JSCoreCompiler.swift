import Foundation
@preconcurrency import JavaScriptCore

/// Errors that can occur during compilation.
public enum CompilerError: Error {
    case initializationFailed(String)
    case compilationFailed(String)
    case compilerClosed
    case invalidInput(String)
    case invalidOutput(String)
    case functionNotAvailable(String)
}

/// Protocol defining the Solidity compiler interface.
public protocol SolidityCompiler: Sendable {
    /// Returns the license information of the compiler.
    var license: String { get async throws }

    /// Returns the version information of the compiler.
    var version: String { get async throws }

    /// Compiles Solidity source code with optional import resolution.
    /// - Parameters:
    ///   - input: The compilation input
    ///   - options: Optional compile options including import callbacks
    /// - Returns: The compilation output
    func compile(_ input: Input, options: CompileOptions?) async throws -> Output

    /// Closes the compiler and releases resources.
    func close() async throws
}

/// JavaScriptCore-based implementation of the Solidity compiler.
public actor JSCoreCompiler: SolidityCompiler {
    /// JavaScript context for executing soljson.js.
    private var context: JSContext?

    /// JavaScript compile function.
    private var compileFunction: JSValue?

    /// JavaScript version function.
    private var versionFunction: JSValue?

    /// JavaScript license function.
    private var licenseFunction: JSValue?

    /// Flag indicating if the compiler has been closed.
    private var isClosed = false

    /// Import resolver for handling import callbacks.
    private let importResolver: ImportResolver

    // MARK: - Initialization

    private init(
        context: JSContext,
        compileFunction: JSValue,
        versionFunction: JSValue,
        licenseFunction: JSValue?
    ) {
        self.context = context
        self.compileFunction = compileFunction
        self.versionFunction = versionFunction
        self.licenseFunction = licenseFunction
        self.importResolver = ImportResolver()
    }

    /// Creates a new compiler instance from soljson.js content.
    static func create(soljsonJS: String) throws -> JSCoreCompiler {
        guard let context = JSContext() else {
            throw CompilerError.initializationFailed("Failed to create JSContext")
        }

        // Set up exception handler for better error reporting
        context.exceptionHandler = { context, exception in
            if let exc = exception {
                print("JavaScript Error: \(exc)")
            }
        }

        // Execute the soljson.js script
        context.evaluateScript(soljsonJS)

        if let exception = context.exception {
            throw CompilerError.initializationFailed(
                "Failed to execute soljson.js: \(exception)"
            )
        }

        // Bind compiler functions
        let (compileFunc, versionFunc, licenseFunc) = try bindFunctions(
            context: context,
            soljsonJS: soljsonJS
        )

        return JSCoreCompiler(
            context: context,
            compileFunction: compileFunc,
            versionFunction: versionFunc,
            licenseFunction: licenseFunc
        )
    }

    // MARK: - Private Static Helpers

    private static func bindFunctions(
        context: JSContext,
        soljsonJS: String
    ) throws -> (compile: JSValue, version: JSValue, license: JSValue?) {
        // Determine version function name (varies by compiler version)
        let versionFuncName = soljsonJS.contains("_solidity_version")
            ? "solidity_version"
            : "version"

        // Bind version function
        let versionScript = "Module.cwrap('\(versionFuncName)', 'string', [])"
        guard let versionVal = context.evaluateScript(versionScript),
              !versionVal.isUndefined else {
            throw CompilerError.initializationFailed("Failed to bind version function")
        }

        // Bind license function (if available)
        var licenseVal: JSValue?
        if soljsonJS.contains("_solidity_license") {
            let licenseScript = "Module.cwrap('solidity_license', 'string', [])"
            if let license = context.evaluateScript(licenseScript),
               !license.isUndefined {
                licenseVal = license
            }
        } else if soljsonJS.contains("_license") {
            let licenseScript = "Module.cwrap('license', 'string', [])"
            if let license = context.evaluateScript(licenseScript),
               !license.isUndefined {
                licenseVal = license
            }
        }

        // Set up compile function
        let setupScript = """
        var nativeCompile = Module.cwrap('solidity_compile', 'string', ['string']);

        var solc = {
            compile: function(input) {
                return nativeCompile(input);
            }
        };

        globalThis.solc = solc;
        globalThis.compile = nativeCompile;

        solc;
        """

        guard let setupResult = context.evaluateScript(setupScript),
              !setupResult.isUndefined else {
            throw CompilerError.initializationFailed("Failed to create compile wrapper")
        }

        // Verify compile function is available
        guard let compileVal = context.objectForKeyedSubscript("compile"),
              !compileVal.isUndefined else {
            throw CompilerError.initializationFailed("Compile function not available")
        }

        return (compileVal, versionVal, licenseVal)
    }

    // MARK: - SolidityCompiler Protocol Implementation

    public var license: String {
        get async throws {
            guard !isClosed else {
                throw CompilerError.compilerClosed
            }

            guard let function = licenseFunction else {
                return ""
            }

            guard let result = function.call(withArguments: []) else {
                return ""
            }

            return result.toString() ?? ""
        }
    }

    public var version: String {
        get async throws {
            guard !isClosed else {
                throw CompilerError.compilerClosed
            }

            guard let function = versionFunction else {
                throw CompilerError.functionNotAvailable("version")
            }

            guard let result = function.call(withArguments: []) else {
                throw CompilerError.compilationFailed("Version function returned nil")
            }

            return result.toString() ?? ""
        }
    }

    public func compile(_ input: Input, options: CompileOptions?) async throws -> Output {
        guard !isClosed else {
            throw CompilerError.compilerClosed
        }

        guard let context = self.context else {
            throw CompilerError.compilerClosed
        }

        guard let compileFunc = self.compileFunction else {
            throw CompilerError.functionNotAvailable("compile")
        }

        // Resolve imports if callback is provided
        var resolvedInput = input
        if let callback = options?.importCallback {
            resolvedInput = try await importResolver.resolveImports(
                input: input,
                callback: callback
            )
        }

        // Marshal input to JSON
        let encoder = JSONEncoder()
        guard let inputData = try? encoder.encode(resolvedInput),
              let inputJSON = String(data: inputData, encoding: .utf8) else {
            throw CompilerError.invalidInput("Failed to marshal input to JSON")
        }

        // Execute compilation
        guard let result = compileFunc.call(withArguments: [inputJSON]) else {
            throw CompilerError.compilationFailed("Compile function returned nil")
        }

        // Check for JavaScript exceptions
        if let exception = context.exception {
            throw CompilerError.compilationFailed(
                "JavaScript exception: \(exception)"
            )
        }

        guard let outputJSON = result.toString() else {
            throw CompilerError.invalidOutput("Failed to get compilation result as string")
        }

        // Parse output
        let decoder = JSONDecoder()
        guard let outputData = outputJSON.data(using: .utf8) else {
            throw CompilerError.invalidOutput("Failed to convert output to data")
        }

        do {
            let output = try decoder.decode(Output.self, from: outputData)
            return output
        } catch {
            throw CompilerError.invalidOutput(
                "Failed to decode compilation output: \(error)"
            )
        }
    }

    public func close() async throws {
        guard !isClosed else {
            return
        }

        // Clean up references
        compileFunction = nil
        versionFunction = nil
        licenseFunction = nil
        context = nil

        isClosed = true
    }

    // No deinit needed - actor ensures cleanup on deallocation
}
