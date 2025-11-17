//
//  FunctionHistoryView.swift
//  SmartContractApp
//
//  Created by Claude on 11/17/25.
//

import SwiftData
import SwiftUI

/// Displays function call history for a contract
/// Shows past calls with parameters, results, and timestamps
struct FunctionHistoryView: View {
    let contract: EVMContract
    let viewModel: ContractInteractionViewModel

    @State private var history: [ContractFunctionCall] = []
    @State private var selectedFilter: String = "All"
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false

    var body: some View {
        Group {
            if history.isEmpty {
                emptyStateView
            } else {
                historyList
            }
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                filterMenu
            }
        }
        .onAppear {
            loadHistory()
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    // MARK: - History List

    private var historyList: some View {
        List {
            ForEach(filteredHistory) { call in
                FunctionHistoryRowView(functionCall: call)
            }
            .onDelete(perform: deleteHistoryItems)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No Function Calls Yet")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Function call history will appear here")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Filter Menu

    private var filterMenu: some View {
        Menu {
            Button("All Functions") {
                selectedFilter = "All"
            }

            if !functionNames.isEmpty {
                Divider()

                ForEach(functionNames, id: \.self) { functionName in
                    Button(functionName) {
                        selectedFilter = functionName
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: "line.3.horizontal.decrease.circle")
                Text(selectedFilter)
            }
        }
    }

    // MARK: - Computed Properties

    /// Filtered history based on selected filter
    private var filteredHistory: [ContractFunctionCall] {
        if selectedFilter == "All" {
            return history
        }
        return history.filter { $0.functionName == selectedFilter }
    }

    /// Unique function names in history
    private var functionNames: [String] {
        Array(Set(history.map { $0.functionName })).sorted()
    }

    // MARK: - Helper Methods

    /// Load function call history from database
    private func loadHistory() {
        do {
            history = try viewModel.loadFunctionHistory(for: contract)
        } catch {
            errorMessage = "Failed to load history: \(error.localizedDescription)"
            showingErrorAlert = true
            history = []
        }
    }

    /// Delete history items at the specified offsets
    private func deleteHistoryItems(at offsets: IndexSet) {
        let callsToDelete = offsets.map { filteredHistory[$0] }

        for call in callsToDelete {
            do {
                try viewModel.deleteFunctionCall(call)
            } catch {
                errorMessage = "Failed to delete history item: \(error.localizedDescription)"
                showingErrorAlert = true
            }
        }

        // Reload history
        loadHistory()
    }
}

// MARK: - Preview

#Preview("With History") {
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

    // Add sample function calls
    let call1 = ContractFunctionCall.sampleReadCall
    call1.contract = contract
    let call2 = ContractFunctionCall.sampleWriteCall
    call2.contract = contract
    let call3 = ContractFunctionCall.sampleFailedCall
    call3.contract = contract

    container.mainContext.insert(endpoint)
    container.mainContext.insert(contract)
    container.mainContext.insert(wallet)
    container.mainContext.insert(call1)
    container.mainContext.insert(call2)
    container.mainContext.insert(call3)

    let walletSignerViewModel = WalletSignerViewModel(
        modelContext: container.mainContext,
        currentWallet: wallet
    )

    let viewModel = ContractInteractionViewModel(
        modelContext: container.mainContext,
        walletSigner: walletSignerViewModel
    )

    return NavigationStack {
        FunctionHistoryView(contract: contract, viewModel: viewModel)
            .modelContainer(container)
    }
}

#Preview("Empty") {
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

    container.mainContext.insert(endpoint)
    container.mainContext.insert(contract)
    container.mainContext.insert(wallet)

    let walletSignerViewModel = WalletSignerViewModel(
        modelContext: container.mainContext,
        currentWallet: wallet
    )

    let viewModel = ContractInteractionViewModel(
        modelContext: container.mainContext,
        walletSigner: walletSignerViewModel
    )

    return NavigationStack {
        FunctionHistoryView(contract: contract, viewModel: viewModel)
            .modelContainer(container)
    }
}
