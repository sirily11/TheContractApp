//
//  ContractFunctionsTabView.swift
//  SmartContractApp
//
//  Created by Claude on 11/17/25.
//

import SwiftData
import SwiftUI

/// Tab-based view for contract functions and history
/// Displays two tabs:
/// - Functions: List of ABI functions with Call buttons
/// - History: List of past function calls with results
struct ContractFunctionsTabView: View {
    let contract: EVMContract

    @Environment(\.modelContext) private var modelContext
    @Environment(WalletSignerViewModel.self) private var walletSigner
    @Environment(ContractInteractionViewModel.self) private var interactionViewModel

    @State private var selectedTab: FunctionTab = .functions

    enum FunctionTab: String, CaseIterable {
        case functions = "Functions"
        case history = "History"

        var systemImage: String {
            switch self {
            case .functions:
                return "function"
            case .history:
                return "clock"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Functions Tab
            FunctionListView(
                contract: contract,
            )
            .tabItem {
                Label(FunctionTab.functions.rawValue, systemImage: FunctionTab.functions.systemImage)
            }
            .tag(FunctionTab.functions)

            // History Tab
            FunctionHistoryView(
                contract: contract,
                viewModel: interactionViewModel
            )
            .tabItem {
                Label(FunctionTab.history.rawValue, systemImage: FunctionTab.history.systemImage)
            }
            .tag(FunctionTab.history)
        }
        .navigationTitle(contract.name)
        #if os(macOS)
            .navigationSubtitle(contract.address)
        #endif
    }
}

// MARK: - Preview

#Preview("Functions Tab") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: EVMContract.self, EvmAbi.self, Endpoint.self, EVMWallet.self,
        configurations: config
    )

    // Add sample data
    let endpoint = Endpoint(name: "Mainnet", url: "https://eth.llamarpc.com", chainId: "1")
    let abi = EvmAbi(
        name: "ERC20",
        abiContent: """
        [
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

    let walletSignerViewModel = WalletSignerViewModel(
        currentWallet: wallet
    )
    walletSignerViewModel.modelContext = container.mainContext

    let contractInteractionViewModel = ContractInteractionViewModel()
    contractInteractionViewModel.walletSigner = walletSignerViewModel

    return NavigationStack {
        ContractFunctionsTabView(contract: contract)
            .modelContainer(container)
            .environment(walletSignerViewModel)
            .environment(contractInteractionViewModel)
    }
}
