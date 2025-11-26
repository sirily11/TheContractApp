//
//  CallWriteInputView.swift
//  SmartContractApp
//
//  Created on 11/26/25.
//

import AgentLayout
import SwiftData
import SwiftUI

/// UI component for displaying write function call inputs with sign & send capability
struct CallWriteInputView: View {
    // MARK: - Input Properties

    let input: CallWriteInput
    let status: ToolStatus
    let toolCallId: String?
    let toolRegistry: ToolRegistry?

    // MARK: - SwiftData

    @Environment(\.modelContext) private var modelContext
    @Query private var contracts: [EVMContract]

    // MARK: - Callback

    let onExecute: () async -> Void

    // MARK: - State

    @State private var callState: LocalCallState = .idle

    /// Local call state for UI display
    enum LocalCallState: Equatable {
        case idle
        case executing
        case failed(String)
    }

    /// Check if there's a failure from the registry (e.g., user rejection)
    private var registryFailure: String? {
        guard let toolCallId, let registry = toolRegistry else { return nil }
        return registry.writeCallFailures[toolCallId]
    }

    /// Check if call succeeded from the registry
    private var registrySuccess: String? {
        guard let toolCallId, let registry = toolRegistry else { return nil }
        return registry.writeCallSuccesses[toolCallId]
    }

    /// Combined call state - local state OR registry failure/success
    private var effectiveCallState: LocalCallState {
        if let failure = registryFailure {
            return .failed(failure)
        }
        return callState
    }

    /// Whether call has completed successfully (from registry)
    private var isCallSuccessful: Bool {
        registrySuccess != nil
    }

    // MARK: - Computed Properties

    private var contract: EVMContract? {
        guard let contractId = UUID(uuidString: input.contractId) else { return nil }
        return contracts.first { $0.id == contractId }
    }

    // MARK: - Initializer

    init(
        input: CallWriteInput,
        status: ToolStatus = .waitingForResult,
        toolCallId: String? = nil,
        toolRegistry: ToolRegistry? = nil,
        onExecute: @escaping () async -> Void
    ) {
        self.input = input
        self.status = status
        self.toolCallId = toolCallId
        self.toolRegistry = toolRegistry
        self.onExecute = onExecute
    }

    // MARK: - Body

    var body: some View {
        ToolCallCard(toolName: CallTools.nameWriteTool) {
            VStack(alignment: .leading, spacing: 20) {
                // Contract Header
                HStack {
                    if let contract = contract {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 6, height: 6)
                            Text(contract.name)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                        )
                    }
                    Spacer()
                }

                // Function Name
                VStack(alignment: .leading, spacing: 4) {
                    Text("Function")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(input.functionName)
                        .font(.system(size: 24, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary)
                }

                // Arguments
                if let args = input.args, !args.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Arguments")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(args.keys.sorted()), id: \.self) { key in
                                HStack(alignment: .top, spacing: 0) {
                                    Text(key)
                                        .foregroundStyle(.secondary)
                                        .font(.system(.caption, design: .monospaced))
                                    Text(": ")
                                        .foregroundStyle(.secondary)
                                        .font(.system(.caption, design: .monospaced))
                                    Text(args[key] ?? "")
                                        .foregroundStyle(.primary)
                                        .font(.system(.caption, design: .monospaced))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                    }
                }

                // Footer: Value & Action Button
                VStack(spacing: 16) {
                    HStack {
                        Text("Value: \(input.value ?? "0") ETH")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(Capsule())
                        Spacer()
                    }

                    if status == .waitingForResult && !isCallSuccessful {
                        switch effectiveCallState {
                        case .idle:
                            // Show Sign & Send button
                            HStack {
                                Spacer()
                                Button(action: handleExecute) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "paperplane.fill")
                                        Text("Sign & Send")
                                            .fontWeight(.medium)
                                    }
                                }
                            }

                        case .executing:
                            // Show executing progress
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Waiting for signature...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)

                        case .failed(let message):
                            // Show error with retry
                            VStack(spacing: 8) {
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .multilineTextAlignment(.center)
                                Button("Retry") {
                                    handleRetry()
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    } else if isCallSuccessful {
                        // Show success from registry
                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Sent")
                                    .fontWeight(.medium)
                            }
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.green)
                            .clipShape(Capsule())

                            if let txHash = registrySuccess {
                                Text(txHash)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        // Tool completed (from message status)
                        HStack(spacing: 6) {
                            Image(systemName: status == .completed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            Text(status == .completed ? "Sent" : "Rejected")
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(status == .completed ? Color.green : Color.red)
                        .clipShape(Capsule())
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(20)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .animation(.snappy, value: status)
    }

    // MARK: - Actions

    private func handleExecute() {
        Task {
            callState = .executing
            await onExecute()
            // After onExecute completes, transaction is queued
            // State will be updated via registry events
        }
    }

    private func handleRetry() {
        // Clear both local state and registry failure
        callState = .idle
        if let toolCallId {
            toolRegistry?.clearWriteCallFailure(toolCallId: toolCallId)
        }
    }
}

// MARK: - Preview

#Preview("Waiting for Result") {
    let container = try! ModelContainer(
        for: EVMContract.self, Endpoint.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let endpoint = Endpoint(name: "Local Testnet", url: "http://localhost:8545", chainId: "1")
    container.mainContext.insert(endpoint)

    let contract = EVMContract(
        name: "USDC Token",
        address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        status: .deployed,
        endpointId: endpoint.id
    )
    container.mainContext.insert(contract)

    let input = CallWriteInput.preview(
        contractId: contract.id.uuidString,
        functionName: "transfer",
        args: [
            "recipient": "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            "amount": "1000000000000000000"
        ],
        value: "0"
    )

    return CallWriteInputView(
        input: input,
        status: .waitingForResult
    ) {
        print("Execute button clicked")
        try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
    }
    .modelContainer(container)
    .frame(width: 400)
    .padding()
    .background(Color.black)
}

#Preview("Completed") {
    let container = try! ModelContainer(
        for: EVMContract.self, Endpoint.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let endpoint = Endpoint(name: "Local Testnet", url: "http://localhost:8545", chainId: "1")
    container.mainContext.insert(endpoint)

    let contract = EVMContract(
        name: "USDC Token",
        address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        status: .deployed,
        endpointId: endpoint.id
    )
    container.mainContext.insert(contract)

    let input = CallWriteInput.preview(
        contractId: contract.id.uuidString,
        functionName: "transfer",
        args: [
            "recipient": "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            "amount": "1000000000000000000"
        ],
        value: "0"
    )

    return CallWriteInputView(
        input: input,
        status: .completed
    ) {
        print("Execute button clicked")
    }
    .modelContainer(container)
    .frame(width: 400)
    .padding()
    .background(Color.black)
}
