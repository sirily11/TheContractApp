//
//  FunctionRowView.swift
//  SmartContractApp
//
//  Created by Claude on 11/17/25.
//

import EvmCore
import SwiftData
import SwiftUI

/// Displays a single function with Call button and last result
/// Shows function signature, state mutability badge, and Call button on the right
struct FunctionRowView: View {
    let contract: EVMContract
    let function: AbiFunction
    let onCallTapped: () -> Void
    var isExecuting: Bool = false

    @Query(sort: \ContractFunctionCall.timestamp, order: .reverse) private var allCalls: [ContractFunctionCall]
    @Environment(ContractInteractionViewModel.self) private var viewModel
    @State private var showingDetailPopover = false

    /// Last successful call for this function (auto-updates via SwiftData)
    private var lastCall: ContractFunctionCall? {
        allCalls.first { call in
            call.contractId == contract.id &&
                call.functionName == function.name &&
                call.status == .success
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Function signature and Call button
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    // Function name and badge
                    HStack(spacing: 8) {
                        Text(function.name)
                            .font(.headline)
                            .foregroundColor(.primary)

                        stateMutabilityBadge

                        Button {
                            showingDetailPopover.toggle()
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showingDetailPopover) {
                            functionDetailPopover
                        }
                    }
                }

                Spacer()

                // Call button
                Button(action: onCallTapped) {
                    HStack(spacing: 4) {
                        if isExecuting {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Call")
                    }
                }
                .buttonStyle(.bordered)
                .tint(buttonColor)
                .disabled(isExecuting)
                .accessibilityIdentifier("contract-call-button")
            }

            // Last result (if available)
            if let lastCall = lastCall, let result = lastCall.result {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Result:")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    HStack {
                        labeledResultView(result: result)

                        Spacer()

                        RelativeTimeView(date: lastCall.timestamp)
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Computed Properties

    /// State mutability badge
    private var stateMutabilityBadge: some View {
        Text(badgeText)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.2))
            .foregroundColor(badgeColor)
            .cornerRadius(4)
    }

    /// Badge text based on state mutability
    private var badgeText: String {
        switch function.stateMutability {
        case .view, .pure:
            return "Read"
        case .nonpayable:
            return "Write"
        case .payable:
            return "Payable"
        }
    }

    /// Badge color based on state mutability
    private var badgeColor: Color {
        switch function.stateMutability {
        case .view, .pure:
            return .green
        case .nonpayable:
            return .orange
        case .payable:
            return .red
        }
    }

    /// Button color based on state mutability
    private var buttonColor: Color {
        switch function.stateMutability {
        case .view, .pure:
            return .blue
        case .nonpayable, .payable:
            return .orange
        }
    }

    /// Function signature showing parameter types
    private var functionSignature: String {
        let paramTypes = function.inputs.map { param in
            if param.name.isEmpty {
                return param.type
            } else {
                return "\(param.type) \(param.name)"
            }
        }
        return "(\(paramTypes.joined(separator: ", ")))"
    }

    /// Return type signature showing output types
    private var returnTypeSignature: String? {
        guard !function.outputs.isEmpty else { return nil }

        if function.outputs.count == 1 {
            let output = function.outputs[0]
            if output.name.isEmpty {
                return output.type
            } else {
                return "\(output.type) \(output.name)"
            }
        } else {
            let outputTypes = function.outputs.map { output in
                if output.name.isEmpty {
                    return output.type
                } else {
                    return "\(output.type) \(output.name)"
                }
            }
            return "(\(outputTypes.joined(separator: ", ")))"
        }
    }

    // MARK: - Labeled Result View

    @ViewBuilder
    private func labeledResultView(result: String) -> some View {
        let outputs = function.outputs

        if outputs.isEmpty {
            // No output definition, just show raw result
            Text(result)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(2)
        } else if outputs.count == 1 {
            // Single output - show with label
            let output = outputs[0]
            HStack(spacing: 4) {
                if !output.name.isEmpty {
                    Text("\(output.name):")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Text(result)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
        } else {
            // Multiple outputs - show compact
            let values = parseResultArray(result)
            HStack(spacing: 6) {
                ForEach(Array(outputs.enumerated()), id: \.offset) { index, output in
                    if index > 0 {
                        Text("·")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 2) {
                        if !output.name.isEmpty {
                            Text("\(output.name):")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Text(index < values.count ? values[index] : "—")
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    /// Parse a result string that might be an array like "[val1, val2, val3]"
    private func parseResultArray(_ result: String) -> [String] {
        let trimmed = result.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
            let inner = String(trimmed.dropFirst().dropLast())
            return inner.components(separatedBy: ", ").map {
                $0.trimmingCharacters(in: .whitespaces)
            }
        }

        return [result]
    }

    // MARK: - Detail Popover

    private var functionDetailPopover: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text(function.name)
                    .font(.headline)
                Spacer()
                stateMutabilityBadge
            }

            Divider()

            // Inputs section
            VStack(alignment: .leading, spacing: 8) {
                Text("Inputs")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                if function.inputs.isEmpty {
                    Text("No inputs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(Array(function.inputs.enumerated()), id: \.offset) { _, input in
                        HStack {
                            Text(input.name.isEmpty ? "(unnamed)" : input.name)
                                .font(.body)
                            Spacer()
                            Text(input.type)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }

            Divider()

            // Outputs section
            VStack(alignment: .leading, spacing: 8) {
                Text("Outputs")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                if function.outputs.isEmpty {
                    Text("No outputs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(Array(function.outputs.enumerated()), id: \.offset) { _, output in
                        HStack {
                            Text(output.name.isEmpty ? "(unnamed)" : output.name)
                                .font(.body)
                            Spacer()
                            Text(output.type)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 280)
    }
}

// MARK: - Preview

#Preview("Read Function") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: EVMContract.self, EvmAbi.self, Endpoint.self, EVMWallet.self, ContractFunctionCall.self,
        configurations: config
    )

    let endpoint = Endpoint(name: "Mainnet", url: "https://eth.llamarpc.com", chainId: "1")
    let contract = EVMContract(
        name: "USDC",
        address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        status: .deployed,
        endpointId: endpoint.id
    )
    contract.endpoint = endpoint

    let wallet = EVMWallet(alias: "Test Wallet", address: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb", keychainPath: "preview-wallet")

    // Create function call history
    let params = [
        TransactionParameter(
            name: "account",
            type: .address,
            value: .init("0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")
        )
    ]
    let paramsData = try! JSONEncoder().encode(params)
    let functionCall = ContractFunctionCall(
        functionName: "balanceOf",
        parameters: paramsData,
        result: "1000000000", // 1 USDC (6 decimals)
        rawResult: "0x3b9aca00",
        status: .success,
        contractId: contract.id,
        contract: contract
    )

    container.mainContext.insert(endpoint)
    container.mainContext.insert(contract)
    container.mainContext.insert(wallet)
    container.mainContext.insert(functionCall)

    let walletSignerViewModel = WalletSignerViewModel(currentWallet: wallet)
    walletSignerViewModel.modelContext = container.mainContext

    let viewModel = ContractInteractionViewModel()
    viewModel.modelContext = container.mainContext
    viewModel.walletSigner = walletSignerViewModel

    let function = AbiFunction(
        name: "balanceOf",
        inputs: [
            AbiParameter(name: "account", type: "address")
        ],
        outputs: [
            AbiParameter(name: "", type: "uint256")
        ],
        stateMutability: .view
    )

    return FunctionRowView(
        contract: contract,
        function: function,
        onCallTapped: {}
    )
    .modelContainer(container)
    .padding()
}

#Preview("Write Function") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: EVMContract.self, EvmAbi.self, Endpoint.self, EVMWallet.self,
        configurations: config
    )

    let endpoint = Endpoint(name: "Mainnet", url: "https://eth.llamarpc.com", chainId: "1")
    let contract = EVMContract(
        name: "USDC",
        address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        status: .deployed,
        endpointId: endpoint.id
    )
    contract.endpoint = endpoint

    let wallet = EVMWallet(alias: "Test Wallet", address: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb", keychainPath: "preview-wallet")

    container.mainContext.insert(endpoint)
    container.mainContext.insert(contract)
    container.mainContext.insert(wallet)

    let walletSignerViewModel = WalletSignerViewModel(currentWallet: wallet)
    walletSignerViewModel.modelContext = container.mainContext

    let viewModel = ContractInteractionViewModel()
    viewModel.modelContext = container.mainContext
    viewModel.walletSigner = walletSignerViewModel

    let function = AbiFunction(
        name: "transfer",
        inputs: [
            AbiParameter(name: "recipient", type: "address"),
            AbiParameter(name: "amount", type: "uint256")
        ],
        outputs: [
            AbiParameter(name: "", type: "bool")
        ],
        stateMutability: .nonpayable
    )

    return FunctionRowView(
        contract: contract,
        function: function,
        onCallTapped: {}
    )
    .modelContainer(container)
    .padding()
}
