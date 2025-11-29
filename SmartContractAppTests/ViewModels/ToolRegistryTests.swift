//
//  ToolRegistryTests.swift
//  SmartContractAppTests
//
//  Created by Claude on 11/29/25.
//

import Combine
import EvmCore
@testable import SmartContractApp
import SwiftData
import XCTest

// MARK: - Mock Chat Provider

final class MockChatProvider: @unchecked Sendable, ChatProviderProtocol {
    var sendFunctionResultCallCount = 0
    var lastSentId: String?
    var lastSentResult: (any Encodable)?
    var sentResults: [(id: String, result: any Encodable)] = []

    func sendFunctionResult(id: String, result: any Encodable) async throws {
        sendFunctionResultCallCount += 1
        lastSentId = id
        lastSentResult = result
        sentResults.append((id: id, result: result))
    }
}

// MARK: - Mock Wallet Signer

final class MockWalletSigner: WalletSignerProtocol {
    private let transactionEventSubject = PassthroughSubject<TransactionEvent, Never>()

    var transactionEventPublisher: AnyPublisher<TransactionEvent, Never> {
        transactionEventSubject.eraseToAnyPublisher()
    }

    var queueTransactionCallCount = 0
    var lastQueuedTransaction: QueuedTransaction?
    var getWalletSignerCallCount = 0
    var signerToReturn: Signer?
    var signerError: Error?

    func queueTransaction(tx: QueuedTransaction) {
        queueTransactionCallCount += 1
        lastQueuedTransaction = tx
    }

    func getWalletSigner() throws -> Signer {
        getWalletSignerCallCount += 1
        if let error = signerError {
            throw error
        }
        guard let signer = signerToReturn else {
            throw WalletSignerError.noWalletSelected
        }
        return signer
    }

    /// Emit a transaction event for testing
    func emitEvent(_ event: TransactionEvent) {
        transactionEventSubject.send(event)
    }
}

// MARK: - Mock Contract Deployment Provider

final class MockContractDeploymentProvider: ContractDeploymentProtocol {
    var compileSolidityCallCount = 0
    var deployBytecodeCallCount = 0

    var compilationResult: (bytecode: String, abi: String)?
    var compilationError: Error?

    var deploymentResult: QueuedTransaction?
    var deploymentError: Error?

    func compileSolidity(
        _ source: String,
        contractName: String?,
        version: String
    ) async throws -> (bytecode: String, abi: String) {
        compileSolidityCallCount += 1
        if let error = compilationError {
            throw error
        }
        guard let result = compilationResult else {
            throw SmartContractApp.DeploymentError.compilationFailed("No compilation result configured")
        }
        return result
    }

    func deployBytecodeToNetwork(
        _ bytecode: String,
        abi: [AbiItem],
        endpoint: Endpoint,
        value: TransactionValue,
        constructorParameters: [TransactionParameter]
    ) async throws -> QueuedTransaction {
        deployBytecodeCallCount += 1
        if let error = deploymentError {
            throw error
        }
        guard let result = deploymentResult else {
            throw SmartContractApp.DeploymentError.transactionFailed("No deployment result configured")
        }
        return result
    }
}

// MARK: - Tool Registry Tests

@MainActor
final class ToolRegistryTests: XCTestCase {
    var toolRegistry: ToolRegistry!
    var mockChatProvider: MockChatProvider!
    var mockWalletSigner: MockWalletSigner!
    var mockDeploymentProvider: MockContractDeploymentProvider!
    var modelContainer: ModelContainer!

    override func setUpWithError() throws {
        let schema = Schema([
            Endpoint.self,
            EVMContract.self,
            EvmAbi.self,
            EVMWallet.self,
            Transaction.self,
            ContractFunctionCall.self,
            ChatHistory.self,
            AIProvider.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [config])

        toolRegistry = ToolRegistry()
        mockChatProvider = MockChatProvider()
        mockWalletSigner = MockWalletSigner()
        mockDeploymentProvider = MockContractDeploymentProvider()

        toolRegistry.modelContext = modelContainer.mainContext
        toolRegistry.walletSigner = mockWalletSigner
        toolRegistry.setProviders(mockChatProvider, deploymentProvider: mockDeploymentProvider)
    }

    override func tearDown() {
        toolRegistry = nil
        mockChatProvider = nil
        mockWalletSigner = nil
        mockDeploymentProvider = nil
        modelContainer = nil
    }

    // MARK: - handleTransaction Tests

    func testHandleTransaction_ContractCreated_SendsChatResult() async throws {
        // Arrange
        let toolCallId = "test-tool-call-id"
        let transactionId = UUID()
        let txHash = "0x1234567890abcdef"
        let contractAddress = "0xContractAddress"

        // Create endpoint for the deployment
        let endpoint = Endpoint(name: "Test", url: "http://localhost:8545", chainId: "1")
        modelContainer.mainContext.insert(endpoint)
        try modelContainer.mainContext.save()

        let deploymentInfo = PendingDeploymentInfo(
            toolCallId: toolCallId,
            name: "TestContract",
            sourceCode: "contract Test {}",
            abiJson: "[]",
            bytecode: "0x123",
            endpointId: endpoint.id
        )

        let queuedTx = QueuedTransaction(
            id: transactionId,
            to: "",
            value: .ether(.init(bigInt: .zero)),
            data: nil,
            gasEstimate: nil,
            contractFunctionName: .constructor,
            contractParameters: [],
            status: .pending,
            bytecode: "0x123",
            abi: []
        )

        toolRegistry.pendingDeployments[transactionId] = deploymentInfo

        // Act
        mockWalletSigner.emitEvent(.contractCreated(txHash: txHash, contractAddress: contractAddress, transaction: queuedTx))

        // Wait for event processing
        try await Task.sleep(nanoseconds: 200_000_000)

        // Assert
        XCTAssertEqual(mockChatProvider.sendFunctionResultCallCount, 1)
        XCTAssertEqual(mockChatProvider.lastSentId, toolCallId)

        if let result = mockChatProvider.lastSentResult as? DeployOutput {
            XCTAssertTrue(result.success)
            XCTAssertEqual(result.contractAddress, contractAddress)
            XCTAssertEqual(result.txHash, txHash)
        } else {
            XCTFail("Expected DeployOutput result")
        }
    }

    func testHandleTransaction_Sent_SendsChatResultForWriteCall() async throws {
        // Arrange
        let toolCallId = "write-call-id"
        let transactionId = UUID()
        let txHash = "0xWriteCallTxHash"

        let queuedTx = QueuedTransaction(
            id: transactionId,
            to: "0xRecipient",
            value: .ether(.init(bigInt: .zero)),
            data: nil,
            gasEstimate: nil,
            contractFunctionName: .function(name: "transfer"),
            contractParameters: [],
            status: .pending,
            bytecode: nil,
            abi: []
        )

        toolRegistry.pendingWriteCalls[transactionId] = toolCallId

        // Act
        mockWalletSigner.emitEvent(.sent(txHash: txHash, transaction: queuedTx))

        // Wait for event processing
        try await Task.sleep(nanoseconds: 200_000_000)

        // Assert
        XCTAssertEqual(mockChatProvider.sendFunctionResultCallCount, 1)
        XCTAssertEqual(mockChatProvider.lastSentId, toolCallId)

        if let result = mockChatProvider.lastSentResult as? CallWriteOutput {
            XCTAssertTrue(result.success)
            XCTAssertEqual(result.txHash, txHash)
        } else {
            XCTFail("Expected CallWriteOutput result")
        }
    }

    func testHandleTransaction_Rejected_SendsChatResultForDeployment() async throws {
        // Arrange
        let toolCallId = "rejected-deploy-id"
        let transactionId = UUID()

        let deploymentInfo = PendingDeploymentInfo(
            toolCallId: toolCallId,
            name: "RejectedContract",
            sourceCode: "contract Test {}",
            abiJson: "[]",
            bytecode: "0x123",
            endpointId: UUID()
        )

        let queuedTx = QueuedTransaction(
            id: transactionId,
            to: "",
            value: .ether(.init(bigInt: .zero)),
            data: nil,
            gasEstimate: nil,
            contractFunctionName: .constructor,
            contractParameters: [],
            status: .pending,
            bytecode: "0x123",
            abi: []
        )

        toolRegistry.pendingDeployments[transactionId] = deploymentInfo

        // Act
        mockWalletSigner.emitEvent(.rejected(queuedTx))

        // Wait for event processing
        try await Task.sleep(nanoseconds: 200_000_000)

        // Assert
        XCTAssertEqual(mockChatProvider.sendFunctionResultCallCount, 1)
        XCTAssertEqual(mockChatProvider.lastSentId, toolCallId)

        if let result = mockChatProvider.lastSentResult as? DeployOutput {
            XCTAssertFalse(result.success)
            XCTAssertNil(result.contractAddress)
            XCTAssertTrue(result.message.contains("rejected"))
        } else {
            XCTFail("Expected DeployOutput result")
        }
    }

    func testHandleTransaction_Rejected_SendsChatResultForWriteCall() async throws {
        // Arrange
        let toolCallId = "rejected-write-id"
        let transactionId = UUID()

        let queuedTx = QueuedTransaction(
            id: transactionId,
            to: "0xRecipient",
            value: .ether(.init(bigInt: .zero)),
            data: nil,
            gasEstimate: nil,
            contractFunctionName: .function(name: "transfer"),
            contractParameters: [],
            status: .pending,
            bytecode: nil,
            abi: []
        )

        toolRegistry.pendingWriteCalls[transactionId] = toolCallId

        // Act
        mockWalletSigner.emitEvent(.rejected(queuedTx))

        // Wait for event processing
        try await Task.sleep(nanoseconds: 200_000_000)

        // Assert
        XCTAssertEqual(mockChatProvider.sendFunctionResultCallCount, 1)
        XCTAssertEqual(mockChatProvider.lastSentId, toolCallId)

        if let result = mockChatProvider.lastSentResult as? CallWriteOutput {
            XCTAssertFalse(result.success)
            XCTAssertNil(result.txHash)
            XCTAssertTrue(result.message.contains("rejected"))
        } else {
            XCTFail("Expected CallWriteOutput result")
        }
    }

    func testHandleTransaction_Error_SendsChatResultForDeployment() async throws {
        // Arrange
        let toolCallId = "error-deploy-id"
        let transactionId = UUID()

        let deploymentInfo = PendingDeploymentInfo(
            toolCallId: toolCallId,
            name: "ErrorContract",
            sourceCode: "contract Test {}",
            abiJson: "[]",
            bytecode: "0x123",
            endpointId: UUID()
        )

        let queuedTx = QueuedTransaction(
            id: transactionId,
            to: "",
            value: .ether(.init(bigInt: .zero)),
            data: nil,
            gasEstimate: nil,
            contractFunctionName: .constructor,
            contractParameters: [],
            status: .pending,
            bytecode: "0x123",
            abi: []
        )

        toolRegistry.pendingDeployments[transactionId] = deploymentInfo

        let testError = NSError(domain: "TestError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Test error message"])

        // Act
        mockWalletSigner.emitEvent(.error(testError, transaction: queuedTx))

        // Wait for event processing
        try await Task.sleep(nanoseconds: 200_000_000)

        // Assert
        XCTAssertEqual(mockChatProvider.sendFunctionResultCallCount, 1)
        XCTAssertEqual(mockChatProvider.lastSentId, toolCallId)

        if let result = mockChatProvider.lastSentResult as? DeployOutput {
            XCTAssertFalse(result.success)
            XCTAssertNil(result.contractAddress)
            XCTAssertTrue(result.message.contains("failed"))
        } else {
            XCTFail("Expected DeployOutput result")
        }
    }

    func testHandleTransaction_Error_SendsChatResultForWriteCall() async throws {
        // Arrange
        let toolCallId = "error-write-id"
        let transactionId = UUID()

        let queuedTx = QueuedTransaction(
            id: transactionId,
            to: "0xRecipient",
            value: .ether(.init(bigInt: .zero)),
            data: nil,
            gasEstimate: nil,
            contractFunctionName: .function(name: "transfer"),
            contractParameters: [],
            status: .pending,
            bytecode: nil,
            abi: []
        )

        toolRegistry.pendingWriteCalls[transactionId] = toolCallId

        let testError = NSError(domain: "TestError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Write call error"])

        // Act
        mockWalletSigner.emitEvent(.error(testError, transaction: queuedTx))

        // Wait for event processing
        try await Task.sleep(nanoseconds: 200_000_000)

        // Assert
        XCTAssertEqual(mockChatProvider.sendFunctionResultCallCount, 1)
        XCTAssertEqual(mockChatProvider.lastSentId, toolCallId)

        if let result = mockChatProvider.lastSentResult as? CallWriteOutput {
            XCTAssertFalse(result.success)
            XCTAssertNil(result.txHash)
            XCTAssertTrue(result.message.contains("failed"))
        } else {
            XCTFail("Expected CallWriteOutput result")
        }
    }

    // MARK: - handleDeploy Tests

    func testHandleDeploy_CompilationError_ReturnsFailedState() async throws {
        // Arrange
        let endpoint = Endpoint(name: "Test", url: "http://localhost:8545", chainId: "1")
        modelContainer.mainContext.insert(endpoint)
        try modelContainer.mainContext.save()

        let input = DeployInput(
            sourceCode: "invalid solidity code",
            endpointId: endpoint.id.uuidString,
            name: "TestContract"
        )

        mockDeploymentProvider.compilationError = SmartContractApp.DeploymentError.compilationFailed("Syntax error")

        // Act
        let result = await toolRegistry.handleDeploy(
            input: input,
            toolCallId: "test-id"
        )

        // Assert
        if case .failed(let message) = result {
            XCTAssertTrue(message.contains("Compilation failed"))
        } else {
            XCTFail("Expected failed state")
        }

        XCTAssertEqual(mockDeploymentProvider.compileSolidityCallCount, 1)
        XCTAssertEqual(mockDeploymentProvider.deployBytecodeCallCount, 0)
    }

    func testHandleDeploy_DeploymentError_ReturnsFailedState() async throws {
        // Arrange
        let endpoint = Endpoint(name: "Test", url: "http://localhost:8545", chainId: "1")
        modelContainer.mainContext.insert(endpoint)
        try modelContainer.mainContext.save()

        let input = DeployInput(
            sourceCode: "contract Test {}",
            endpointId: endpoint.id.uuidString,
            name: "TestContract"
        )

        mockDeploymentProvider.compilationResult = (bytecode: "0x123", abi: "[]")
        mockDeploymentProvider.deploymentError = SmartContractApp.DeploymentError.transactionFailed("Network error")

        // Act
        let result = await toolRegistry.handleDeploy(
            input: input,
            toolCallId: "test-id"
        )

        // Assert
        if case .failed(let message) = result {
            XCTAssertTrue(message.contains("Failed to queue transaction"))
        } else {
            XCTFail("Expected failed state")
        }

        XCTAssertEqual(mockDeploymentProvider.compileSolidityCallCount, 1)
        XCTAssertEqual(mockDeploymentProvider.deployBytecodeCallCount, 1)
    }

    func testHandleDeploy_Success_ReturnsDeployingState() async throws {
        // Arrange
        let endpoint = Endpoint(name: "Test", url: "http://localhost:8545", chainId: "1")
        modelContainer.mainContext.insert(endpoint)
        try modelContainer.mainContext.save()

        let input = DeployInput(
            sourceCode: "contract Test {}",
            endpointId: endpoint.id.uuidString,
            name: "TestContract"
        )

        let queuedTx = QueuedTransaction(
            to: "",
            value: .ether(.init(bigInt: .zero)),
            data: nil,
            gasEstimate: nil,
            contractFunctionName: .constructor,
            contractParameters: [],
            status: .pending,
            bytecode: "0x123",
            abi: []
        )

        mockDeploymentProvider.compilationResult = (bytecode: "0x123", abi: "[]")
        mockDeploymentProvider.deploymentResult = queuedTx

        // Act
        let result = await toolRegistry.handleDeploy(
            input: input,
            toolCallId: "test-id"
        )

        // Assert
        if case .deploying = result {
            // Success
        } else {
            XCTFail("Expected deploying state, got \(result)")
        }

        XCTAssertEqual(mockDeploymentProvider.compileSolidityCallCount, 1)
        XCTAssertEqual(mockDeploymentProvider.deployBytecodeCallCount, 1)

        // Verify pending deployment was tracked
        XCTAssertNotNil(toolRegistry.pendingDeployments[queuedTx.id])
    }

    func testHandleDeploy_MissingEndpoint_ReturnsFailedState() async throws {
        // Arrange
        let input = DeployInput(
            sourceCode: "contract Test {}",
            endpointId: UUID().uuidString,  // Non-existent endpoint
            name: "TestContract"
        )

        // Act
        let result = await toolRegistry.handleDeploy(
            input: input,
            toolCallId: "test-id"
        )

        // Assert
        if case .failed(let message) = result {
            XCTAssertTrue(message.contains("Endpoint not found"))
        } else {
            XCTFail("Expected failed state")
        }
    }

    func testHandleDeploy_EmptySourceCode_ReturnsFailedState() async throws {
        // Arrange
        let endpoint = Endpoint(name: "Test", url: "http://localhost:8545", chainId: "1")
        modelContainer.mainContext.insert(endpoint)
        try modelContainer.mainContext.save()

        let input = DeployInput(
            sourceCode: "",
            endpointId: endpoint.id.uuidString,
            name: "TestContract"
        )

        // Act
        let result = await toolRegistry.handleDeploy(
            input: input,
            toolCallId: "test-id"
        )

        // Assert
        if case .failed(let message) = result {
            XCTAssertTrue(message.contains("Source code is required"))
        } else {
            XCTFail("Expected failed state")
        }
    }
}

