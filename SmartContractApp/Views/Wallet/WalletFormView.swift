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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var alias: String = ""
    @State private var privateKeyInput: String = ""
    @State private var mnemonicWords: [String] = Array(repeating: "", count: 12)
    @State private var mnemonicWordCount: Int = 12
    @State private var derivedAddress: String = ""
    @State private var isGenerating: Bool = false

    // Validation states
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""

    // Mode
    private let creationMode: WalletCreationMode
    private let wallet: EVMWallet?
    private var isEditing: Bool { wallet != nil }

    init(creationMode: WalletCreationMode = .random, wallet: EVMWallet? = nil) {
        self.creationMode = creationMode
        self.wallet = wallet
        print("WalletFormView initialized in \(isEditing ? "edit" : "create") mode. Creation mode: \(creationMode)")
    }

    var body: some View {
        NavigationStack {
            Form {
                if isEditing {
                    // Edit mode: only allow changing alias
                    editModeSection
                } else {
                    // Create mode: show appropriate fields based on creation mode
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

    // MARK: - View Sections

    private var navigationTitle: String {
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

    private var editModeSection: some View {
        Section(header: Text("Wallet Details")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Wallet Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Enter wallet name", text: $alias)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            if let wallet = wallet {
                HStack {
                    Text("Address")
                    Spacer()
                    Text(wallet.address)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }

                HStack {
                    Text("Source")
                    Spacer()
                    Text(wallet.isFromMnemonic ? "Mnemonic" : "Private Key")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var createModeSection: some View {
        Section(header: Text("Wallet Details")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Wallet Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Enter wallet name", text: $alias)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }

        switch creationMode {
        case .random:
            randomWalletSection
        case .privateKey:
            privateKeySection
        case .mnemonic:
            mnemonicSection
        }

        if !derivedAddress.isEmpty {
            addressPreviewSection
        }
    }

    private var randomWalletSection: some View {
        Section(header: Text("Random Wallet")) {
            Text(
                "A new wallet will be generated with a secure 12-word mnemonic phrase. Both the mnemonic and derived private key will be stored in your device's keychain."
            )
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }

    private var privateKeySection: some View {
        Section(header: Text("Private Key")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Private Key (64 hex characters)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                SecureField("0x...", text: $privateKeyInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .fontDesign(.monospaced)
                #if os(iOS)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                #endif
                    .onChange(of: privateKeyInput) { _, newValue in
                        validateAndDeriveAddressFromPrivateKey(newValue)
                    }
            }

            Text("⚠️ Never share your private key with anyone. It will be stored securely in the keychain.")
                .font(.caption2)
                .foregroundColor(.orange)
        }
    }

    private var mnemonicSection: some View {
        Group {
            Section(header: Text("Mnemonic Words")) {
                Picker("Word Count", selection: $mnemonicWordCount) {
                    Text("12 words").tag(12)
                    Text("24 words").tag(24)
                }
                .pickerStyle(.segmented)
                .onChange(of: mnemonicWordCount) { oldValue, newValue in
                    if newValue != oldValue {
                        // Resize the array
                        mnemonicWords = Array(repeating: "", count: newValue)
                    }
                }
            }

            Section {
                ForEach(Array(mnemonicWords.enumerated()), id: \.offset) { index, _ in
                    HStack(spacing: 8) {
                        Text("\(index + 1).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 30, alignment: .trailing)

                        TextField("word", text: Binding(
                            get: { mnemonicWords[index] },
                            set: { newValue in
                                mnemonicWords[index] = newValue
                                validateAndDeriveAddressFromMnemonic()
                            }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        #if os(iOS)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        #endif
                    }
                }
            }

            Section {
                Text(
                    "⚠️ Never share your mnemonic phrase with anyone. Both the mnemonic and derived private key will be stored securely in the keychain."
                )
                .font(.caption2)
                .foregroundColor(.orange)
            }
        }
    }

    private var addressPreviewSection: some View {
        Section(header: Text("Derived Address")) {
            HStack {
                Text("Address:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(derivedAddress)
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
            }
        }
    }

    private func metadataSection(wallet: EVMWallet) -> some View {
        Section(header: Text("Metadata")) {
            HStack {
                Text("Created:")
                Spacer()
                Text(wallet.createdAt, style: .date)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Updated:")
                Spacer()
                Text(wallet.updatedAt, style: .date)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Validation

    private var isFormValid: Bool {
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
            let allWordsEntered = mnemonicWords.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            return hasAlias && allWordsEntered && !derivedAddress.isEmpty
        }
    }

    private func validateAndDeriveAddressFromPrivateKey(_ privateKey: String) {
        derivedAddress = ""

        let trimmed = privateKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            let signer = try PrivateKeySigner(hexPrivateKey: trimmed)
            derivedAddress = signer.address.value
        } catch {
            // Silently fail during typing
            derivedAddress = ""
        }
    }

    private func validateAndDeriveAddressFromMnemonic() {
        derivedAddress = ""

        // Check if all words are entered
        let words = mnemonicWords.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
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
            // Silently fail during typing
            derivedAddress = ""
        }
    }

    // MARK: - Data Management

    private func loadWallet(_ wallet: EVMWallet) {
        alias = wallet.alias
    }

    private func generateDefaultAlias() {
        // Query the wallet count from modelContext
        let descriptor = FetchDescriptor<EVMWallet>()
        let wallets = (try? modelContext.fetch(descriptor)) ?? []
        let count = wallets.count + 1
        alias = "Wallet \(count)"
    }

    private func saveWallet() {
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

    private func createWallet() async throws {
        let trimmedAlias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        let keychainPath = "wallet_\(UUID().uuidString)"

        var privateKey: String
        var mnemonic: String? = nil
        var address: String

        switch creationMode {
        case .random:
            // Generate random wallet with mnemonic
            // Generate a random 12-word BIP39 mnemonic
            let mnemonicObj = try Mnemonic.generate(wordCount: .twelve)

            // Store the mnemonic phrase
            mnemonic = mnemonicObj.phrase

            // Derive private key from mnemonic using Ethereum path
            privateKey = try mnemonicObj.privateKey(derivePath: .ethereum)

            // Derive address from private key
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

            // Store the phrase
            mnemonic = mnemonicObj.phrase

            // Derive private key
            privateKey = try mnemonicObj.privateKey(derivePath: .ethereum)

            // Derive address
            let signer = try PrivateKeySigner(hexPrivateKey: privateKey)
            address = signer.address.value
        }

        // Create wallet model
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
