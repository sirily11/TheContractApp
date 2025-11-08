//
//  WalletFormView+Validation.swift
//  SmartContractApp
//
//  Created by Claude Code
//

import EvmCore
import Foundation

// MARK: - Validation

extension WalletFormView {

    /// Validates whether the form is ready for submission
    var isFormValid: Bool {
        let hasAlias = !alias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if isEditing {
            return hasAlias
        }

        switch creationMode {
        case .random:
            return hasAlias
        case .privateKey:
            return hasAlias && !privateKeyInput.isEmpty && !derivedAddress.isEmpty
        case .mnemonic:
            let allWordsEntered = mnemonicWords.allSatisfy {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return hasAlias && allWordsEntered && !derivedAddress.isEmpty
        }
    }

    /// Validates private key input and derives the corresponding address
    /// - Parameter privateKey: The private key string to validate
    func validateAndDeriveAddressFromPrivateKey(_ privateKey: String) {
        derivedAddress = ""

        let trimmed = privateKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            let signer = try PrivateKeySigner(hexPrivateKey: trimmed)
            derivedAddress = signer.address.value
        } catch {
            // Silently fail during typing to allow users to complete input
            derivedAddress = ""
        }
    }

    /// Validates mnemonic phrase input and derives the corresponding address
    func validateAndDeriveAddressFromMnemonic() {
        derivedAddress = ""

        // Check if all words are entered
        let words = mnemonicWords.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        guard words.allSatisfy({ !$0.isEmpty }) else { return }

        do {
            // Try to create mnemonic (without checksum validation for real-time validation)
            let mnemonic = try Mnemonic(words: words, validateChecksum: false)

            // Derive private key
            let privateKey = try mnemonic.privateKey(derivePath: .ethereum)

            // Derive address
            let signer = try PrivateKeySigner(hexPrivateKey: privateKey)
            derivedAddress = signer.address.value
        } catch {
            // Silently fail during typing to allow users to complete input
            derivedAddress = ""
        }
    }
}
