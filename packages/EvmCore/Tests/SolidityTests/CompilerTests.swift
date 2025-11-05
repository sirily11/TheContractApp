import Foundation
import Testing

@testable import Solidity

/// Basic compilation tests for the Solidity compiler.
@Suite("Compiler Tests")
struct CompilerTests {

    // MARK: - Basic Compilation

    @Test("Compile simple contract")
    func testCompileSimpleContract() async throws {
        let compiler = try await Solc.create(version: "0.8.21")

        let input = Input(
            sources: [
                "SimpleContract.sol": SourceIn(
                    content: """
                        pragma solidity ^0.8.0;

                        contract SimpleContract {
                            uint256 public value;

                            function setValue(uint256 _value) public {
                                value = _value;
                            }

                            function getValue() public view returns (uint256) {
                                return value;
                            }
                        }
                        """
                )
            ],
            settings: Settings(
                optimizer: Optimizer(enabled: true, runs: 200),
                outputSelection: [
                    "*": [
                        "*": [
                            "abi",
                            "evm.bytecode.object",
                            "evm.deployedBytecode.object",
                            "evm.methodIdentifiers",
                        ]
                    ]
                ]
            )
        )

        let output = try await compiler.compile(input, options: nil)

        // Verify no compilation errors (warnings are OK)
        if let errors = output.errors {
            let actualErrors = errors.filter { $0.severity == "error" }
            #expect(actualErrors.isEmpty, "Expected no errors, got: \(actualErrors)")
        }

        // Verify contract was compiled
        #expect(output.contracts != nil, "Expected contracts in output")

        guard let contracts = output.contracts?["SimpleContract.sol"] else {
            Issue.record("Contract file not found in output")
            return
        }

        guard let contract = contracts["SimpleContract"] else {
            Issue.record("SimpleContract not found in output")
            return
        }

        // Verify bytecode is present
        #expect(contract.evm?.bytecode?.object != nil, "Expected bytecode")
        #expect(contract.evm?.deployedBytecode?.object != nil, "Expected deployed bytecode")

        // Verify ABI is present
        #expect(contract.abi != nil, "Expected ABI")
        #expect(contract.abi?.count ?? 0 > 0, "Expected non-empty ABI")

        // Verify method identifiers
        let methodIds = contract.evm?.methodIdentifiers
        #expect(methodIds?["setValue(uint256)"] != nil, "Expected setValue method identifier")
        #expect(methodIds?["getValue()"] != nil, "Expected getValue method identifier")
        #expect(methodIds?["value()"] != nil, "Expected value getter method identifier")
    }

    // MARK: - Version Compatibility

    @Test("Compile with matching pragma version")
    func testVersionCompatibility() async throws {
        let compiler = try await Solc.create(version: "0.8.21")

        let input = Input(
            sources: [
                "Test.sol": SourceIn(
                    content: """
                        pragma solidity ^0.8.0;
                        contract Test {
                            function one() public pure returns (uint) { return 1; }
                        }
                        """
                )
            ],
            settings: Settings(
                outputSelection: ["*": ["*": ["abi", "evm.bytecode"]]]
            )
        )

        let output = try await compiler.compile(input, options: nil)

        // Should compile without errors
        if let errors = output.errors {
            let actualErrors = errors.filter { $0.severity == "error" }
            #expect(actualErrors.isEmpty, "Expected no errors for compatible version")
        }
    }

    @Test("Compile with incompatible pragma version")
    func testIncompatibleVersion() async throws {
        let compiler = try await Solc.create(version: "0.8.21")

        let input = Input(
            sources: [
                "Test.sol": SourceIn(
                    content: """
                        pragma solidity ^0.4.0;
                        contract Test {
                            function one() public pure returns (uint) { return 1; }
                        }
                        """
                )
            ],
            settings: Settings(
                outputSelection: ["*": ["*": ["abi", "evm.bytecode"]]]
            )
        )

        let output = try await compiler.compile(input, options: nil)

        // Should have compilation errors
        #expect(output.errors != nil, "Expected errors for incompatible version")

        if let errors = output.errors {
            let actualErrors = errors.filter { $0.severity == "error" }
            #expect(!actualErrors.isEmpty, "Expected compilation errors")
        }
    }

    // MARK: - Compiler Metadata

    @Test("Get compiler version")
    func testCompilerVersion() async throws {
        let compiler = try await Solc.create(version: "0.8.21")

        let version = try await compiler.version
        #expect(!version.isEmpty, "Expected non-empty version string")
        #expect(version.contains("0.8.21"), "Expected version to contain 0.8.21")
    }

    @Test("Get compiler license")
    func testCompilerLicense() async throws {
        let compiler = try await Solc.create(version: "0.8.21")

        let license = try await compiler.license
        // License may be empty on some versions, but if present should have content
        if !license.isEmpty {
            #expect(license.count > 5, "Expected meaningful license string")
        }
    }

    // MARK: - Error Handling

    @Test("Compile with syntax error")
    func testSyntaxError() async throws {
        let compiler = try await Solc.create(version: "0.8.21")

        let input = Input(
            sources: [
                "Invalid.sol": SourceIn(
                    content: """
                        pragma solidity ^0.8.0;
                        contract Invalid {
                            function broken() public {
                                // Missing semicolon
                                uint x = 5
                            }
                        }
                        """
                )
            ],
            settings: Settings(
                outputSelection: ["*": ["*": ["abi"]]]
            )
        )

        let output = try await compiler.compile(input, options: nil)

        // Should have parser errors
        #expect(output.errors != nil, "Expected errors for syntax error")

        if let errors = output.errors {
            let actualErrors = errors.filter { $0.severity == "error" }
            #expect(!actualErrors.isEmpty, "Expected compilation errors")

            // Check that error messages are meaningful
            let hasParserError = actualErrors.contains { error in
                error.type?.contains("Parser") ?? false
                    || error.message?.contains("Expected") ?? false
            }
            #expect(hasParserError, "Expected parser error")
        }
    }

    @Test("Compile without options")
    func testCompileWithoutOptions() async throws {
        let compiler = try await Solc.create(version: "0.8.21")

        let input = Input(
            sources: [
                "Simple.sol": SourceIn(
                    content: """
                        pragma solidity ^0.8.0;
                        contract Simple {
                            uint public x = 42;
                        }
                        """
                )
            ],
            settings: Settings(
                outputSelection: ["*": ["*": ["abi", "evm.bytecode"]]]
            )
        )

        // Pass nil options explicitly
        let output = try await compiler.compile(input, options: nil)

        if let errors = output.errors {
            let actualErrors = errors.filter { $0.severity == "error" }
            #expect(actualErrors.isEmpty, "Expected no errors")
        }

        #expect(output.contracts != nil, "Expected contracts")
    }

    // MARK: - Optimizer

    @Test("Compile with optimizer enabled")
    func testOptimizerEnabled() async throws {
        let compiler = try await Solc.create(version: "0.8.21")

        let input = Input(
            sources: [
                "Optimized.sol": SourceIn(
                    content: """
                        pragma solidity ^0.8.0;
                        contract Optimized {
                            function add(uint a, uint b) public pure returns (uint) {
                                return a + b;
                            }
                        }
                        """
                )
            ],
            settings: Settings(
                optimizer: Optimizer(enabled: true, runs: 200),
                outputSelection: ["*": ["*": ["evm.bytecode.object"]]]
            )
        )

        let output = try await compiler.compile(input, options: nil)

        if let errors = output.errors {
            let actualErrors = errors.filter { $0.severity == "error" }
            #expect(actualErrors.isEmpty, "Expected no errors")
        }

        #expect(output.contracts != nil, "Expected contracts")
    }

    @Test("Compile with optimizer disabled")
    func testOptimizerDisabled() async throws {
        let compiler = try await Solc.create(version: "0.8.21")

        let input = Input(
            sources: [
                "NotOptimized.sol": SourceIn(
                    content: """
                        pragma solidity ^0.8.0;
                        contract NotOptimized {
                            function add(uint a, uint b) public pure returns (uint) {
                                return a + b;
                            }
                        }
                        """
                )
            ],
            settings: Settings(
                optimizer: Optimizer(enabled: false, runs: 200),
                outputSelection: ["*": ["*": ["evm.bytecode.object"]]]
            )
        )

        let output = try await compiler.compile(input, options: nil)

        if let errors = output.errors {
            let actualErrors = errors.filter { $0.severity == "error" }
            #expect(actualErrors.isEmpty, "Expected no errors")
        }

        #expect(output.contracts != nil, "Expected contracts")
    }
}
