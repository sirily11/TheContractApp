//
//  ContentView.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/5/25.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WalletSignerViewModel.self) private var walletSigner
    @Environment(WindowStateManager.self) private var windowStateManager
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    #endif
    @State private var selectedCategory: SidebarCategory?
    @State private var selectedEndpoint: Endpoint?
    @State private var selectedAbi: EvmAbi?
    @State private var selectedContract: EVMContract?
    @State private var selectedWallet: EVMWallet?
    @State private var showingQueuedTransactions = false

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(SidebarCategory.allCases, selection: $selectedCategory) { category in
                NavigationLink(value: category) {
                    Label(category.title, systemImage: category.systemImage)
                }
            }
            .navigationTitle("Smart Contract App")
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } content: {
            // Content
            if let selectedCategory = selectedCategory {
                switch selectedCategory {
                case .endpoints:
                    EndpointContentView(selectedEndpoint: $selectedEndpoint)
                case .abi:
                    AbiContentView(selectedAbi: $selectedAbi)
                case .contract:
                    ContractContentView(selectedContract: $selectedContract)
                case .wallet:
                    WalletContentView(selectedWallet: $selectedWallet)
                }
            } else {
                ContentUnavailableView(
                    "Select Category",
                    systemImage: "sidebar.left",
                    description: Text("Choose a category from the sidebar to view its contents.")
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
            } else if let selectedContract = selectedContract {
                ContractDetailView(contract: selectedContract)
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
                    Image(systemName: "network")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)

                    Text("Welcome to Smart Contract App")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Select a category from the sidebar to get started")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    #if os(macOS)
                    toggleSigningWalletWindow()
                    #else
                    showingQueuedTransactions = true
                    #endif
                } label: {
                    walletToolbarButton
                }
                .help("Pending Transactions")
            }
        }
        #if os(iOS)
        .sheet(isPresented: $showingQueuedTransactions) {
            NavigationStack {
                SigningWalletView()
            }
        }
        #endif
        .onChange(of: selectedCategory) { _, _ in
            // Clear all item selections when category changes
            selectedEndpoint = nil
            selectedAbi = nil
            selectedContract = nil
            selectedWallet = nil
        }
        .onChange(of: selectedEndpoint) { _, newValue in
            // Clear other selections when endpoint is selected
            if newValue != nil {
                selectedAbi = nil
                selectedContract = nil
                selectedWallet = nil
            }
        }
        .onChange(of: selectedAbi) { _, newValue in
            // Clear other selections when ABI is selected
            if newValue != nil {
                selectedEndpoint = nil
                selectedContract = nil
                selectedWallet = nil
            }
        }
        .onChange(of: selectedContract) { _, newValue in
            // Clear other selections when contract is selected
            if newValue != nil {
                selectedEndpoint = nil
                selectedAbi = nil
                selectedWallet = nil
            }
        }
        .onChange(of: selectedWallet) { _, newValue in
            // Clear other selections when wallet is selected
            if newValue != nil {
                selectedEndpoint = nil
                selectedAbi = nil
                selectedContract = nil
            }
        }
    }

    // MARK: - Actions

    #if os(macOS)
    private func toggleSigningWalletWindow() {
        if windowStateManager.isSigningWalletWindowOpen {
            dismissWindow(id: "signing-wallet")
        } else {
            openWindow(id: "signing-wallet")
        }
    }
    #endif

    // MARK: - Toolbar Button

    @ViewBuilder
    private var walletToolbarButton: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "wallet.pass")
                .font(.title3)
                .imageScale(.medium)

            if walletSigner.pendingTransactionCount > 0 {
                ZStack {
                    Circle()
                        .fill(.red)
                        .frame(width: 18, height: 18)

                    Text("\(min(walletSigner.pendingTransactionCount, 99))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .offset(x: 8, y: -8)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Endpoint.self, EVMContract.self, EvmAbi.self, EVMWallet.self], inMemory: true)
}
