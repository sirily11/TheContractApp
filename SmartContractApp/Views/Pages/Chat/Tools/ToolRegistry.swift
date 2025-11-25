//
//  ToolRegistry.swift
//  SmartContractApp
//
//  Created by Claude on 11/22/25.
//

import Agent
import AgentLayout
import EvmCore
import Foundation
import Observation
import SwiftData
import SwiftUI

// MARK: - Tool Registry

/// Central registry for all AI agent tools
/// Manages tool creation and pending operations that require user interaction
@Observable
@MainActor
final class ToolRegistry {
    // MARK: - Dependencies

    var modelContext: ModelContext!
    var walletSigner: WalletSignerViewModel!

    // MARK: - Pending Operations

    /// Pending deployment waiting for user confirmation
    private(set) var pendingDeployment: PendingDeployment?

    /// Pending write call waiting for user confirmation
    private(set) var pendingWriteCall: PendingWriteCall?

    // MARK: - Initialization

    init() {}

    // MARK: - Tool Creation

    /// Creates all available tools
    func createTools() -> [any AgentToolProtocol] {
        guard let context = modelContext, let signer = walletSigner else {
            return []
        }

        return [
            // CRUD Tools
            EndpointTools.endpointManagerTool(context: context),
            ABITools.abiManagerTool(context: context),
            ContractTools.contractManagerTool(context: context),

            // Compilation Tool
            CompileTools.compileSolidityTool(),

            // Interactive Tools
            DeployTools.deployContractTool(
                context: context,
                walletSigner: signer,
                registry: self
            ),
            CallTools.callReadTool(
                context: context,
                walletSigner: signer
            ),
            CallTools.callWriteTool(
                context: context,
                walletSigner: signer,
                registry: self
            ),
        ]
    }

    // MARK: - Pending Operation Management

    /// Set pending deployment
    func setPendingDeployment(_ deployment: PendingDeployment?) async {
        pendingDeployment = deployment
    }

    /// Set pending write call
    func setPendingWriteCall(_ call: PendingWriteCall?) async {
        pendingWriteCall = call
    }

    /// Clear pending deployment
    func clearPendingDeployment() {
        pendingDeployment = nil
    }

    /// Clear pending write call
    func clearPendingWriteCall() {
        pendingWriteCall = nil
    }

    // MARK: - Message Renderer

    /// Creates a combined message renderer for tool results that need custom UI
    func createMessageRenderer() -> MessageRenderer {
        return { [weak self] message, allMessages, provider, status in
            guard let self = self else {
                return (AnyView(EmptyView()), .skip)
            }

            // Check if this message is a deployment result
            if let pending = self.pendingDeployment {
                let view = DeploymentConfirmationView(
                    deployment: pending,
                    status: status,
                    provider: provider,
                    onComplete: {
                        self.clearPendingDeployment()
                    }
                )
                return (AnyView(view), .append)
            }

            // Check if this message is a write call result
            if let pending = self.pendingWriteCall {
                let view = WriteCallConfirmationView(
                    writeCall: pending,
                    status: status,
                    provider: provider,
                    onComplete: {
                        self.clearPendingWriteCall()
                    }
                )
                return (AnyView(view), .append)
            }

            return (AnyView(EmptyView()), .skip)
        }
    }
}

// MARK: - Confirmation Views

/// View for confirming deployment transactions
struct DeploymentConfirmationView: View {
    let deployment: PendingDeployment
    let status: ToolStatus
    let provider: (any ChatProvider)?
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.badge.plus")
                    .foregroundStyle(.blue)
                Text("Contract Deployment")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                // Prefilled from input parameters
                LabeledContent("Name", value: deployment.contractName)
                LabeledContent("Endpoint", value: deployment.endpoint.name)

                // Show value if provided
                if let valueStr = deployment.input.value, !valueStr.isEmpty {
                    LabeledContent("Value", value: "\(valueStr) ETH")
                }

                if !deployment.queuedTransaction.contractParameters.isEmpty {
                    Text("Constructor Parameters:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(deployment.queuedTransaction.contractParameters) { param in
                        LabeledContent(param.name, value: param.value.toString())
                            .font(.caption)
                    }
                }
            }

            // Status indicator based on ToolStatus
            statusView
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .waitingForResult:
            HStack {
                Image(systemName: "clock.badge.questionmark")
                    .foregroundStyle(.orange)
                Text("Waiting for wallet approval...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .rejected:
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text("Deployment rejected")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        case .completed:
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Deployment confirmed")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }
}

/// View for confirming write call transactions
struct WriteCallConfirmationView: View {
    let writeCall: PendingWriteCall
    let status: ToolStatus
    let provider: (any ChatProvider)?
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "function")
                    .foregroundStyle(.purple)
                Text("Contract Call")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Contract", value: writeCall.contract.name)
                LabeledContent("Function", value: writeCall.input.functionName)

                // Prefilled parameters from input.args
                if !writeCall.queuedTransaction.contractParameters.isEmpty {
                    Text("Parameters:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(writeCall.queuedTransaction.contractParameters) { param in
                        LabeledContent(param.name, value: param.value.toString())
                            .font(.caption)
                    }
                }

                // Prefilled value from input
                if let valueStr = writeCall.input.value, !valueStr.isEmpty {
                    LabeledContent("Value", value: "\(valueStr) ETH")
                }
            }

            // Status indicator based on ToolStatus
            statusView
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .waitingForResult:
            HStack {
                Image(systemName: "clock.badge.questionmark")
                    .foregroundStyle(.orange)
                Text("Waiting for wallet approval...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .rejected:
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text("Call rejected")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        case .completed:
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Call confirmed")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Preview would need mock data
        Text("Tool Registry Preview")
    }
    .padding()
}
