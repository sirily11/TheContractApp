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

    // MARK: - SwiftData

    @Environment(\.modelContext) private var modelContext
    @Query private var endpoints: [Endpoint]

    // MARK: - Callback

    let onDeploy: () async -> Void

    // MARK: - State

    @State private var isDeploying: Bool = false
    @State private var showingSourceCode: Bool = false

    // MARK: - Computed Properties

    private var endpoint: Endpoint? {
        guard let endpointId = deployInput.endpointId else { return nil }
        return endpoints.first { $0.id.uuidString == endpointId }
    }

    // MARK: - Initializer

    init(
        deployInput: DeployInput,
        status: ToolStatus = .waitingForResult,
        onDeploy: @escaping () async -> Void
    ) {
        self.deployInput = deployInput
        self.status = status
        self.onDeploy = onDeploy
    }

    // MARK: - Body

    var body: some View {
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
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .glassEffect()
                }

                Spacer()

                if deployInput.sourceCode != nil {
                    Button(action: { showingSourceCode = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .font(.caption2)
                            Text("View Source")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
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
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
            }

            // Footer: Cost & Deploy Button
            VStack(spacing: 16) {
                HStack {
                    Text("Value: \(deployInput.value ?? "0") ETH")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                if status == .waitingForResult {
                    HStack {
                        Spacer()
                        Button(action: handleDeploy) {
                            HStack {
                                if isDeploying {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(.black)
                                } else {
                                    Image(systemName: "checkmark.shield.fill")
                                }
                                Text(isDeploying ? "Deploying..." : "Sign & Deploy")
                            }
                        }
                        .disabled(isDeploying)
                    }
                } else {
                    HStack {
                        Image(systemName: status == .completed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        Text(status == .completed ? "Deployed" : "Rejected")
                    }
                    .font(.subheadline)
                    .foregroundStyle(status == .completed ? .green : .red)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
                }
            }
        }
        .padding(24)
        .glassEffect(in: .rect(cornerRadius: 20))
        .animation(.snappy, value: status)
        .animation(.snappy, value: isDeploying)
        .sheet(isPresented: $showingSourceCode) {
            if let sourceCode = deployInput.sourceCode {
                SourceCodeSheet(sourceCode: sourceCode)
            }
        }
    }

    // MARK: - Actions

    private func handleDeploy() {
        isDeploying = true
        Task {
            await onDeploy()
            isDeploying = false
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
        NavigationStack {
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
        .frame(minWidth: 600, minHeight: 500)
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
