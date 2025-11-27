//
//  WalletFormView.swift
//  SmartContractApp
//
//  Created by Claude Code
//

import EvmCore
import SwiftData
import SwiftUI

struct WalletFormView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss

    // MARK: - Form State

    @State var alias: String = ""
    @State var privateKeyInput: String = ""
    @State var mnemonicWords: [String] = Array(repeating: "", count: 12)
    @State var mnemonicWordCount: Int = 12
    @State var derivedAddress: String = ""
    @State var isGenerating: Bool = false

    // MARK: - Validation States

    @State var showingValidationAlert = false
    @State var validationMessage = ""
    @State var showingErrorAlert = false
    @State var errorMessage = ""

    // MARK: - Mode

    let creationMode: WalletCreationMode
    let wallet: EVMWallet?

    var isEditing: Bool { wallet != nil }

    init(creationMode: WalletCreationMode = .random, wallet: EVMWallet? = nil) {
        self.creationMode = creationMode
        self.wallet = wallet
        print("WalletFormView initialized in \(isEditing ? "edit" : "create") mode. Creation mode: \(creationMode)")
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                if isEditing {
                    editModeSection
                } else {
                    createModeSection
                }

                if isEditing, let wallet = wallet {
                    metadataSection(wallet: wallet)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(navigationTitle)
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    #if os(iOS)
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                dismiss()
                            }
                        }

                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(isEditing ? "Update" : "Create") {
                                saveWallet()
                            }
                            .disabled(!isFormValid || isGenerating)
                            .accessibilityIdentifier(isEditing ? .wallet.updateButton : .wallet.createButton)
                        }
                    #else
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                dismiss()
                            }
                        }

                        ToolbarItem(placement: .primaryAction) {
                            Button(isEditing ? "Update" : "Create") {
                                saveWallet()
                            }
                            .disabled(!isFormValid || isGenerating)
                            .accessibilityIdentifier(isEditing ? .wallet.updateButton : .wallet.createButton)
                        }
                    #endif
                }
                .onAppear {
                    if let wallet = wallet {
                        loadWallet(wallet)
                    } else {
                        generateDefaultAlias()
                    }
                }
                .alert("Validation Error", isPresented: $showingValidationAlert) {
                    Button("OK") {}
                } message: {
                    Text(validationMessage)
                }
                .alert("Error", isPresented: $showingErrorAlert) {
                    Button("OK") {}
                } message: {
                    Text(errorMessage)
                }
        }
    }

    // MARK: - Computed Properties

    var navigationTitle: String {
        if isEditing {
            return "Edit Wallet"
        }
        switch creationMode {
        case .random:
            return "Create Random Wallet"
        case .privateKey:
            return "Import from Private Key"
        case .mnemonic:
            return "Import from Mnemonic"
        }
    }
}

// MARK: - Previews

#Preview("Random Wallet") {
    WalletFormView(creationMode: .random)
        .modelContainer(for: EVMWallet.self, inMemory: true)
}

#Preview("Import Private Key") {
    WalletFormView(creationMode: .privateKey)
        .modelContainer(for: EVMWallet.self, inMemory: true)
}

#Preview("Import Mnemonic") {
    WalletFormView(creationMode: .mnemonic)
        .modelContainer(for: EVMWallet.self, inMemory: true)
}

#Preview("Edit Wallet") {
    let wallet = EVMWallet(
        alias: "My Wallet",
        address: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
        keychainPath: "wallet_preview",
        isFromMnemonic: true
    )

    return WalletFormView(wallet: wallet)
        .modelContainer(for: EVMWallet.self, inMemory: true)
}
