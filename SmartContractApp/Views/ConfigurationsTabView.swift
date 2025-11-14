//
//  ConfigurationsTabView.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/12/25.
//

import SwiftData
import SwiftUI

enum ConfigurationCategory: String, CaseIterable, Hashable, Identifiable {
    case endpoints
    case abi
    case wallet

    var id: String { rawValue }

    var title: String {
        switch self {
        case .endpoints: return "Endpoints"
        case .abi: return "ABI"
        case .wallet: return "Wallet"
        }
    }

    var systemImage: String {
        switch self {
        case .endpoints: return "network"
        case .abi: return "doc.text"
        case .wallet: return "wallet.bifold"
        }
    }
}

struct ConfigurationsTabView: View {
    @State private var selectedCategory: ConfigurationCategory?
    @State private var selectedEndpoint: Endpoint?
    @State private var selectedAbi: EvmAbi?
    @State private var selectedWallet: EVMWallet?

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(ConfigurationCategory.allCases, selection: $selectedCategory) { category in
                NavigationLink(value: category) {
                    Label(category.title, systemImage: category.systemImage)
                }
            }
            .navigationTitle("Configurations")
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } content: {
            // Content
            if let selectedCategory = selectedCategory {
                switch selectedCategory {
                case .endpoints:
                    EndpointContentView(selectedEndpoint: $selectedEndpoint)
                case .abi:
                    AbiContentView(selectedAbi: $selectedAbi)
                case .wallet:
                    WalletContentView(selectedWallet: $selectedWallet)
                }
            } else {
                ContentUnavailableView(
                    "Select Configuration",
                    systemImage: "sidebar.left",
                    description: Text("Choose a configuration category from the sidebar.")
                )
            }
        } detail: {
            // Detail
            if let selectedEndpoint = selectedEndpoint {
                EndpointDetailView(endpoint: selectedEndpoint)
                    .navigationDestination(for: EVMContract.self) { contract in
                        ContractDetailView(contract: contract)
                    }
            } else if let selectedAbi = selectedAbi {
                AbiDetailView(abi: selectedAbi)
                    .navigationDestination(for: EVMContract.self) { contract in
                        ContractDetailView(contract: contract)
                    }
            } else if let selectedWallet = selectedWallet {
                WalletDetailView(wallet: selectedWallet)
            } else if selectedCategory != nil {
                ContentUnavailableView(
                    "No Selection",
                    systemImage: "doc",
                    description: Text("Select an item to view its details.")
                )
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "gearshape.2")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)

                    Text("Configurations")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Select a configuration category from the sidebar")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .onChange(of: selectedCategory) { _, _ in
            // Clear all item selections when category changes
            selectedEndpoint = nil
            selectedAbi = nil
            selectedWallet = nil
        }
        .onChange(of: selectedEndpoint) { _, newValue in
            // Clear other selections when endpoint is selected
            if newValue != nil {
                selectedAbi = nil
                selectedWallet = nil
            }
        }
        .onChange(of: selectedAbi) { _, newValue in
            // Clear other selections when ABI is selected
            if newValue != nil {
                selectedEndpoint = nil
                selectedWallet = nil
            }
        }
        .onChange(of: selectedWallet) { _, newValue in
            // Clear other selections when wallet is selected
            if newValue != nil {
                selectedEndpoint = nil
                selectedAbi = nil
            }
        }
    }
}

#Preview {
    ConfigurationsTabView()
        .modelContainer(for: [Endpoint.self, EvmAbi.self, EVMWallet.self], inMemory: true)
}
