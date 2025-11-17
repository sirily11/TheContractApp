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

    @Query private var allHistory: [ContractFunctionCall]
    @State private var selectedFilter: String = "All"
    @State private var selection = Set<UUID>()
    @State private var sortOrder = [KeyPathComparator(\ContractFunctionCall.timestamp, order: .reverse)]
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false

    // MARK: - Initialization

    init(contract: EVMContract, viewModel: ContractInteractionViewModel) {
        self.contract = contract
        self.viewModel = viewModel

        // Configure query to fetch all history for this contract
        let contractId = contract.id
        _allHistory = Query(
            filter: #Predicate<ContractFunctionCall> { call in
                call.contractId == contractId
            },
            sort: [SortDescriptor(\.timestamp, order: .reverse)]
        )
    }

    var body: some View {
        Group {
            if filteredHistory.isEmpty {
                emptyStateView
            } else {
                historyTable
            }
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                filterMenu
            }
            if !selection.isEmpty {
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        deleteSelectedItems()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    // MARK: - History Table

    private var historyTable: some View {
        Table(filteredHistory, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Status") { call in
                HStack(spacing: 4) {
                    Image(systemName: statusIcon(for: call.status))
                        .foregroundColor(statusColor(for: call.status))
                        .font(.caption)
                    Text(call.status.rawValue.capitalized)
                        .font(.caption2)
                        .foregroundColor(statusColor(for: call.status))
                }
            }
            .width(min: 80, max: 100)

            TableColumn("Function", value: \.functionName)
                .width(min: 100, ideal: 150)

            TableColumn("Parameters") { call in
                Text(call.formattedParameters)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .width(min: 150, ideal: 250)

            TableColumn("Result") { call in
                if let result = call.result {
                    Text(result)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else if let error = call.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text("—")
                        .foregroundColor(.secondary)
                }
            }
            .width(min: 120, ideal: 200)

            TableColumn("Tx Hash") { call in
                if let hash = call.transactionHash {
                    Text(truncatedHash(hash))
                        .font(.caption)
                        .foregroundColor(.blue)
                } else {
                    Text("—")
                        .foregroundColor(.secondary)
                }
            }
            .width(min: 100, max: 120)

            TableColumn("Gas") { call in
                if let gas = call.gasUsed {
                    Text(gas)
                        .font(.caption)
                } else {
                    Text("—")
                        .foregroundColor(.secondary)
                }
            }
            .width(min: 60, max: 80)

            TableColumn("Time", value: \.timestamp) { call in
                Text(call.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .width(min: 80, max: 120)
        }
        .contextMenu(forSelectionType: UUID.self) { items in
            if items.isEmpty {
                // Context menu on empty area
                Button("Refresh") {
                    // SwiftData auto-refreshes, but we can force if needed
                }
            } else {
                // Context menu on selected items
                Button(role: .destructive) {
                    deleteItems(withIds: items)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
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
            return allHistory
        }
        return allHistory.filter { $0.functionName == selectedFilter }
    }

    /// Unique function names in history
    private var functionNames: [String] {
        Array(Set(allHistory.map { $0.functionName })).sorted()
    }

    // MARK: - Helper Methods

    /// Status icon for a given call status
    private func statusIcon(for status: CallStatus) -> String {
        switch status {
        case .pending:
            return "clock"
        case .success:
            return "checkmark.circle.fill"
        case .failed, .reverted:
            return "xmark.circle.fill"
        }
    }

    /// Status color for a given call status
    private func statusColor(for status: CallStatus) -> Color {
        switch status {
        case .pending:
            return .orange
        case .success:
            return .green
        case .failed, .reverted:
            return .red
        }
    }

    /// Truncate transaction hash for display
    private func truncatedHash(_ hash: String) -> String {
        guard hash.count > 10 else { return hash }
        let start = hash.prefix(6)
        let end = hash.suffix(4)
        return "\(start)...\(end)"
    }

    /// Delete selected items
    private func deleteSelectedItems() {
        deleteItems(withIds: selection)
        selection.removeAll()
    }

    /// Delete items with given IDs
    private func deleteItems(withIds ids: Set<UUID>) {
        let callsToDelete = allHistory.filter { ids.contains($0.id) }

        for call in callsToDelete {
            do {
                try viewModel.deleteFunctionCall(call)
            } catch {
                errorMessage = "Failed to delete history item: \(error.localizedDescription)"
                showingErrorAlert = true
            }
        }
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

    let walletSignerViewModel = WalletSignerViewModel(currentWallet: wallet)
    walletSignerViewModel.modelContext = container.mainContext

    let viewModel = ContractInteractionViewModel()
    viewModel.modelContext = container.mainContext
    viewModel.walletSigner = walletSignerViewModel

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

    let walletSignerViewModel = WalletSignerViewModel(currentWallet: wallet)
    walletSignerViewModel.modelContext = container.mainContext

    let viewModel = ContractInteractionViewModel()
    viewModel.modelContext = container.mainContext
    viewModel.walletSigner = walletSignerViewModel

    return NavigationStack {
        FunctionHistoryView(contract: contract, viewModel: viewModel)
            .modelContainer(container)
    }
}
