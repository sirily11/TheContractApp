//
//  WalletContentView.swift
//  SmartContractApp
//
//  Created by Claude Code
//

import SwiftData
import SwiftUI

enum WalletCreationMode: Identifiable {
    case random
    case privateKey
    case mnemonic

    var id: Self { self }
}

struct WalletContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EVMWallet.createdAt, order: .reverse) private var wallets: [EVMWallet]
    @Binding var selectedWallet: EVMWallet?

    @State private var creationMode: WalletCreationMode?
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var walletToDelete: EVMWallet?

    var body: some View {
        List(wallets, selection: $selectedWallet) { wallet in
            NavigationLink(value: wallet) {
                WalletRowView(wallet: wallet)
            }
            .contextMenu {
                Button("Edit") {
                    selectedWallet = wallet
                    showingEditSheet = true
                }

                Divider()

                Button("Delete", role: .destructive) {
                    walletToDelete = wallet
                    showingDeleteAlert = true
                }
            }
        }
        .navigationTitle("Wallets")
        .navigationSplitViewColumnWidth(min: 300, ideal: 350)
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                walletCreationMenu
            }
            #else
            ToolbarItem(placement: .primaryAction) {
                walletCreationMenu
            }
            #endif
        }
        .sheet(item: $creationMode) { mode in
            WalletFormView(creationMode: mode)
        }
        .sheet(isPresented: $showingEditSheet) {
            if let wallet = selectedWallet {
                WalletFormView(wallet: wallet)
            } else {
                Text("No wallet selected")
            }
        }
        .alert("Delete Wallet", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let wallet = walletToDelete {
                    deleteWallet(wallet)
                }
            }
            Button("Cancel", role: .cancel) {
                walletToDelete = nil
            }
        } message: {
            if let wallet = walletToDelete {
                Text(
                    "Are you sure you want to delete '\(wallet.alias)'? This will also remove all associated keys from the keychain. This action cannot be undone."
                )
            }
        }
    }

    private var walletCreationMenu: some View {
        Menu {
            Button(action: {
                creationMode = .random
            }) {
                Label("Create Random Wallet", systemImage: "dice")
            }

            Button(action: {
                creationMode = .privateKey
            }) {
                Label("Import from Private Key", systemImage: "key")
            }

            Button(action: {
                creationMode = .mnemonic
            }) {
                Label("Import from Mnemonic", systemImage: "list.bullet.rectangle")
            }
        } label: {
            Image(systemName: "plus")
        }
    }

    private func deleteWallet(_ wallet: EVMWallet) {
        // First delete from keychain
        do {
            try wallet.deleteFromKeychain()
        } catch {
            print("Warning: Failed to delete wallet from keychain: \(error.localizedDescription)")
            // Continue with deletion even if keychain fails
        }

        // Then delete from SwiftData
        withAnimation {
            modelContext.delete(wallet)
            try? modelContext.save()
        }
        walletToDelete = nil

        // Clear selection if deleted wallet was selected
        if selectedWallet == wallet {
            selectedWallet = nil
        }
    }
}
