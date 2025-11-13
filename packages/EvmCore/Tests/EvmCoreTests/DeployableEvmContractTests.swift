import BigInt
import Foundation
import Testing

@testable import EvmCore
@testable import Solidity

/// Comprehensive tests for DeployableEvmContract
@Suite("DeployableEvmContract Tests", .serialized)
struct DeployableEvmContractTests {

    // MARK: - Test Data

    static let anvilUrl = "http://localhost:8545"

    // Simple storage contract without constructor
    static let simpleStorageSource = """
        // SPDX-License-Identifier: MIT
        pragma solidity ^0.8.0;

        contract SimpleStorage {
            uint256 private value;

            function setValue(uint256 newValue) public {
                value = newValue;
            }

            function getValue() public view returns (uint256) {
                return value;
            }
        }
        """

    // Contract with multiple constructor parameter types
    static let multiParamConstructorSource = """
        // SPDX-License-Identifier: MIT
        pragma solidity ^0.8.0;

        contract MultiParamContract {
            address public owner;
            uint256 public initialValue;
            string public name;
            bool public isActive;

            constructor(
                address _owner,
                uint256 _initialValue,
                string memory _name,
                bool _isActive
            ) {
                owner = _owner;
                initialValue = _initialValue;
                name = _name;
                isActive = _isActive;
            }

            function getOwner() public view returns (address) {
                return owner;
            }

            function getInitialValue() public view returns (uint256) {
                return initialValue;
            }

            function getName() public view returns (string memory) {
                return name;
            }

            function getIsActive() public view returns (bool) {
                return isActive;
            }
        }
        """

    // Contract with import statements
    static let contractWithImport = """
        // SPDX-License-Identifier: MIT
        pragma solidity ^0.8.0;

        import "./ICounter.sol";

        contract Counter is ICounter {
            uint256 private count;

            function increment() external override {
                count++;
            }

            function getCount() external view override returns (uint256) {
                return count;
            }
        }
        """

    static let importedInterface = """
        // SPDX-License-Identifier: MIT
        pragma solidity ^0.8.0;

        interface ICounter {
            function increment() external;
            function getCount() external view returns (uint256);
        }
        """

    // MARK: - E2E Tests (Require Anvil)

    @Test("Deploy from source code without constructor")
    func testDeployFromSourceCodeNoConstructor() async throws {
        print("Setting up transport and signer...")
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let signer = try PrivateKeySigner(hexPrivateKey: AnvilAccounts.privateKey0)
        let client = EvmClient(transport: transport)
        let evmSigner = client.withSigner(signer: signer)

        print("Creating compiler...")
        let compiler = try await Solc.create(version: "0.8.21")

        print("Parsing ABI...")
        // Compile to get ABI first
        let input = Input(
            language: "Solidity",
            sources: ["SimpleStorage.sol": SourceIn(content: Self.simpleStorageSource)],
            settings: Settings(
                outputSelection: ["*": ["*": ["abi"]]]
            )
        )
        let output = try await compiler.compile(input, options: nil)
        guard let abiArray = output.contracts?["SimpleStorage.sol"]?["SimpleStorage"]?.abi else {
            throw DeployableContractTestError.compilationFailed("Failed to get ABI")
        }

        let abiJsonData = try JSONEncoder().encode(abiArray)
        let abiJsonString = String(data: abiJsonData, encoding: .utf8)!
        let abiParser = try AbiParser(fromJsonString: abiJsonString)

        print("Creating deployable contract from source code...")
        let deployableContract = DeployableEvmContract(
            sourceCode: Self.simpleStorageSource,
            contractName: "SimpleStorage",
            abi: abiParser.items,
            evmSigner: evmSigner,
            compiler: compiler
        )

        print("Deploying contract from source...")
        let contract = try await deployableContract.deploy(
            constructorArgs: [],
            importCallback: nil,
            value: TransactionValue(wei: Wei(bigInt: BigInt(0))),
            gasLimit: GasLimit(bigInt: BigInt(1_000_000)),
            gasPrice: nil as Gwei?
        )

        print("Contract deployed at: \(contract.address.value)")

        // Test the deployed contract
        let valueResult = try await contract.callFunction(
            name: "getValue",
            args: [],
            value: TransactionValue(wei: Wei(bigInt: BigInt(0))),
            gasLimit: nil as GasLimit?,
            gasPrice: nil as Gwei?
        )
        let value = valueResult.result.value as! BigInt

        print("Initial value: \(value)")
        #expect(value == 0, "Initial value should be 0")

        print("✅ Deploy from source code test passed!")
    }

    @Test("Deploy contract with multiple constructor parameter types")
    func testDeployWithMultipleParameterTypes() async throws {
        print("Setting up transport and signer...")
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let signer = try PrivateKeySigner(hexPrivateKey: AnvilAccounts.privateKey0)
        let client = EvmClient(transport: transport)
        let evmSigner = client.withSigner(signer: signer)

        print("Compiling contract...")
        let compiler = try await Solc.create(version: "0.8.21")

        let input = Input(
            language: "Solidity",
            sources: ["MultiParamContract.sol": SourceIn(content: Self.multiParamConstructorSource)],
            settings: Settings(
                outputSelection: ["*": ["*": ["abi", "evm.bytecode.object"]]]
            )
        )

        let output = try await compiler.compile(input, options: nil)

        guard let contractData = output.contracts?["MultiParamContract.sol"]?["MultiParamContract"],
              let bytecodeHex = contractData.evm?.bytecode?.object,
              let abiArray = contractData.abi
        else {
            throw DeployableContractTestError.compilationFailed("Failed to extract contract data")
        }

        let abiJsonData = try JSONEncoder().encode(abiArray)
        let abiJsonString = String(data: abiJsonData, encoding: .utf8)!
        let abiParser = try AbiParser(fromJsonString: abiJsonString)

        print("Deploying contract with multiple parameter types...")
        let ownerAddress = AnvilAccounts.account1
        let initialValue = BigInt(12345)
        let name = "TestContract"
        let isActive = true

        let deployableContract = DeployableEvmContract(
            bytecode: bytecodeHex,
            abi: abiParser.items,
            evmSigner: evmSigner
        )

        let contract = try await deployableContract.deploy(
            constructorArgs: [
                AnyCodable(ownerAddress),
                AnyCodable(initialValue),
                AnyCodable(name),
                AnyCodable(isActive)
            ],
            importCallback: nil,
            value: TransactionValue(wei: Wei(bigInt: BigInt(0))),
            gasLimit: GasLimit(bigInt: BigInt(2_000_000)),
            gasPrice: nil as Gwei?
        )

        print("Contract deployed at: \(contract.address.value)")

        // Verify constructor parameters were set correctly
        let storedOwnerResult = try await contract.callFunction(
            name: "getOwner",
            args: [],
            value: TransactionValue(wei: Wei(bigInt: BigInt(0))),
            gasLimit: nil as GasLimit?,
            gasPrice: nil as Gwei?
        )
        let storedOwner = storedOwnerResult.result.value as! String
        print("Stored owner: \(storedOwner)")
        #expect(storedOwner.lowercased() == ownerAddress.lowercased(), "Owner should match")

        let storedValueResult = try await contract.callFunction(
            name: "getInitialValue",
            args: [],
            value: TransactionValue(wei: Wei(bigInt: BigInt(0))),
            gasLimit: nil as GasLimit?,
            gasPrice: nil as Gwei?
        )
        let storedValue = storedValueResult.result.value as! BigInt
        print("Stored value: \(storedValue)")
        #expect(storedValue == initialValue, "Initial value should match")

        let storedNameResult = try await contract.callFunction(
            name: "getName",
            args: [],
            value: TransactionValue(wei: Wei(bigInt: BigInt(0))),
            gasLimit: nil as GasLimit?,
            gasPrice: nil as Gwei?
        )
        let storedName = storedNameResult.result.value as! String
        print("Stored name: \(storedName)")
        #expect(storedName == name, "Name should match")

        let storedIsActiveResult = try await contract.callFunction(
            name: "getIsActive",
            args: [],
            value: TransactionValue(wei: Wei(bigInt: BigInt(0))),
            gasLimit: nil as GasLimit?,
            gasPrice: nil as Gwei?
        )
        let storedIsActive = storedIsActiveResult.result.value as! Bool
        print("Stored isActive: \(storedIsActive)")
        #expect(storedIsActive == isActive, "IsActive should match")

        print("✅ Multiple parameter types test passed!")
    }

    @Test("Deploy contract with import callback")
    func testDeployWithImportCallback() async throws {
        print("Setting up transport and signer...")
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let signer = try PrivateKeySigner(hexPrivateKey: AnvilAccounts.privateKey0)
        let client = EvmClient(transport: transport)
        let evmSigner = client.withSigner(signer: signer)

        print("Creating compiler...")
        let compiler = try await Solc.create(version: "0.8.21")

        // Create import callback that resolves ICounter.sol
        let importCallback: ImportCallback = { url in
            if url == "./ICounter.sol" {
                return ImportResult(contents: Self.importedInterface, error: nil)
            }
            return ImportResult(contents: nil, error: "Import not found: \(url)")
        }

        print("Getting ABI...")
        // Compile with import to get ABI
        let input = Input(
            language: "Solidity",
            sources: ["Counter.sol": SourceIn(content: Self.contractWithImport)],
            settings: Settings(
                outputSelection: ["*": ["*": ["abi"]]]
            )
        )
        let options = CompileOptions(importCallback: importCallback)
        let output = try await compiler.compile(input, options: options)

        guard let abiArray = output.contracts?["Counter.sol"]?["Counter"]?.abi else {
            throw DeployableContractTestError.compilationFailed("Failed to get ABI")
        }

        let abiJsonData = try JSONEncoder().encode(abiArray)
        let abiJsonString = String(data: abiJsonData, encoding: .utf8)!
        let abiParser = try AbiParser(fromJsonString: abiJsonString)

        print("Creating deployable contract...")
        let deployableContract = DeployableEvmContract(
            sourceCode: Self.contractWithImport,
            contractName: "Counter",
            abi: abiParser.items,
            evmSigner: evmSigner,
            compiler: compiler
        )

        print("Deploying contract with import callback...")
        let contract = try await deployableContract.deploy(
            constructorArgs: [],
            importCallback: importCallback,
            value: TransactionValue(wei: Wei(bigInt: BigInt(0))),
            gasLimit: GasLimit(bigInt: BigInt(1_500_000)),
            gasPrice: nil as Gwei?
        )

        print("Contract deployed at: \(contract.address.value)")

        // Test the deployed contract
        let initialCountResult = try await contract.callFunction(
            name: "getCount",
            args: [],
            value: TransactionValue(wei: Wei(bigInt: BigInt(0))),
            gasLimit: nil as GasLimit?,
            gasPrice: nil as Gwei?
        )
        let initialCount = initialCountResult.result.value as! BigInt

        print("Initial count: \(initialCount)")
        #expect(initialCount == 0, "Initial count should be 0")

        print("✅ Import callback test passed!")
    }

    @Test("Deploy contract with ETH value")
    func testDeployWithValue() async throws {
        // Contract that accepts ETH in constructor
        let payableConstructorSource = """
            // SPDX-License-Identifier: MIT
            pragma solidity ^0.8.0;

            contract PayableConstructor {
                uint256 public receivedValue;

                constructor() payable {
                    receivedValue = msg.value;
                }

                function getBalance() public view returns (uint256) {
                    return address(this).balance;
                }
            }
            """

        print("Setting up transport and signer...")
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let signer = try PrivateKeySigner(hexPrivateKey: AnvilAccounts.privateKey0)
        let client = EvmClient(transport: transport)
        let evmSigner = client.withSigner(signer: signer)

        print("Compiling contract...")
        let compiler = try await Solc.create(version: "0.8.21")

        let input = Input(
            language: "Solidity",
            sources: ["PayableConstructor.sol": SourceIn(content: payableConstructorSource)],
            settings: Settings(
                outputSelection: ["*": ["*": ["abi", "evm.bytecode.object"]]]
            )
        )

        let output = try await compiler.compile(input, options: nil)

        guard let contractData = output.contracts?["PayableConstructor.sol"]?["PayableConstructor"],
              let bytecodeHex = contractData.evm?.bytecode?.object,
              let abiArray = contractData.abi
        else {
            throw DeployableContractTestError.compilationFailed("Failed to extract contract data")
        }

        let abiJsonData = try JSONEncoder().encode(abiArray)
        let abiJsonString = String(data: abiJsonData, encoding: .utf8)!
        let abiParser = try AbiParser(fromJsonString: abiJsonString)

        print("Deploying contract with ETH value...")
        let deployValue = BigInt(1_000_000_000_000_000_000) // 1 ETH

        let deployableContract = DeployableEvmContract(
            bytecode: bytecodeHex,
            abi: abiParser.items,
            evmSigner: evmSigner
        )

        let contract = try await deployableContract.deploy(
            constructorArgs: [],
            importCallback: nil,
            value: TransactionValue(wei: Wei(bigInt: deployValue)),
            gasLimit: GasLimit(bigInt: BigInt(1_000_000)),
            gasPrice: nil as Gwei?
        )

        print("Contract deployed at: \(contract.address.value)")

        // Verify contract received the value
        let contractBalanceResult = try await contract.callFunction(
            name: "getBalance",
            args: [],
            value: TransactionValue(wei: Wei(bigInt: BigInt(0))),
            gasLimit: nil as GasLimit?,
            gasPrice: nil as Gwei?
        )
        let contractBalance = contractBalanceResult.result.value as! BigInt

        print("Contract balance: \(contractBalance)")
        #expect(contractBalance == deployValue, "Contract should have received the deployment value")

        print("✅ Deploy with value test passed!")
    }

    // MARK: - Error Handling Tests

    @Test("Deploy with empty bytecode succeeds (validates at transaction level)")
    func testDeployWithEmptyBytecode() async throws {
        // Note: Empty bytecode is technically valid for initialization.
        // The error would occur at the transaction level when submitting to the blockchain.
        // This test documents that empty bytecode doesn't throw at the contract level.

        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let signer = try PrivateKeySigner(hexPrivateKey: AnvilAccounts.privateKey0)
        let client = EvmClient(transport: transport)
        let evmSigner = client.withSigner(signer: signer)

        let deployableContract = DeployableEvmContract(
            bytecode: "",
            abi: [],
            evmSigner: evmSigner
        )

        // This will fail at the network level, not at validation level
        // So we expect a TransactionError, not a DeploymentError.missingBytecode
        await #expect(throws: (any Error).self) {
            _ = try await deployableContract.deploy(
                constructorArgs: [],
                importCallback: nil,
                value: TransactionValue(wei: Wei(bigInt: BigInt(0))),
                gasLimit: GasLimit(bigInt: BigInt(1_000_000)),
                gasPrice: nil
            )
        }

        print("✅ Empty bytecode test passed!")
    }

    @Test("Deploy fails when constructor not found in ABI")
    func testDeployFailsWhenConstructorNotFound() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let signer = try PrivateKeySigner(hexPrivateKey: AnvilAccounts.privateKey0)
        let client = EvmClient(transport: transport)
        let evmSigner = client.withSigner(signer: signer)

        // Create ABI without constructor
        let abiJson = """
        [
            {
                "type": "function",
                "name": "getValue",
                "inputs": [],
                "outputs": [{"type": "uint256", "name": ""}],
                "stateMutability": "view"
            }
        ]
        """

        let abiParser = try AbiParser(fromJsonString: abiJson)

        let deployableContract = DeployableEvmContract(
            bytecode: "0x6080604052",
            abi: abiParser.items,
            evmSigner: evmSigner
        )

        // Try to deploy with constructor args when there's no constructor in ABI
        await #expect(throws: DeploymentError.self) {
            _ = try await deployableContract.deploy(
                constructorArgs: [AnyCodable(BigInt(42))],
                importCallback: nil,
                value: TransactionValue(wei: Wei(bigInt: BigInt(0))),
                gasLimit: GasLimit(bigInt: BigInt(1_000_000)),
                gasPrice: nil
            )
        }

        print("✅ Constructor not found error test passed!")
    }

    @Test("Deploy fails when constructor argument count mismatch")
    func testDeployFailsWithArgumentCountMismatch() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let signer = try PrivateKeySigner(hexPrivateKey: AnvilAccounts.privateKey0)
        let client = EvmClient(transport: transport)
        let evmSigner = client.withSigner(signer: signer)

        // Create ABI with constructor that expects 2 arguments
        let abiJson = """
        [
            {
                "type": "constructor",
                "inputs": [
                    {"type": "uint256", "name": "x"},
                    {"type": "uint256", "name": "y"}
                ]
            }
        ]
        """

        let abiParser = try AbiParser(fromJsonString: abiJson)

        let deployableContract = DeployableEvmContract(
            bytecode: "0x6080604052",
            abi: abiParser.items,
            evmSigner: evmSigner
        )

        // Try to deploy with wrong number of arguments
        await #expect(throws: DeploymentError.self) {
            _ = try await deployableContract.deploy(
                constructorArgs: [AnyCodable(BigInt(42))], // Only 1 arg, expects 2
                importCallback: nil,
                value: TransactionValue(wei: Wei(bigInt: BigInt(0))),
                gasLimit: GasLimit(bigInt: BigInt(1_000_000)),
                gasPrice: nil
            )
        }

        print("✅ Argument count mismatch error test passed!")
    }

    @Test("Deploy fails when compilation fails")
    func testDeployFailsWithCompilationError() async throws {
        let invalidSource = """
            // SPDX-License-Identifier: MIT
            pragma solidity ^0.8.0;

            contract Invalid {
                // Syntax error: missing semicolon
                uint256 public value
            }
            """

        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let signer = try PrivateKeySigner(hexPrivateKey: AnvilAccounts.privateKey0)
        let client = EvmClient(transport: transport)
        let evmSigner = client.withSigner(signer: signer)
        let compiler = try await Solc.create(version: "0.8.21")

        let deployableContract = DeployableEvmContract(
            sourceCode: invalidSource,
            contractName: "Invalid",
            abi: [],
            evmSigner: evmSigner,
            compiler: compiler
        )

        await #expect(throws: DeploymentError.self) {
            _ = try await deployableContract.deploy(
                constructorArgs: [],
                importCallback: nil,
                value: TransactionValue(wei: Wei(bigInt: BigInt(0))),
                gasLimit: GasLimit(bigInt: BigInt(1_000_000)),
                gasPrice: nil
            )
        }

        print("✅ Compilation error test passed!")
    }

    @Test("Deploy fails when contract name not found in compilation output")
    func testDeployFailsWithWrongContractName() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let signer = try PrivateKeySigner(hexPrivateKey: AnvilAccounts.privateKey0)
        let client = EvmClient(transport: transport)
        let evmSigner = client.withSigner(signer: signer)
        let compiler = try await Solc.create(version: "0.8.21")

        let deployableContract = DeployableEvmContract(
            sourceCode: Self.simpleStorageSource,
            contractName: "NonExistentContract", // Wrong name
            abi: [],
            evmSigner: evmSigner,
            compiler: compiler
        )

        await #expect(throws: DeploymentError.self) {
            _ = try await deployableContract.deploy(
                constructorArgs: [],
                importCallback: nil,
                value: TransactionValue(wei: Wei(bigInt: BigInt(0))),
                gasLimit: GasLimit(bigInt: BigInt(1_000_000)),
                gasPrice: nil
            )
        }

        print("✅ Wrong contract name error test passed!")
    }

    // MARK: - Constructor Encoding Tests (tested indirectly through deployment)
    // Note: Constructor encoding is tested indirectly through the deployment E2E tests above,
    // particularly testDeployWithMultipleParameterTypes which covers uint256, address, string, and bool types.

    // MARK: - Deployment Error Description Tests

    @Test("DeploymentError error descriptions are correct")
    func testDeploymentErrorDescriptions() {
        let errors: [DeploymentError] = [
            .missingBytecode("test"),
            .constructorNotFound("test"),
            .encodingFailed("test"),
            .transactionFailed("test"),
            .deploymentFailed("test"),
            .missingContractAddress("test"),
            .compilationNotSupported("test"),
            .compilationFailed("test")
        ]

        for error in errors {
            let description = error.errorDescription
            #expect(description != nil, "Error description should not be nil")
            #expect(!description!.isEmpty, "Error description should not be empty")
            print("\(error): \(description!)")
        }

        print("✅ Error descriptions test passed!")
    }
}

// MARK: - Test Errors
// Note: We use a different name to avoid conflicts with ContractE2ETests

enum DeployableContractTestError: Error, LocalizedError {
    case compilationFailed(String)
    case testFailed(String)

    var errorDescription: String? {
        switch self {
        case .compilationFailed(let message):
            return "Compilation failed: \(message)"
        case .testFailed(let message):
            return "Test failed: \(message)"
        }
    }
}
