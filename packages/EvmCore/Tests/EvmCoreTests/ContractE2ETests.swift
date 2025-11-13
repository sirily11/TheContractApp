import BigInt
import Foundation
import Testing

@testable import EvmCore
@testable import Solidity

/// E2E tests for contract compilation, deployment, and interaction
@Suite("Contract E2E Tests", .serialized)
struct ContractE2ETests {

    // Solidity test contract with multiple function types
    static let testContractSource = """
        // SPDX-License-Identifier: MIT
        pragma solidity ^0.8.0;

        contract TestContract {
            uint256 private value;
            mapping(address => uint256) private balances;
            uint256 private totalDeposited;

            // Constructor to initialize the value
            constructor(uint256 initialValue) {
                value = initialValue;
            }

            // Read-only function: get current value
            function getValue() public view returns (uint256) {
                return value;
            }

            // State-changing function: set new value
            function setValue(uint256 newValue) public {
                value = newValue;
            }

            // State-changing function: increment value
            function increment() public {
                value += 1;
            }

            // Payable function: accept ETH deposit
            function deposit() public payable {
                balances[msg.sender] += msg.value;
                totalDeposited += msg.value;
            }

            // Payable function with parameter: deposit for specific address
            function depositFor(address recipient) public payable {
                balances[recipient] += msg.value;
                totalDeposited += msg.value;
            }

            // Read-only function: get balance of address
            function getBalance(address account) public view returns (uint256) {
                return balances[account];
            }

            // Read-only function: get total deposited
            function getTotalDeposited() public view returns (uint256) {
                return totalDeposited;
            }

            // Read-only function: get contract balance
            function getContractBalance() public view returns (uint256) {
                return address(this).balance;
            }
        }
        """

    static let anvilUrl = "http://localhost:8545"

    @Test("Compile, deploy, and test contract with all function types")
    func testFullContractLifecycle() async throws {
        // MARK: - Setup
        print("Setting up transport and signer...")
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let signer = try PrivateKeySigner(hexPrivateKey: AnvilAccounts.privateKey0)
        let client = EvmClient(transport: transport)
        let evmSigner = client.withSigner(signer: signer)

        // MARK: - Compilation
        print("Compiling contract...")
        let compiler = try await Solc.create(version: "0.8.21")

        let input = Input(
            language: "Solidity",
            sources: [
                "TestContract.sol": SourceIn(content: Self.testContractSource)
            ],
            settings: Settings(
                optimizer: Optimizer(enabled: true, runs: 200),
                outputSelection: [
                    "*": [
                        "*": ["abi", "evm.bytecode.object"]
                    ]
                ]
            )
        )

        let output = try await compiler.compile(input, options: nil)

        // Check for compilation errors
        if let errors = output.errors {
            let errorMessages = errors.filter { $0.severity == "error" }
            if !errorMessages.isEmpty {
                throw TestError.compilationFailed(
                    errorMessages.map { $0.formattedMessage ?? "Unknown error" }.joined(
                        separator: "\n")
                )
            }
        }

        // Extract bytecode and ABI
        guard let contractData = output.contracts?["TestContract.sol"]?["TestContract"] else {
            throw TestError.compilationFailed("Contract not found in output")
        }

        guard let bytecodeHex = contractData.evm?.bytecode?.object else {
            throw TestError.compilationFailed("Bytecode not found in output")
        }

        guard let abiArray = contractData.abi else {
            throw TestError.compilationFailed("ABI not found in output")
        }

        print("Compilation successful!")
        print("Bytecode length: \(bytecodeHex.count) characters")
        print("ABI items: \(abiArray.count)")

        // Parse ABI
        let abiJsonData = try JSONEncoder().encode(abiArray)
        let abiJsonString = String(data: abiJsonData, encoding: .utf8)!
        let abiParser = try AbiParser(fromJsonString: abiJsonString)

        // MARK: - Deployment
        print("\nDeploying contract...")
        let initialValue = BigInt(42)

        let deployableContract = DeployableEvmContract(
            bytecode: bytecodeHex,
            abi: abiParser.items,
            evmSigner: evmSigner
        )

        let contract = try await deployableContract.deploy(
            constructorArgs: [AnyCodable(initialValue)],
            importCallback: nil,
            value: TransactionValue(wei: Wei(bigInt: BigInt(0))),
            gasLimit: GasLimit(bigInt: BigInt(3_000_000)),
            gasPrice: nil as Gwei?
        )

        print("Contract deployed at: \(contract.address.value)")

        // MARK: - Test Read-Only Function (getValue)
        print("\nTesting read-only function: getValue()")

        let currentValueResult = try await contract.callFunction(
            name: "getValue",
            args: [],
            value: TransactionValue(wei: Wei(bigInt: BigInt(0))),
            gasLimit: nil as GasLimit?,
            gasPrice: nil as Gwei?
        )
        let currentValue = currentValueResult.result.value as! BigInt

        print("Current value: \(currentValue)")
        #expect(currentValue == initialValue, "Initial value should be \(initialValue)")
        #expect(currentValueResult.transactionHash == nil, "Read-only call should not have transaction hash")

        // MARK: - Test State-Changing Function (setValue)
        print("\nTesting state-changing function: setValue()")

        let newValue = BigInt(100)

        // Call writable function using callFunction
        let setValueResult = try await contract.callFunction(
            name: "setValue",
            args: [AnyCodable(newValue)],
            value: TransactionValue(wei: Wei(bigInt: BigInt(0))),
            gasLimit: GasLimit(bigInt: BigInt(100_000)),
            gasPrice: nil as Gwei?
        )
        let setValueTxHash = setValueResult.result.value as! String

        print("Transaction sent and mined: \(setValueTxHash)")
        #expect(setValueResult.transactionHash == setValueTxHash, "Transaction hash should match")

        // Verify value changed
        let updatedValueResult = try await contract.callFunction(
            name: "getValue",
            args: [],
            value: TransactionValue(wei: Wei(bigInt: BigInt(0))),
            gasLimit: nil as GasLimit?,
            gasPrice: nil as Gwei?
        )
        let updatedValue = updatedValueResult.result.value as! BigInt

        print("Updated value: \(updatedValue)")
        #expect(updatedValue == newValue, "Value should be updated to \(newValue)")

        // MARK: - Test State-Changing Function (increment)
        print("\nTesting state-changing function: increment()")

        // Call writable function using callFunction
        let incrementResult = try await contract.callFunction(
            name: "increment",
            args: [],
            value: TransactionValue(wei: Wei(bigInt: BigInt(0))),
            gasLimit: GasLimit(bigInt: BigInt(100_000)),
            gasPrice: nil as Gwei?
        )
        let incrementTxHash = incrementResult.result.value as! String

        print("Transaction sent and mined: \(incrementTxHash)")
        #expect(incrementResult.transactionHash != nil, "Write operation should have transaction hash")

        // Verify value incremented
        let incrementedValueResult = try await contract.callFunction(
            name: "getValue",
            args: [],
            value: TransactionValue(wei: Wei(bigInt: BigInt(0))),
            gasLimit: nil as GasLimit?,
            gasPrice: nil as Gwei?
        )
        let incrementedValue = incrementedValueResult.result.value as! BigInt

        print("Incremented value: \(incrementedValue)")
        #expect(incrementedValue == newValue + 1, "Value should be incremented to \(newValue + 1)")

        // MARK: - Test Payable Function (deposit)
        print("\nTesting payable function: deposit()")

        let depositAmount = Wei(bigInt: BigInt(1_000_000_000_000_000_000))  // 1 ETH in wei

        // Call payable writable function using callFunction
        let depositResult = try await contract.callFunction(
            name: "deposit",
            args: [],
            value: TransactionValue(wei: depositAmount),
            gasLimit: GasLimit(bigInt: BigInt(100_000)),
            gasPrice: nil as Gwei?
        )
        let depositTxHash = depositResult.result.value as! String

        print("Deposit transaction sent and mined: \(depositTxHash)")
        #expect(depositResult.transactionHash != nil, "Payable write should have transaction hash")

        // Verify balance updated
        let balanceResult = try await contract.callFunction(
            name: "getBalance",
            args: [AnyCodable(signer.address.value)],
            value: TransactionValue(wei: Wei(bigInt: BigInt(0))),
            gasLimit: nil as GasLimit?,
            gasPrice: nil as Gwei?
        )
        let balance = balanceResult.result.value as! BigInt

        print("Balance for \(signer.address.value): \(balance)")
        #expect(balance == depositAmount.value, "Balance should be \(depositAmount.value)")

        // Verify contract balance
        let contractBalanceResult = try await contract.callFunction(
            name: "getContractBalance",
            args: [],
            value: TransactionValue(wei: Wei(bigInt: BigInt(0))),
            gasLimit: nil as GasLimit?,
            gasPrice: nil as Gwei?
        )
        let contractBalance = contractBalanceResult.result.value as! BigInt

        print("Contract balance: \(contractBalance)")
        #expect(contractBalance == depositAmount.value, "Contract balance should be \(depositAmount.value)")

        // MARK: - Test Payable Function with Parameters (depositFor)
        print("\nTesting payable function with parameters: depositFor()")

        let recipient = AnvilAccounts.account1
        let depositForAmount = Wei(bigInt: BigInt(500_000_000_000_000_000))  // 0.5 ETH in wei

        // Call payable writable function with parameters using callFunction
        let depositForResult = try await contract.callFunction(
            name: "depositFor",
            args: [AnyCodable(recipient)],
            value: TransactionValue(wei: depositForAmount),
            gasLimit: GasLimit(bigInt: BigInt(100_000)),
            gasPrice: nil as Gwei?
        )
        let depositForTxHash = depositForResult.result.value as! String

        print("DepositFor transaction sent and mined: \(depositForTxHash)")
        #expect(depositForResult.transactionHash != nil, "Payable write with params should have transaction hash")

        // Verify recipient balance
        let recipientBalanceResult = try await contract.callFunction(
            name: "getBalance",
            args: [AnyCodable(recipient)],
            value: TransactionValue(wei: Wei(bigInt: BigInt(0))),
            gasLimit: nil as GasLimit?,
            gasPrice: nil as Gwei?
        )
        let recipientBalance = recipientBalanceResult.result.value as! BigInt

        print("Balance for recipient \(recipient): \(recipientBalance)")
        #expect(
            recipientBalance == depositForAmount.value, "Recipient balance should be \(depositForAmount.value)")

        // Verify total deposited
        let totalDepositedResult = try await contract.callFunction(
            name: "getTotalDeposited",
            args: [],
            value: TransactionValue(wei: Wei(bigInt: BigInt(0))),
            gasLimit: nil as GasLimit?,
            gasPrice: nil as Gwei?
        )
        let totalDeposited = totalDepositedResult.result.value as! BigInt

        let expectedTotal = depositAmount.value + depositForAmount.value
        print("Total deposited: \(totalDeposited)")
        #expect(totalDeposited == expectedTotal, "Total deposited should be \(expectedTotal)")

        // Verify final contract balance
        let finalContractBalanceResult = try await contract.callFunction(
            name: "getContractBalance",
            args: [],
            value: TransactionValue(wei: Wei(bigInt: BigInt(0))),
            gasLimit: nil as GasLimit?,
            gasPrice: nil as Gwei?
        )
        let finalContractBalance = finalContractBalanceResult.result.value as! BigInt

        print("Final contract balance: \(finalContractBalance)")
        #expect(
            finalContractBalance == expectedTotal,
            "Final contract balance should be \(expectedTotal)")

        print("\n✅ All tests passed!")
    }

    @Test("Deploy contract without constructor arguments")
    func testDeploySimpleContract() async throws {
        let simpleContract = """
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

        print("Setting up transport and signer...")
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let signer = try PrivateKeySigner(hexPrivateKey: AnvilAccounts.privateKey0)
        let client = EvmClient(transport: transport)
        let evmSigner = client.withSigner(signer: signer)

        print("Compiling simple contract...")
        let compiler = try await Solc.create(version: "0.8.21")

        let input = Input(
            language: "Solidity",
            sources: ["SimpleStorage.sol": SourceIn(content: simpleContract)],
            settings: Settings(
                outputSelection: ["*": ["*": ["abi", "evm.bytecode.object"]]]
            )
        )

        let output = try await compiler.compile(input, options: nil)

        guard let contractData = output.contracts?["SimpleStorage.sol"]?["SimpleStorage"],
            let bytecodeHex = contractData.evm?.bytecode?.object,
            let abiArray = contractData.abi
        else {
            throw TestError.compilationFailed("Failed to extract contract data")
        }

        let abiJsonData = try JSONEncoder().encode(abiArray)
        let abiJsonString = String(data: abiJsonData, encoding: .utf8)!
        let abiParser = try AbiParser(fromJsonString: abiJsonString)

        print("Deploying simple contract...")
        let deployableContract = DeployableEvmContract(
            bytecode: bytecodeHex,
            abi: abiParser.items,
            evmSigner: evmSigner
        )

        let contract = try await deployableContract.deploy(
            constructorArgs: [],  // No constructor arguments
            importCallback: nil,
            value: TransactionValue(wei: Wei(bigInt: BigInt(0))),
            gasLimit: GasLimit(bigInt: BigInt(1_000_000)),
            gasPrice: nil as Gwei?
        )

        print("Contract deployed at: \(contract.address.value)")

        // Test initial value
        let initialValueResult = try await contract.callFunction(
            name: "getValue",
            args: [],
            value: TransactionValue(wei: Wei(bigInt: BigInt(0))),
            gasLimit: nil as GasLimit?,
            gasPrice: nil as Gwei?
        )
        let initialValue = initialValueResult.result.value as! BigInt

        print("Initial value: \(initialValue)")
        #expect(initialValue == 0, "Initial value should be 0")

        print("✅ Simple contract deployment test passed!")
    }
}

// MARK: - Test Errors

enum TestError: Error, LocalizedError {
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
