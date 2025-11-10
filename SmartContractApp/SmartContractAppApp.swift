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
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Endpoint.self,
            EVMContract.self,
            EvmAbi.self,
            EVMWallet.self,
            Transaction.self,
            QueuedTransaction.self,
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

    @State private var walletSignerViewModel: WalletSignerViewModel?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.walletSigner, walletSignerViewModel)
                .onAppear {
                    if walletSignerViewModel == nil {
                        walletSignerViewModel = WalletSignerViewModel(
                            modelContext: sharedModelContainer.mainContext
                        )
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
