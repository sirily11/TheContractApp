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
    @State private var walletSignerViewModel: WalletSignerViewModel?
    @State private var contractInteractionViewModel: ContractInteractionViewModel?

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
            ContentViewWrapper(
                modelContext: sharedModelContainer.mainContext,
                windowStateManager: windowStateManager,
                walletSignerViewModel: getOrCreateWalletSignerViewModel(),
                contractInteractionViewModel: getOrCreateContractInteractionViewModel()
            )
        }
        .modelContainer(sharedModelContainer)

        #if os(macOS)
        WindowGroup(id: "signing-wallet") {
            SigningWalletWindowWrapper(
                windowStateManager: windowStateManager,
                walletSignerViewModel: getOrCreateWalletSignerViewModel()
            )
            .containerBackground(.thinMaterial, for: .window)
        }
        .modelContainer(sharedModelContainer)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 400, height: 700)
        #endif
    }

    private func getOrCreateWalletSignerViewModel() -> WalletSignerViewModel {
        if let viewModel = walletSignerViewModel {
            return viewModel
        }
        let viewModel = WalletSignerViewModel(modelContext: sharedModelContainer.mainContext)
        walletSignerViewModel = viewModel
        return viewModel
    }

    private func getOrCreateContractInteractionViewModel() -> ContractInteractionViewModel {
        if let viewModel = contractInteractionViewModel {
            return viewModel
        }
        let walletSigner = getOrCreateWalletSignerViewModel()
        let viewModel = ContractInteractionViewModel(
            modelContext: sharedModelContainer.mainContext,
            walletSigner: walletSigner
        )
        contractInteractionViewModel = viewModel
        return viewModel
    }
}

/// Wrapper to pass shared dependencies to ContentView
private struct ContentViewWrapper: View {
    let modelContext: ModelContext
    let windowStateManager: WindowStateManager
    let walletSignerViewModel: WalletSignerViewModel
    let contractInteractionViewModel: ContractInteractionViewModel

    var body: some View {
        ContentView()
            .environment(walletSignerViewModel)
            .environment(contractInteractionViewModel)
            .environment(windowStateManager)
    }
}

/// Wrapper for the signing wallet window
private struct SigningWalletWindowWrapper: View {
    let windowStateManager: WindowStateManager
    let walletSignerViewModel: WalletSignerViewModel

    var body: some View {
        SigningWalletView()
            .environment(walletSignerViewModel)
            .frame(minWidth: 400, minHeight: 700)
            .onAppear {
                windowStateManager.isSigningWalletWindowOpen = true
            }
            .onDisappear {
                windowStateManager.isSigningWalletWindowOpen = false
            }
    }
}
