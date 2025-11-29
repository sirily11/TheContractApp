//
//  CallWriteInputViewTests.swift
//  SmartContractAppTests
//
//  Created by Claude on 11/29/25.
//

import AgentLayout
import SwiftData
import SwiftUI
import Testing
import ViewInspector
@testable import SmartContractApp

@Suite(.serialized)
struct CallWriteInputViewTests {

    // MARK: - Test Infrastructure

    /// Create a test environment with ModelContainer and ToolRegistry
    @MainActor private func createTestEnvironment(
        writeCallFailures: [String: String] = [:],
        writeCallSuccesses: [String: String] = [:]
    ) throws -> (container: ModelContainer, registry: ToolRegistry, contract: EVMContract) {
        // Create in-memory ModelContainer
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Endpoint.self, EVMContract.self, EvmAbi.self, EVMWallet.self,
            configurations: config
        )

        // Create a sample endpoint
        let endpoint = Endpoint(
            name: "Test Network",
            url: "http://localhost:8545",
            chainId: "1"
        )
        container.mainContext.insert(endpoint)

        // Create a sample contract
        let contract = EVMContract(
            name: "Test Token",
            address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
            status: .deployed,
            endpointId: endpoint.id
        )
        container.mainContext.insert(contract)

        // Create ToolRegistry with pre-populated state
        let registry = ToolRegistry()
        registry.modelContext = container.mainContext

        // Populate failure/success dictionaries
        for (key, value) in writeCallFailures {
            registry.writeCallFailures[key] = value
        }
        for (key, value) in writeCallSuccesses {
            registry.writeCallSuccesses[key] = value
        }

        return (container, registry, contract)
    }

    /// Create a sample CallWriteInput
    private func createCallWriteInput(contractId: String) -> CallWriteInput {
        CallWriteInput.preview(
            contractId: contractId,
            functionName: "transfer",
            args: ["recipient": "0x1234", "amount": "1000"],
            value: "0"
        )
    }

    // MARK: - Idle State Tests

    @Test("Idle state shows Sign & Send button when no registry entries")
    @MainActor func testIdleStateShowsSendButton() async throws {
        // Arrange
        let (container, registry, contract) = try createTestEnvironment()
        let toolCallId = "test-tool-call-id"
        let input = createCallWriteInput(contractId: contract.id.uuidString)

        let view = CallWriteInputView(
            input: input,
            status: .waitingForResult,
            toolCallId: toolCallId,
            toolRegistry: registry
        ) {
            // No-op callback
        }
        .modelContainer(container)

        // Act
        let inspectedView = try view.inspect()

        // Assert - Should find "Sign & Send" button text (throws if not found)
        _ = try inspectedView.find(text: "Sign & Send")
    }

    // MARK: - Failed State Tests

    @Test("Failed state shows error message and Retry button")
    @MainActor func testFailedStateShowsErrorMessage() async throws {
        // Arrange
        let toolCallId = "failed-tool-call-id"
        let errorMessage = "Transaction rejected by user"

        let (container, registry, contract) = try createTestEnvironment(
            writeCallFailures: [toolCallId: errorMessage]
        )
        let input = createCallWriteInput(contractId: contract.id.uuidString)

        let view = CallWriteInputView(
            input: input,
            status: .waitingForResult,
            toolCallId: toolCallId,
            toolRegistry: registry
        ) {
            // No-op callback
        }
        .modelContainer(container)

        // Act
        let inspectedView = try view.inspect()

        // Assert - Should find error message (throws if not found)
        _ = try inspectedView.find(text: errorMessage)

        // Assert - Should find Retry button (throws if not found)
        _ = try inspectedView.find(button: "Retry")
    }

    // MARK: - Success State Tests

    @Test("Success state shows Sent badge and transaction hash")
    @MainActor func testSuccessStateShowsSentBadge() async throws {
        // Arrange
        let toolCallId = "success-tool-call-id"
        let txHash = "0xabcdef1234567890abcdef1234567890abcdef12"

        let (container, registry, contract) = try createTestEnvironment(
            writeCallSuccesses: [toolCallId: txHash]
        )
        let input = createCallWriteInput(contractId: contract.id.uuidString)

        let view = CallWriteInputView(
            input: input,
            status: .waitingForResult,
            toolCallId: toolCallId,
            toolRegistry: registry
        ) {
            // No-op callback
        }
        .modelContainer(container)

        // Act
        let inspectedView = try view.inspect()

        // Assert - Should find "Sent" text (throws if not found)
        _ = try inspectedView.find(text: "Sent")

        // Assert - Should find transaction hash (throws if not found)
        _ = try inspectedView.find(text: txHash)
    }

    // MARK: - Rejected Status Tests

    @Test("Rejected status shows Rejected badge")
    @MainActor func testRejectedStatusShowsRejectedBadge() async throws {
        // Arrange
        let (container, registry, contract) = try createTestEnvironment()
        let toolCallId = "rejected-tool-call-id"
        let input = createCallWriteInput(contractId: contract.id.uuidString)

        let view = CallWriteInputView(
            input: input,
            status: .rejected,
            toolCallId: toolCallId,
            toolRegistry: registry
        ) {
            // No-op callback
        }
        .modelContainer(container)

        // Act
        let inspectedView = try view.inspect()

        // Assert - Should find "Rejected" text (throws if not found)
        _ = try inspectedView.find(text: "Rejected")
    }
}
