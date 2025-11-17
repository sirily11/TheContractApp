//
//  SmartContractAppApp.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/5/25.
//

import SwiftData
import SwiftUI

@main
struct SmartContractAppApp: App {
    @State private var windowStateManager = WindowStateManager()
    @State private var walletSignerViewModel = WalletSignerViewModel()
    @State private var contractInteractionViewModel = ContractInteractionViewModel()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Endpoint.self,
            EVMContract.self,
            EvmAbi.self,
            EVMWallet.self,
            Transaction.self,
            ContractFunctionCall.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If migration fails, try to delete and recreate the store
            print("⚠️ ModelContainer creation failed: \(error)")
            print("🔄 Attempting to reset database...")

            // Get the default store URL
            let url = URL.applicationSupportDirectory.appending(path: "default.store")

            // Try to delete the old database file
            if FileManager.default.fileExists(atPath: url.path()) {
                do {
                    try FileManager.default.removeItem(at: url)
                    print("✅ Old database deleted, creating new one...")
                } catch {
                    print("❌ Failed to delete old database: \(error)")
                }
            }

            // Try again to create the container
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer even after reset: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentViewWrapper()
                .environment(windowStateManager)
                .environment(walletSignerViewModel)
                .environment(contractInteractionViewModel)
        }
        .modelContainer(sharedModelContainer)

        #if os(macOS)
        WindowGroup(id: "signing-wallet") {
            SigningWalletWindowWrapper()
                .containerBackground(.thinMaterial, for: .window)
                .environment(walletSignerViewModel)
                .environment(contractInteractionViewModel)
                .environment(windowStateManager)
        }
        .modelContainer(sharedModelContainer)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 400, height: 700)
        #endif
    }
}

/// Wrapper to pass shared dependencies to ContentView
private struct ContentViewWrapper: View {
    @Environment(\.modelContext) var modelContext
    @Environment(WalletSignerViewModel.self) var walletSignerViewModel
    @Environment(ContractInteractionViewModel.self) var contractInteractionViewModel

    // MARK: - AppStorage for Centralized Selection

    @AppStorage("selectedEndpointId") private var selectedEndpointIdString: String = ""
    @AppStorage("selectedWalletId") private var selectedWalletIdString: String = ""

    var body: some View {
        ContentView()
            .onAppear {
                walletSignerViewModel.modelContext = modelContext
                contractInteractionViewModel.modelContext = modelContext
                contractInteractionViewModel.walletSigner = walletSignerViewModel

                // Initialize wallet selection from AppStorage
                initializeWalletSelection()
            }
            .onChange(of: selectedWalletIdString) { _, newValue in
                updateWalletSelection(newValue)
            }
            .onChange(of: selectedEndpointIdString) { _, newValue in
                validateEndpointSelection(newValue)
            }
    }

    // MARK: - Selection Management

    /// Initialize wallet selection from AppStorage on app launch
    private func initializeWalletSelection() {
        // Query all wallets
        let walletDescriptor = FetchDescriptor<EVMWallet>(sortBy: [SortDescriptor(\EVMWallet.alias)])
        guard let wallets = try? modelContext.fetch(walletDescriptor) else { return }

        // Try to find the stored wallet
        if let storedWalletId = UUID(uuidString: selectedWalletIdString),
           let selectedWallet = wallets.first(where: { $0.id == storedWalletId })
        {
            // Valid stored wallet found
            walletSignerViewModel.setSelectedWallet(selectedWallet)
        } else if let firstWallet = wallets.first {
            // No valid stored wallet, use first available
            walletSignerViewModel.setSelectedWallet(firstWallet)
            selectedWalletIdString = firstWallet.id.uuidString
        } else {
            // No wallets available
            walletSignerViewModel.setSelectedWallet(nil)
            selectedWalletIdString = ""
        }

        // Validate endpoint selection
        validateEndpointSelection(selectedEndpointIdString)
    }

    /// Update wallet selection when AppStorage changes
    private func updateWalletSelection(_ newWalletIdString: String) {
        let walletDescriptor = FetchDescriptor<EVMWallet>(sortBy: [SortDescriptor(\EVMWallet.alias)])
        guard let wallets = try? modelContext.fetch(walletDescriptor) else { return }

        if let newWalletId = UUID(uuidString: newWalletIdString),
           let newWallet = wallets.first(where: { $0.id == newWalletId })
        {
            // Valid wallet ID
            walletSignerViewModel.setSelectedWallet(newWallet)
        } else if let firstWallet = wallets.first {
            // Invalid ID, fallback to first wallet
            walletSignerViewModel.setSelectedWallet(firstWallet)
            selectedWalletIdString = firstWallet.id.uuidString
        } else {
            // No wallets available
            walletSignerViewModel.setSelectedWallet(nil)
            selectedWalletIdString = ""
        }
    }

    /// Validate endpoint selection and fallback to first if invalid
    private func validateEndpointSelection(_ endpointIdString: String) {
        let endpointDescriptor = FetchDescriptor<Endpoint>(sortBy: [SortDescriptor(\Endpoint.name)])
        guard let endpoints = try? modelContext.fetch(endpointDescriptor) else { return }

        // Check if current selection is valid
        if let currentId = UUID(uuidString: endpointIdString),
           endpoints.first(where: { $0.id == currentId }) != nil
        {
            // Valid selection, no action needed
            return
        }

        // Invalid selection, fallback to first endpoint
        if let firstEndpoint = endpoints.first {
            selectedEndpointIdString = firstEndpoint.id.uuidString
        } else {
            selectedEndpointIdString = ""
        }
    }
}

/// Wrapper for the signing wallet window
private struct SigningWalletWindowWrapper: View {
    @Environment(\.modelContext) var modelContext
    @Environment(WalletSignerViewModel.self) var walletSignerViewModel
    @Environment(WindowStateManager.self) var windowStateManager

    var body: some View {
        SigningWalletView()
            .frame(minWidth: 400, minHeight: 700)
            .onAppear {
                walletSignerViewModel.modelContext = modelContext
                windowStateManager.isSigningWalletWindowOpen = true
            }
            .onDisappear {
                windowStateManager.isSigningWalletWindowOpen = false
            }
    }
}
