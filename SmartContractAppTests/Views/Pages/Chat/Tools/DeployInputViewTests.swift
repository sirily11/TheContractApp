//
//  DeployInputViewTests.swift
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
struct DeployInputViewTests {

    // MARK: - Test Infrastructure

    /// Create a test environment with ModelContainer and ToolRegistry
    @MainActor private func createTestEnvironment(
        deploymentFailures: [String: String] = [:],
        deploymentSuccesses: [String: String] = [:]
    ) throws -> (container: ModelContainer, registry: ToolRegistry, endpoint: Endpoint) {
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

        // Create ToolRegistry with pre-populated state
        let registry = ToolRegistry()
        registry.modelContext = container.mainContext

        // Populate failure/success dictionaries
        for (key, value) in deploymentFailures {
            registry.deploymentFailures[key] = value
        }
        for (key, value) in deploymentSuccesses {
            registry.deploymentSuccesses[key] = value
        }

        return (container, registry, endpoint)
    }

    /// Create a sample DeployInput
    private func createDeployInput(endpointId: String) -> DeployInput {
        DeployInput(
            sourceCode: "contract Test {}",
            constructorArgs: ["value": "100"],
            endpointId: endpointId,
            name: "TestContract"
        )
    }

    // MARK: - Idle State Tests

    @Test("Idle state shows Sign & Deploy button when no registry entries")
    @MainActor func testIdleStateShowsDeployButton() async throws {
        // Arrange
        let (container, registry, endpoint) = try createTestEnvironment()
        let toolCallId = "test-tool-call-id"
        let input = createDeployInput(endpointId: endpoint.id.uuidString)

        let view = DeployInputView(
            deployInput: input,
            status: .waitingForResult,
            toolCallId: toolCallId,
            toolRegistry: registry
        ) {
            // No-op callback
        }
        .modelContainer(container)

        // Act
        let inspectedView = try view.inspect()

        // Assert - Should find "Sign & Deploy" button text (throws if not found)
        _ = try inspectedView.find(text: "Sign & Deploy")
    }

    // MARK: - Failed State Tests

    @Test("Failed state shows error message and Retry button")
    @MainActor func testFailedStateShowsErrorMessage() async throws {
        // Arrange
        let toolCallId = "failed-tool-call-id"
        let errorMessage = "Transaction rejected by user"

        let (container, registry, endpoint) = try createTestEnvironment(
            deploymentFailures: [toolCallId: errorMessage]
        )
        let input = createDeployInput(endpointId: endpoint.id.uuidString)

        let view = DeployInputView(
            deployInput: input,
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

    @Test("Success state shows Deployed badge and contract address")
    @MainActor func testSuccessStateShowsDeployedBadge() async throws {
        // Arrange
        let toolCallId = "success-tool-call-id"
        let contractAddress = "0x1234567890abcdef1234567890abcdef12345678"

        let (container, registry, endpoint) = try createTestEnvironment(
            deploymentSuccesses: [toolCallId: contractAddress]
        )
        let input = createDeployInput(endpointId: endpoint.id.uuidString)

        let view = DeployInputView(
            deployInput: input,
            status: .waitingForResult,
            toolCallId: toolCallId,
            toolRegistry: registry
        ) {
            // No-op callback
        }
        .modelContainer(container)

        // Act
        let inspectedView = try view.inspect()

        // Assert - Should find "Deployed" text (throws if not found)
        _ = try inspectedView.find(text: "Deployed")

        // Assert - Should find contract address (throws if not found)
        _ = try inspectedView.find(text: contractAddress)
    }

    // MARK: - Rejected Status Tests

    @Test("Rejected status shows Rejected badge")
    @MainActor func testRejectedStatusShowsRejectedBadge() async throws {
        // Arrange
        let (container, registry, endpoint) = try createTestEnvironment()
        let toolCallId = "rejected-tool-call-id"
        let input = createDeployInput(endpointId: endpoint.id.uuidString)

        let view = DeployInputView(
            deployInput: input,
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
