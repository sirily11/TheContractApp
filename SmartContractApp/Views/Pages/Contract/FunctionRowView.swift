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

    @State private var lastCall: ContractFunctionCall?
    @Environment(ContractInteractionViewModel.self) private var viewModel

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
                    }

                    // Function signature (parameter types)
                    if !function.inputs.isEmpty {
                        Text(functionSignature)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                // Call button
                Button("Call", action: onCallTapped)
                    .buttonStyle(.bordered)
                    .tint(buttonColor)
            }

            // Last result (if available)
            if let lastCall = lastCall, let result = lastCall.result {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Result:")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    HStack {
                        Text(result)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(2)

                        Spacer()

                        Text(lastCall.timestamp, style: .relative)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            loadLastCall()
        }
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

    // MARK: - Helper Methods

    /// Load the last successful call for this function
    private func loadLastCall() {
        do {
            lastCall = try viewModel.getLastSuccessfulCall(
                for: contract,
                functionName: function.name
            )
        } catch {
            // Silently fail - no last call available
            lastCall = nil
        }
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
