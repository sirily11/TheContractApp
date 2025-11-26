//
//  CallReadInputView.swift
//  SmartContractApp
//
//  Created on 11/26/25.
//

import Agent
import AgentLayout
import SwiftData
import SwiftUI

/// UI component for displaying read function call inputs and results
struct CallReadInputView: View {
    // MARK: - Input Properties

    let input: CallReadInput
    let status: ToolStatus
    let resultMessage: OpenAIToolMessage?

    // MARK: - SwiftData

    @Environment(\.modelContext) private var modelContext
    @Query private var contracts: [EVMContract]

    // MARK: - Computed Properties

    private var contract: EVMContract? {
        guard let contractId = UUID(uuidString: input.contractId) else { return nil }
        return contracts.first { $0.id == contractId }
    }

    /// Parse the result from the tool message
    private var callResult: CallReadOutput? {
        guard let content = resultMessage?.content else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(CallReadOutput.self, from: content.data(using: .utf8) ?? Data())
    }

    // MARK: - Body

    var body: some View {
        ToolCallCard(toolName: CallTools.nameReadTool) {
            VStack(alignment: .leading, spacing: 20) {
                // Contract and Function Header
                HStack {
                    if let contract = contract {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.blue)
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

                // Result Section
                resultSection
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

    // MARK: - Result Section

    @ViewBuilder
    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Result")
                .font(.caption)
                .foregroundStyle(.secondary)

            if status == .waitingForResult {
                // Still executing
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Executing...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if let result = callResult {
                if result.success {
                    // Success result
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Success")
                                .fontWeight(.medium)
                                .foregroundStyle(.green)
                        }
                        .font(.caption)

                        if let resultValue = result.result {
                            Text(resultValue)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.green.opacity(0.2), lineWidth: 1)
                    )
                } else {
                    // Error result
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                            Text("Failed")
                                .fontWeight(.medium)
                                .foregroundStyle(.red)
                        }
                        .font(.caption)

                        Text(result.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.red.opacity(0.2), lineWidth: 1)
                    )
                }
            } else {
                // No result yet or parsing failed
                Text("No result available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

// MARK: - Preview

#Preview("Executing") {
    let container = try! ModelContainer(
        for: EVMContract.self, Endpoint.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let endpoint = Endpoint(name: "Local", url: "http://localhost:8545", chainId: "1")
    container.mainContext.insert(endpoint)

    let contract = EVMContract(
        name: "USDC Token",
        address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        status: .deployed,
        endpointId: endpoint.id
    )
    container.mainContext.insert(contract)

    let input = CallReadInput.preview(
        contractId: contract.id.uuidString,
        functionName: "balanceOf",
        args: ["account": "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"]
    )

    return CallReadInputView(
        input: input,
        status: .waitingForResult,
        resultMessage: nil
    )
    .modelContainer(container)
    .frame(width: 400)
    .padding()
    .background(Color.black)
}
