//
//  DeployInputView.swift
//  SmartContractApp
//
//  Created on 11/25/25.
//

import AgentLayout
import SwiftData
import SwiftUI

struct DeployInputView: View {
    // MARK: - Input Properties

    let deployInput: DeployInput
    let status: ToolStatus
    let toolCallId: String?
    let toolRegistry: ToolRegistry?

    // MARK: - SwiftData

    @Environment(\.modelContext) private var modelContext
    @Query private var endpoints: [Endpoint]

    // MARK: - Callback

    let onDeploy: () async -> Void

    // MARK: - State

    @State private var deploymentState: LocalDeploymentState = .idle
    @State private var showingSourceCode: Bool = false

    /// Local deployment state for UI display
    enum LocalDeploymentState: Equatable {
        case idle
        case compiling
        case deploying
        case failed(String)
    }

    /// Check if there's a failure from the registry (e.g., user rejection)
    private var registryFailure: String? {
        guard let toolCallId, let registry = toolRegistry else { return nil }
        return registry.deploymentFailures[toolCallId]
    }

    /// Check if deployment succeeded from the registry
    private var registrySuccess: String? {
        guard let toolCallId, let registry = toolRegistry else { return nil }
        return registry.deploymentSuccesses[toolCallId]
    }

    /// Combined deployment state - local state OR registry failure/success
    private var effectiveDeploymentState: LocalDeploymentState {
        if let failure = registryFailure {
            return .failed(failure)
        }
        return deploymentState
    }

    /// Whether deployment has completed successfully (from registry)
    private var isDeploymentSuccessful: Bool {
        registrySuccess != nil
    }

    // MARK: - Computed Properties

    private var endpoint: Endpoint? {
        guard let endpointId = deployInput.endpointId else { return nil }
        return endpoints.first { $0.id.uuidString == endpointId }
    }

    // MARK: - Initializer

    init(
        deployInput: DeployInput,
        status: ToolStatus = .waitingForResult,
        toolCallId: String? = nil,
        toolRegistry: ToolRegistry? = nil,
        onDeploy: @escaping () async -> Void
    ) {
        self.deployInput = deployInput
        self.status = status
        self.toolCallId = toolCallId
        self.toolRegistry = toolRegistry
        self.onDeploy = onDeploy
    }

    // MARK: - Body

    var body: some View {
        ToolCallCard(toolName: DeployTools.name) {
            // Contract deployment details
            VStack(alignment: .leading, spacing: 20) {
                // Top Header: Endpoint & View Source
                HStack {
                    if let endpoint = endpoint {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text(endpoint.name)
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

                    if deployInput.sourceCode != nil {
                        Button(action: { showingSourceCode = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left.forwardslash.chevron.right")
                                    .font(.caption2)
                                Text("View Source")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.primary.opacity(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(0.1))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Title Section
                VStack(alignment: .leading, spacing: 4) {
                    Text("Contract Name")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(deployInput.name ?? "Unknown Contract")
                        .font(.system(size: 36, weight: .regular))
                        .foregroundStyle(.primary)
                }

                // Constructor Arguments
                if let args = deployInput.constructorArgs, !args.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Constructor Arguments")
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

                // Footer: Cost & Deploy Button
                VStack(spacing: 16) {
                    HStack {
                        Text("Value: \(deployInput.value ?? "0") ETH")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(Capsule())
                        Spacer()
                    }

                    if status == .waitingForResult && !isDeploymentSuccessful {
                        switch effectiveDeploymentState {
                        case .idle:
                            // Show Sign & Deploy button
                            HStack {
                                Spacer()
                                Button(action: handleDeploy) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.shield.fill")
                                        Text("Sign & Deploy")
                                            .fontWeight(.medium)
                                    }
                                }
                            }

                        case .compiling:
                            // Show compiling progress
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Compiling...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)

                        case .deploying:
                            // Show deploying progress
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Deploying... Please approve in wallet")
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
                    } else if isDeploymentSuccessful {
                        // Show success from registry
                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Deployed")
                                    .fontWeight(.medium)
                            }
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.green)
                            .clipShape(Capsule())

                            if let contractAddress = registrySuccess {
                                Text(contractAddress)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: status == .completed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            Text(status == .completed ? "Deployed" : "Rejected")
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
        .sheet(isPresented: $showingSourceCode) {
            if let sourceCode = deployInput.sourceCode {
                SourceCodeSheet(sourceCode: sourceCode)
            }
        }
    }

    // MARK: - Actions

    private func handleDeploy() {
        Task {
            deploymentState = .compiling
            await onDeploy()
            // After onDeploy completes, transaction is queued
            // Only update to deploying if not already failed
            if case .compiling = deploymentState {
                deploymentState = .deploying
            }
        }
    }

    private func handleRetry() {
        // Clear both local state and registry failure
        deploymentState = .idle
        if let toolCallId {
            toolRegistry?.clearDeploymentFailure(toolCallId: toolCallId)
        }
    }
}

// MARK: - Source Code Sheet

private struct SourceCodeSheet: View {
    let sourceCode: String
    @State private var content: String
    @Environment(\.dismiss) private var dismiss

    init(sourceCode: String) {
        self.sourceCode = sourceCode
        self._content = State(initialValue: sourceCode)
    }

    var body: some View {
        ScrollView {
            SolidityView(content: $content, readonly: true, noCompile: true)
                .frame(minWidth: 500, minHeight: 400)
                .navigationTitle("Source Code")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
        }
    }
}

// MARK: - Preview

#Preview("Waiting for Result") {
    let container = try! ModelContainer(for: Endpoint.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))

    // Create a sample endpoint for preview
    let endpoint = Endpoint(
        name: "Local Testnet",
        url: "http://localhost:8545",
        chainId: "1"
    )
    container.mainContext.insert(endpoint)

    let sampleInput = DeployInput(
        sourceCode: """
        // SPDX-License-Identifier: MIT
        pragma solidity ^0.8.0;

        contract SimpleStorage {
            uint256 private value;
            address public owner;

            constructor(uint256 initialValue, address _owner) {
                value = initialValue;
                owner = _owner;
            }

            function setValue(uint256 _value) public {
                value = _value;
            }

            function getValue() public view returns (uint256) {
                return value;
            }
        }
        """,
        constructorArgs: ["initialValue": "100", "owner": "0x123..."],
        endpointId: endpoint.id.uuidString,
        name: "HelloWorld"
    )

    return DeployInputView(
        deployInput: sampleInput,
        status: .waitingForResult
    ) {
        print("Deploy button clicked")
        try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
    }
    .modelContainer(container)
    .frame(width: 400)
    .padding()
    .background(Color.black)
}

#Preview("Completed") {
    let container = try! ModelContainer(for: Endpoint.self, configurations: .init(isStoredInMemoryOnly: true))

    let endpoint = Endpoint(
        name: "Local Testnet",
        url: "http://localhost:8545",
        chainId: "1"
    )
    container.mainContext.insert(endpoint)

    let sampleInput = DeployInput(
        constructorArgs: ["initialValue": "100", "owner": "0x123..."],
        endpointId: endpoint.id.uuidString,
        name: "HelloWorld"
    )

    return DeployInputView(
        deployInput: sampleInput,
        status: .completed
    ) {
        print("Deploy button clicked")
    }
    .modelContainer(container)
    .frame(width: 400)
    .padding()
    .background(Color.black)
}
