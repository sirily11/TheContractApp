import Foundation
import Testing
@testable import Solidity

/// Tests for import resolution functionality.
@Suite("Import Resolution Tests")
struct ImportResolutionTests {

    // MARK: - Single Import

    @Test("Resolve single import")
    func testSingleImport() async throws {
        let compiler = try await Solc.create(version: "0.8.21")

        let input = Input(
            sources: [
                "Calculator.sol": SourceIn(
                    content: """
                    pragma solidity ^0.8.0;

                    import "./lib/Math.sol";

                    contract Calculator {
                        function add(uint256 a, uint256 b) public pure returns (uint256) {
                            return Math.add(a, b);
                        }
                    }
                    """
                )
            ],
            settings: Settings(
                outputSelection: ["*": ["*": ["abi", "evm.bytecode"]]]
            )
        )

        let options = CompileOptions(
            importCallback: { url in
                if url == "./lib/Math.sol" {
                    return ImportResult(
                        contents: """
                        pragma solidity ^0.8.0;

                        library Math {
                            function add(uint256 a, uint256 b) internal pure returns (uint256) {
                                return a + b;
                            }
                        }
                        """
                    )
                }
                return ImportResult(error: "File not found: \(url)")
            }
        )

        let output = try await compiler.compile(input, options: options)

        // Should compile successfully
        if let errors = output.errors {
            let actualErrors = errors.filter { $0.severity == "error" }
            #expect(actualErrors.isEmpty, "Expected no errors: \(actualErrors)")
        }

        #expect(output.contracts != nil, "Expected contracts")
    }

    // MARK: - Failed Import

    @Test("Handle failed import resolution")
    func testFailedImport() async throws {
        let compiler = try await Solc.create(version: "0.8.21")

        let input = Input(
            sources: [
                "Test.sol": SourceIn(
                    content: """
                    pragma solidity ^0.8.0;

                    import "./Missing.sol";

                    contract Test {}
                    """
                )
            ],
            settings: Settings(
                outputSelection: ["*": ["*": ["abi"]]]
            )
        )

        let options = CompileOptions(
            importCallback: { url in
                ImportResult(error: "File not found: \(url)")
            }
        )

        // Should throw during import resolution
        do {
            _ = try await compiler.compile(input, options: options)
            Issue.record("Expected import resolution to fail")
        } catch {
            // Expected to fail
            #expect(error is ImportResolverError, "Expected ImportResolverError")
        }
    }

    // MARK: - Multiple Imports

    @Test("Resolve multiple imports")
    func testMultipleImports() async throws {
        let compiler = try await Solc.create(version: "0.8.21")

        let input = Input(
            sources: [
                "Main.sol": SourceIn(
                    content: """
                    pragma solidity ^0.8.0;

                    import "./lib/Math.sol";
                    import "./lib/String.sol";

                    contract Main {
                        function add(uint a, uint b) public pure returns (uint) {
                            return Math.add(a, b);
                        }

                        function concat(string memory a, string memory b) public pure returns (string memory) {
                            return String.concat(a, b);
                        }
                    }
                    """
                )
            ],
            settings: Settings(
                outputSelection: ["*": ["*": ["abi", "evm.bytecode"]]]
            )
        )

        let options = CompileOptions(
            importCallback: { url in
                switch url {
                case "./lib/Math.sol":
                    return ImportResult(
                        contents: """
                        pragma solidity ^0.8.0;
                        library Math {
                            function add(uint a, uint b) internal pure returns (uint) {
                                return a + b;
                            }
                        }
                        """
                    )
                case "./lib/String.sol":
                    return ImportResult(
                        contents: """
                        pragma solidity ^0.8.0;
                        library String {
                            function concat(string memory a, string memory b) internal pure returns (string memory) {
                                return string(abi.encodePacked(a, b));
                            }
                        }
                        """
                    )
                default:
                    return ImportResult(error: "File not found: \(url)")
                }
            }
        )

        let output = try await compiler.compile(input, options: options)

        if let errors = output.errors {
            let actualErrors = errors.filter { $0.severity == "error" }
            #expect(actualErrors.isEmpty, "Expected no errors: \(actualErrors)")
        }

        #expect(output.contracts != nil, "Expected contracts")
    }

    // MARK: - Nested Imports

    @Test("Resolve nested imports")
    func testNestedImports() async throws {
        let compiler = try await Solc.create(version: "0.8.21")

        let input = Input(
            sources: [
                "Token.sol": SourceIn(
                    content: """
                    pragma solidity ^0.8.0;

                    import "./IERC20.sol";

                    contract Token is IERC20 {
                        mapping(address => uint256) private _balances;

                        function balanceOf(address account) external view returns (uint256) {
                            return _balances[account];
                        }

                        function transfer(address to, uint256 amount) external returns (bool) {
                            _balances[msg.sender] -= amount;
                            _balances[to] += amount;
                            return true;
                        }
                    }
                    """
                )
            ],
            settings: Settings(
                outputSelection: ["*": ["*": ["abi", "evm.bytecode"]]]
            )
        )

        let options = CompileOptions(
            importCallback: { url in
                switch url {
                case "./IERC20.sol":
                    return ImportResult(
                        contents: """
                        pragma solidity ^0.8.0;

                        import "./Context.sol";

                        interface IERC20 is Context {
                            function balanceOf(address account) external view returns (uint256);
                            function transfer(address to, uint256 amount) external returns (bool);
                        }
                        """
                    )
                case "./Context.sol":
                    return ImportResult(
                        contents: """
                        pragma solidity ^0.8.0;

                        interface Context {
                            // Context interface
                        }
                        """
                    )
                default:
                    return ImportResult(error: "File not found: \(url)")
                }
            }
        )

        let output = try await compiler.compile(input, options: options)

        if let errors = output.errors {
            let actualErrors = errors.filter { $0.severity == "error" }
            #expect(actualErrors.isEmpty, "Expected no errors: \(actualErrors)")
        }

        #expect(output.contracts != nil, "Expected contracts")
    }

    // MARK: - Package Imports

    @Test("Resolve package-style imports")
    func testPackageImports() async throws {
        let compiler = try await Solc.create(version: "0.8.21")

        let input = Input(
            sources: [
                "MyToken.sol": SourceIn(
                    content: """
                    pragma solidity ^0.8.0;

                    import "@openzeppelin/contracts/utils/Context.sol";

                    contract MyToken is Context {
                        function sender() public view returns (address) {
                            return _msgSender();
                        }
                    }
                    """
                )
            ],
            settings: Settings(
                outputSelection: ["*": ["*": ["abi", "evm.bytecode"]]]
            )
        )

        let options = CompileOptions(
            importCallback: { url in
                if url.hasPrefix("@openzeppelin/") {
                    switch url {
                    case "@openzeppelin/contracts/utils/Context.sol":
                        return ImportResult(
                            contents: """
                            pragma solidity ^0.8.0;

                            abstract contract Context {
                                function _msgSender() internal view virtual returns (address) {
                                    return msg.sender;
                                }

                                function _msgData() internal view virtual returns (bytes calldata) {
                                    return msg.data;
                                }
                            }
                            """
                        )
                    default:
                        return ImportResult(error: "OpenZeppelin file not found: \(url)")
                    }
                }
                return ImportResult(error: "File not found: \(url)")
            }
        )

        let output = try await compiler.compile(input, options: options)

        if let errors = output.errors {
            let actualErrors = errors.filter { $0.severity == "error" }
            #expect(actualErrors.isEmpty, "Expected no errors: \(actualErrors)")
        }

        #expect(output.contracts != nil, "Expected contracts")
    }

    // MARK: - Import Variants

    @Test("Parse different import syntax variants")
    func testImportSyntaxVariants() async throws {
        let compiler = try await Solc.create(version: "0.8.21")

        let input = Input(
            sources: [
                "Test.sol": SourceIn(
                    content: """
                    pragma solidity ^0.8.0;

                    import "./A.sol";
                    import {SymbolB} from "./B.sol";
                    import * as C from "./C.sol";

                    contract Test is A {
                        function test() public pure returns (uint) {
                            return 1;
                        }
                    }
                    """
                )
            ],
            settings: Settings(
                outputSelection: ["*": ["*": ["abi"]]]
            )
        )

        let options = CompileOptions(
            importCallback: { url in
                switch url {
                case "./A.sol":
                    return ImportResult(contents: """
                    pragma solidity ^0.8.0;
                    contract A {}
                    """)
                case "./B.sol":
                    return ImportResult(contents: """
                    pragma solidity ^0.8.0;
                    contract SymbolB {}
                    """)
                case "./C.sol":
                    return ImportResult(contents: """
                    pragma solidity ^0.8.0;
                    contract C {}
                    """)
                default:
                    return ImportResult(error: "File not found: \(url)")
                }
            }
        )

        let output = try await compiler.compile(input, options: options)

        if let errors = output.errors {
            let actualErrors = errors.filter { $0.severity == "error" }
            #expect(actualErrors.isEmpty, "Expected no errors: \(actualErrors)")
        }
    }

    // MARK: - Pre-included Imports

    @Test("Handle pre-included imports")
    func testPreIncludedImports() async throws {
        let compiler = try await Solc.create(version: "0.8.21")

        // Pre-include the dependency in the sources
        let input = Input(
            sources: [
                "Main.sol": SourceIn(
                    content: """
                    pragma solidity ^0.8.0;

                    import "./Lib.sol";

                    contract Main {
                        function test() public pure returns (uint) {
                            return Lib.getValue();
                        }
                    }
                    """
                ),
                "Lib.sol": SourceIn(
                    content: """
                    pragma solidity ^0.8.0;

                    library Lib {
                        function getValue() internal pure returns (uint) {
                            return 42;
                        }
                    }
                    """
                )
            ],
            settings: Settings(
                outputSelection: ["*": ["*": ["abi", "evm.bytecode"]]]
            )
        )

        // No import callback needed since all files are pre-included
        let output = try await compiler.compile(input, options: nil)

        if let errors = output.errors {
            let actualErrors = errors.filter { $0.severity == "error" }
            #expect(actualErrors.isEmpty, "Expected no errors: \(actualErrors)")
        }

        #expect(output.contracts != nil, "Expected contracts")
        #expect(output.contracts?["Main.sol"] != nil, "Expected Main.sol in output")
        #expect(output.contracts?["Lib.sol"] != nil, "Expected Lib.sol in output")
    }
}
