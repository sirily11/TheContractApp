//
//  FunctionListView.swift
//  SmartContractApp
//
//  Created by Claude on 11/17/25.
//

import EvmCore
import SwiftData
import SwiftUI

/// Displays a list of contract functions grouped by type (Read/Write)
/// Each function row shows the function signature and a Call button
struct FunctionListView: View {
    let contract: EVMContract

    @State private var functions: [AbiFunction] = []
    @State private var selectedFunction: AbiFunction?
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false

    @Environment(FunctionListViewModel.self) private var viewModel

    var body: some View {
        Group {
            if contract.abi == nil {
                emptyStateView(message: "No ABI available", systemImage: "doc.text.slash")
            } else if functions.isEmpty {
                emptyStateView(message: "No functions in ABI", systemImage: "function")
            } else {
                functionList
            }
        }
        .navigationTitle("Functions")
        .onAppear {
            loadFunctions()
        }
        .sheet(item: $selectedFunction) { function in
            FunctionCallSheet(
                contract: contract,
                function: function,
            )
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    // MARK: - Function List

    private var functionList: some View {
        List {
            // Read Functions Section
            if !readFunctions.isEmpty {
                Section {
                    ForEach(readFunctions, id: \.name) { function in
                        FunctionRowView(
                            contract: contract,
                            function: function,
                            onCallTapped: {
                                handleFunctionCall(function)
                            },
                            isExecuting: viewModel.isExecuting(function.name)
                        )
                    }
                } header: {
                    HStack {
                        Image(systemName: "book")
                        Text("Read Functions")
                    }
                }
            }

            // Write Functions Section
            if !writeFunctions.isEmpty {
                Section {
                    ForEach(writeFunctions, id: \.name) { function in
                        FunctionRowView(
                            contract: contract,
                            function: function,
                            onCallTapped: {
                                handleFunctionCall(function)
                            }
                        )
                    }
                } header: {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Write Functions")
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private func emptyStateView(message: String, systemImage: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Add an ABI to interact with contract functions")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Computed Properties

    /// Read functions (view and pure)
    private var readFunctions: [AbiFunction] {
        functions.filter { function in
            function.stateMutability == .view || function.stateMutability == .pure
        }
    }

    /// Write functions (nonpayable and payable)
    private var writeFunctions: [AbiFunction] {
        functions.filter { function in
            function.stateMutability == .nonpayable || function.stateMutability == .payable
        }
    }

    // MARK: - Helper Methods

    /// Handle function call - auto-execute if read-only with no params, otherwise show sheet
    private func handleFunctionCall(_ function: AbiFunction) {
        if viewModel.shouldAutoExecute(function) {
            // Auto-execute read-only functions with no parameters
            Task { @MainActor in
                await viewModel.executeReadFunction(contract: contract, function: function)
            }
        } else {
            // Show sheet for functions with parameters or write functions
            selectedFunction = function
        }
    }

    /// Load functions from contract ABI
    private func loadFunctions() {
        guard let abi = contract.abi else {
            functions = []
            return
        }

        do {
            let parser = try AbiParser(fromJsonString: abi.abiContent)
            functions = parser.items.compactMap { item in
                guard item.type == .function else { return nil }
                return try? AbiFunction.from(item: item)
            }
        } catch {
            errorMessage = "Failed to parse ABI: \(error.localizedDescription)"
            showingErrorAlert = true
            functions = []
        }
    }
}

// MARK: - Preview

#Preview("With Functions") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: EVMContract.self, EvmAbi.self, Endpoint.self, EVMWallet.self,
        configurations: config
    )

    let endpoint = Endpoint(name: "Mainnet", url: "https://eth.llamarpc.com", chainId: "1")
    let abi = EvmAbi(
        name: "ERC20",
        abiContent: """
        [
            {
                "constant": true,
                "inputs": [],
                "name": "name",
                "outputs": [{"name": "", "type": "string"}],
                "stateMutability": "view",
                "type": "function"
            },
            {
                "constant": true,
                "inputs": [{"name": "account", "type": "address"}],
                "name": "balanceOf",
                "outputs": [{"name": "", "type": "uint256"}],
                "stateMutability": "view",
                "type": "function"
            },
            {
                "constant": false,
                "inputs": [
                    {"name": "recipient", "type": "address"},
                    {"name": "amount", "type": "uint256"}
                ],
                "name": "transfer",
                "outputs": [{"name": "", "type": "bool"}],
                "stateMutability": "nonpayable",
                "type": "function"
            },
            {
                "constant": false,
                "inputs": [
                    {"name": "spender", "type": "address"},
                    {"name": "amount", "type": "uint256"}
                ],
                "name": "approve",
                "outputs": [{"name": "", "type": "bool"}],
                "stateMutability": "nonpayable",
                "type": "function"
            }
        ]
        """
    )
    let contract = EVMContract(
        name: "USDC",
        address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        status: .deployed,
        endpointId: endpoint.id
    )
    contract.abi = abi
    contract.endpoint = endpoint

    let wallet = EVMWallet(alias: "Test Wallet", address: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb", keychainPath: "preview-wallet")

    container.mainContext.insert(endpoint)
    container.mainContext.insert(abi)
    container.mainContext.insert(contract)
    container.mainContext.insert(wallet)

    let walletSignerViewModel = WalletSignerViewModel(currentWallet: wallet)
    walletSignerViewModel.modelContext = container.mainContext

    let viewModel = ContractInteractionViewModel()
    viewModel.modelContext = container.mainContext
    viewModel.walletSigner = walletSignerViewModel

    return NavigationStack {
        FunctionListView(contract: contract)
            .modelContainer(container)
            .environment(walletSignerViewModel)
            .environment(viewModel)
    }
}

#Preview("No ABI") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: EVMContract.self, EvmAbi.self, Endpoint.self, EVMWallet.self,
        configurations: config
    )

    let endpoint = Endpoint(name: "Mainnet", url: "https://eth.llamarpc.com", chainId: "1")
    let contract = EVMContract(
        name: "Unknown Contract",
        address: "0x0000000000000000000000000000000000000000",
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
        FunctionListView(contract: contract)
            .modelContainer(container)
            .environment(walletSignerViewModel)
            .environment(viewModel)
    }
}
