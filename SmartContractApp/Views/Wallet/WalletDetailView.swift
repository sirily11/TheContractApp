//
//  WalletDetailView.swift
//  SmartContractApp
//
//  Created by Claude Code
//

import LocalAuthentication
import SwiftData
import SwiftUI

struct WalletDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let wallet: EVMWallet

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingPrivateKey = false
    @State private var showingMnemonic = false
    @State private var privateKey: String?
    @State private var mnemonic: String?
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var copiedToClipboard = false

    init(wallet: EVMWallet) {
        self.wallet = wallet
        print("Wallet: \(wallet.isFromMnemonic)")
    }

    var body: some View {
        Form {
            walletInfoSection

            securitySection

            metadataSection
        }
        .formStyle(.grouped)
        .navigationTitle(wallet.alias)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                #if os(iOS)
                    ToolbarItem(placement: .navigationBarTrailing) {
                        walletMenu
                    }
                #else
                    ToolbarItem(placement: .primaryAction) {
                        walletMenu
                    }
                #endif
            }
            .sheet(isPresented: $showingEditSheet) {
                WalletFormView(wallet: wallet)
            }
            .alert("Delete Wallet", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    deleteWallet()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "Are you sure you want to delete '\(wallet.alias)'? This will also remove all associated keys from the keychain. This action cannot be undone."
                )
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .overlay(alignment: .top) {
                if copiedToClipboard {
                    Text("Copied to clipboard")
                        .font(.caption)
                        .padding(8)
                        .background(Color.green.opacity(0.9))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 50)
                }
            }
    }

    // MARK: - View Sections

    private var walletInfoSection: some View {
        Section(header: Text("Wallet Information")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Address")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Text(wallet.address)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)

                    Spacer()

                    Button(action: {
                        copyToClipboard(wallet.address)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }

            HStack {
                Text("Source")
                Spacer()
                HStack(spacing: 4) {
                    if wallet.isFromMnemonic {
                        Image(systemName: "list.bullet.rectangle.fill")
                            .font(.caption)
                        Text("Mnemonic")
                    } else {
                        Image(systemName: "key.fill")
                            .font(.caption)
                        Text("Private Key")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
    }

    private var securitySection: some View {
        Section(header: Text("Security")) {
            // Private Key
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Private Key")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button(showingPrivateKey ? "Hide" : "Show") {
                        togglePrivateKeyVisibility()
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }

                if showingPrivateKey, let privateKey = privateKey {
                    HStack {
                        Text(privateKey)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.orange)
                            .textSelection(.enabled)
                            .lineLimit(nil)

                        Spacer()

                        Button(action: {
                            copyToClipboard(privateKey)
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                } else if showingPrivateKey {
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }

            // Mnemonic (if available)
            if wallet.isFromMnemonic {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Mnemonic Phrase")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button(showingMnemonic ? "Hide" : "Show") {
                            toggleMnemonicVisibility()
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                    }

                    if showingMnemonic, let mnemonic = mnemonic {
                        HStack {
                            Text(mnemonic)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.orange)
                                .textSelection(.enabled)
                                .lineLimit(nil)

                            Spacer()

                            Button(action: {
                                copyToClipboard(mnemonic)
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    } else if showingMnemonic {
                        Text("Loading...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            }

            Text("⚠️ Never share your private key or mnemonic phrase with anyone.")
                .font(.caption2)
                .foregroundColor(.orange)
        }
    }

    private var metadataSection: some View {
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

    private var walletMenu: some View {
        Menu {
            Button(action: {
                showingEditSheet = true
            }) {
                Label("Edit", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive, action: {
                showingDeleteAlert = true
            }) {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    // MARK: - Actions

    private func togglePrivateKeyVisibility() {
        if showingPrivateKey {
            showingPrivateKey = false
            privateKey = nil
        } else {
            authenticateAndLoadPrivateKey()
        }
    }

    private func toggleMnemonicVisibility() {
        if showingMnemonic {
            showingMnemonic = false
            mnemonic = nil
        } else {
            authenticateAndLoadMnemonic()
        }
    }

    private func authenticateAndLoadPrivateKey() {
        authenticate { success in
            if success {
                loadPrivateKey()
            }
        }
    }

    private func authenticateAndLoadMnemonic() {
        authenticate { success in
            if success {
                loadMnemonic()
            }
        }
    }

    private func authenticate(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?

        // Check if biometric authentication is available
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Authenticate to view sensitive wallet information"

            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        completion(true)
                    } else {
                        // Authentication failed
                        self.errorMessage = authenticationError?.localizedDescription ?? "Authentication failed"
                        self.showingErrorAlert = true
                        completion(false)
                    }
                }
            }
        } else {
            // Biometrics not available, fall back to device passcode
            if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                let reason = "Authenticate to view sensitive wallet information"

                context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authenticationError in
                    DispatchQueue.main.async {
                        if success {
                            completion(true)
                        } else {
                            self.errorMessage = authenticationError?.localizedDescription ?? "Authentication failed"
                            self.showingErrorAlert = true
                            completion(false)
                        }
                    }
                }
            } else {
                // No authentication available
                DispatchQueue.main.async {
                    self.errorMessage = "No authentication method available on this device"
                    self.showingErrorAlert = true
                    completion(false)
                }
            }
        }
    }

    private func loadPrivateKey() {
        do {
            privateKey = try wallet.getPrivateKey()
            showingPrivateKey = true
        } catch {
            errorMessage = "Failed to load private key: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }

    private func loadMnemonic() {
        do {
            mnemonic = try wallet.getMnemonic()
            showingMnemonic = true
        } catch {
            errorMessage = "Failed to load mnemonic: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }

    private func copyToClipboard(_ text: String) {
        #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        #else
            UIPasteboard.general.string = text
        #endif

        // Show copied confirmation
        withAnimation {
            copiedToClipboard = true
        }

        // Hide after 2 seconds
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                withAnimation {
                    copiedToClipboard = false
                }
            }
        }
    }

    private func deleteWallet() {
        // Delete from keychain
        do {
            try wallet.deleteFromKeychain()
        } catch {
            print("Warning: Failed to delete wallet from keychain: \(error.localizedDescription)")
        }

        // Delete from SwiftData
        modelContext.delete(wallet)
        try? modelContext.save()

        // Navigation will automatically pop since the wallet is deleted
    }
}

#Preview {
    let wallet = EVMWallet(
        alias: "My Main Wallet",
        address: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
        keychainPath: "wallet_preview",
        isFromMnemonic: true
    )

    return NavigationStack {
        WalletDetailView(wallet: wallet)
    }
    .modelContainer(for: EVMWallet.self, inMemory: true)
}
