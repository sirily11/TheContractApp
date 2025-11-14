//
//  WalletFormView+DataManagement.swift
//  SmartContractApp
//
//  Created by Claude Code
//

import EvmCore
import Foundation
import SwiftData
import SwiftUI

// MARK: - Data Management

extension WalletFormView {

    /// Loads an existing wallet's data into the form
    /// - Parameter wallet: The wallet to load
    func loadWallet(_ wallet: EVMWallet) {
        alias = wallet.alias
    }

    /// Generates a default alias for a new wallet based on existing wallet count
    func generateDefaultAlias() {
        let descriptor = FetchDescriptor<EVMWallet>()
        let wallets = (try? modelContext.fetch(descriptor)) ?? []
        let count = wallets.count + 1
        alias = "Wallet \(count)"
    }

    /// Saves the wallet (creates new or updates existing)
    func saveWallet() {
        // Prevent double submission
        guard !isGenerating else { return }
        isGenerating = true

        Task {
            do {
                if isEditing {
                    try await updateWallet()
                } else {
                    try await createWallet()
                }
                await MainActor.run {
                    isGenerating = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    errorMessage = error.localizedDescription
                    showingErrorAlert = true
                }
            }
        }
    }

    /// Updates an existing wallet in the database
    private func updateWallet() async throws {
        guard let existingWallet = wallet else { return }

        await MainActor.run {
            existingWallet.alias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
            existingWallet.updatedAt = Date()

            do {
                try modelContext.save()
            } catch {
                errorMessage = "Failed to update wallet: \(error.localizedDescription)"
                showingErrorAlert = true
            }
        }
    }

    /// Creates a new wallet and saves it to the database
    private func createWallet() async throws {
        let trimmedAlias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        let keychainPath = "wallet_\(UUID().uuidString)"

        var privateKey: String
        var mnemonic: String? = nil
        var address: String

        switch creationMode {
        case .random:
            // Generate random wallet with mnemonic
            let mnemonicObj = try Mnemonic.generate(wordCount: .twelve)
            mnemonic = mnemonicObj.phrase
            privateKey = try mnemonicObj.privateKey(derivePath: .ethereum)
            let signer = try PrivateKeySigner(hexPrivateKey: privateKey)
            address = signer.address.value

        case .privateKey:
            // Import from private key
            let trimmedPrivateKey = privateKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
            let signer = try PrivateKeySigner(hexPrivateKey: trimmedPrivateKey)
            privateKey = trimmedPrivateKey
            address = signer.address.value

        case .mnemonic:
            // Import from mnemonic
            let words = mnemonicWords.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }

            // Validate mnemonic (with checksum validation)
            let mnemonicObj = try Mnemonic(words: words, validateChecksum: true)
            mnemonic = mnemonicObj.phrase
            privateKey = try mnemonicObj.privateKey(derivePath: .ethereum)
            let signer = try PrivateKeySigner(hexPrivateKey: privateKey)
            address = signer.address.value
        }

        // Create wallet model (UUID is auto-generated)
        let newWallet = EVMWallet(
            alias: trimmedAlias,
            address: address,
            keychainPath: keychainPath,
            isFromMnemonic: mnemonic != nil
        )

        // Store private key in keychain
        try newWallet.setPrivateKey(privateKey)

        // Store mnemonic if present
        if let mnemonic = mnemonic {
            try newWallet.setMnemonic(mnemonic)
        }

        // Save to SwiftData
        do {
            await MainActor.run {
                modelContext.insert(newWallet)
            }

            try await MainActor.run {
                try modelContext.save()
            }
        } catch {
            // If save fails, clean up keychain
            try? newWallet.deleteFromKeychain()
            throw error
        }
    }
}
