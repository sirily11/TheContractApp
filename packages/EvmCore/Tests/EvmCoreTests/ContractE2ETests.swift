import Testing
import Foundation
import BigInt
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
        let signer = try AnvilSigner(addressString: AnvilAccounts.account0)

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
                    errorMessages.map { $0.formattedMessage ?? "Unknown error" }.joined(separator: "\n")
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
            signer: signer,
            transport: transport
        )

        let contract = try await deployableContract.deploy(
            constructorArgs: [AnyCodable(initialValue)],
            importCallback: nil as ((_ url: String) -> EvmCore.ImportResult)?,
            value: BigInt(0),
            gasLimit: BigInt(3_000_000),
            gasPrice: nil as BigInt?
        )

        print("Contract deployed at: \(contract.address.value)")

        // MARK: - Test Read-Only Function (getValue)
        print("\nTesting read-only function: getValue()")

        let currentValue: BigInt = try await contract.callFunction(
            name: "getValue",
            args: [],
            value: BigInt(0),
            gasLimit: nil,
            gasPrice: nil
        )

        print("Current value: \(currentValue)")
        #expect(currentValue == initialValue, "Initial value should be \(initialValue)")

        // MARK: - Test State-Changing Function (setValue)
        print("\nTesting state-changing function: setValue()")

        let newValue = BigInt(100)
        let txHelper = TransactionHelper(transport: transport)

        // Find setValue function
        guard let setValueFunc = contract.functions.first(where: { $0.name == "setValue" }) else {
            throw TestError.testFailed("setValue function not found")
        }

        // Encode function call
        let setValueCallData = try setValueFunc.encodeCall(args: [newValue])

        // Send transaction
        let setValueTxHash = try await txHelper.sendTransaction(
            from: signer.address,
            to: contract.address,
            data: setValueCallData,
            value: BigInt(0),
            gas: BigInt(100_000),
            gasPrice: nil
        )

        print("Transaction sent: \(setValueTxHash)")

        // Wait for receipt
        let setValueReceipt = try await txHelper.waitForReceipt(txHash: setValueTxHash)
        print("Transaction mined in block: \(setValueReceipt.blockNumber)")
        #expect(setValueReceipt.isSuccessful, "setValue transaction should succeed")

        // Verify value changed
        let updatedValue: BigInt = try await contract.callFunction(
            name: "getValue",
            args: [],
            value: BigInt(0),
            gasLimit: nil,
            gasPrice: nil
        )

        print("Updated value: \(updatedValue)")
        #expect(updatedValue == newValue, "Value should be updated to \(newValue)")

        // MARK: - Test State-Changing Function (increment)
        print("\nTesting state-changing function: increment()")

        guard let incrementFunc = contract.functions.first(where: { $0.name == "increment" }) else {
            throw TestError.testFailed("increment function not found")
        }

        let incrementCallData = try incrementFunc.encodeCall(args: [])
        let incrementTxHash = try await txHelper.sendTransaction(
            from: signer.address,
            to: contract.address,
            data: incrementCallData,
            value: BigInt(0),
            gas: BigInt(100_000),
            gasPrice: nil
        )

        let incrementReceipt = try await txHelper.waitForReceipt(txHash: incrementTxHash)
        #expect(incrementReceipt.isSuccessful, "increment transaction should succeed")

        // Verify value incremented
        let incrementedValue: BigInt = try await contract.callFunction(
            name: "getValue",
            args: [],
            value: BigInt(0),
            gasLimit: nil,
            gasPrice: nil
        )

        print("Incremented value: \(incrementedValue)")
        #expect(incrementedValue == newValue + 1, "Value should be incremented to \(newValue + 1)")

        // MARK: - Test Payable Function (deposit)
        print("\nTesting payable function: deposit()")

        let depositAmount = BigInt(1_000_000_000_000_000_000) // 1 ETH in wei

        guard let depositFunc = contract.functions.first(where: { $0.name == "deposit" }) else {
            throw TestError.testFailed("deposit function not found")
        }

        let depositCallData = try depositFunc.encodeCall(args: [])
        let depositTxHash = try await txHelper.sendTransaction(
            from: signer.address,
            to: contract.address,
            data: depositCallData,
            value: depositAmount,
            gas: BigInt(100_000),
            gasPrice: nil
        )

        let depositReceipt = try await txHelper.waitForReceipt(txHash: depositTxHash)
        print("Deposit transaction mined: \(depositReceipt.transactionHash)")
        #expect(depositReceipt.isSuccessful, "deposit transaction should succeed")

        // Verify balance updated
        let balance: BigInt = try await contract.callFunction(
            name: "getBalance",
            args: [AnyCodable(signer.address.value)],
            value: BigInt(0),
            gasLimit: nil,
            gasPrice: nil
        )

        print("Balance for \(signer.address.value): \(balance)")
        #expect(balance == depositAmount, "Balance should be \(depositAmount)")

        // Verify contract balance
        let contractBalance: BigInt = try await contract.callFunction(
            name: "getContractBalance",
            args: [],
            value: BigInt(0),
            gasLimit: nil,
            gasPrice: nil
        )

        print("Contract balance: \(contractBalance)")
        #expect(contractBalance == depositAmount, "Contract balance should be \(depositAmount)")

        // MARK: - Test Payable Function with Parameters (depositFor)
        print("\nTesting payable function with parameters: depositFor()")

        let recipient = AnvilAccounts.account1
        let depositForAmount = BigInt(500_000_000_000_000_000) // 0.5 ETH in wei

        guard let depositForFunc = contract.functions.first(where: { $0.name == "depositFor" }) else {
            throw TestError.testFailed("depositFor function not found")
        }

        let depositForCallData = try depositForFunc.encodeCall(args: [recipient])
        let depositForTxHash = try await txHelper.sendTransaction(
            from: signer.address,
            to: contract.address,
            data: depositForCallData,
            value: depositForAmount,
            gas: BigInt(100_000),
            gasPrice: nil
        )

        let depositForReceipt = try await txHelper.waitForReceipt(txHash: depositForTxHash)
        #expect(depositForReceipt.isSuccessful, "depositFor transaction should succeed")

        // Verify recipient balance
        let recipientBalance: BigInt = try await contract.callFunction(
            name: "getBalance",
            args: [AnyCodable(recipient)],
            value: BigInt(0),
            gasLimit: nil,
            gasPrice: nil
        )

        print("Balance for recipient \(recipient): \(recipientBalance)")
        #expect(recipientBalance == depositForAmount, "Recipient balance should be \(depositForAmount)")

        // Verify total deposited
        let totalDeposited: BigInt = try await contract.callFunction(
            name: "getTotalDeposited",
            args: [],
            value: BigInt(0),
            gasLimit: nil,
            gasPrice: nil
        )

        let expectedTotal = depositAmount + depositForAmount
        print("Total deposited: \(totalDeposited)")
        #expect(totalDeposited == expectedTotal, "Total deposited should be \(expectedTotal)")

        // Verify final contract balance
        let finalContractBalance: BigInt = try await contract.callFunction(
            name: "getContractBalance",
            args: [],
            value: BigInt(0),
            gasLimit: nil,
            gasPrice: nil
        )

        print("Final contract balance: \(finalContractBalance)")
        #expect(finalContractBalance == expectedTotal, "Final contract balance should be \(expectedTotal)")

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
        let signer = try AnvilSigner(addressString: AnvilAccounts.account0)

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
              let abiArray = contractData.abi else {
            throw TestError.compilationFailed("Failed to extract contract data")
        }

        let abiJsonData = try JSONEncoder().encode(abiArray)
        let abiJsonString = String(data: abiJsonData, encoding: .utf8)!
        let abiParser = try AbiParser(fromJsonString: abiJsonString)

        print("Deploying simple contract...")
        let deployableContract = DeployableEvmContract(
            bytecode: bytecodeHex,
            abi: abiParser.items,
            signer: signer,
            transport: transport
        )

        let contract = try await deployableContract.deploy(
            constructorArgs: [], // No constructor arguments
            importCallback: nil as ((_ url: String) -> EvmCore.ImportResult)?,
            value: BigInt(0),
            gasLimit: BigInt(1_000_000),
            gasPrice: nil as BigInt?
        )

        print("Contract deployed at: \(contract.address.value)")

        // Test initial value
        let initialValue: BigInt = try await contract.callFunction(
            name: "getValue",
            args: [],
            value: BigInt(0),
            gasLimit: nil,
            gasPrice: nil
        )

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
