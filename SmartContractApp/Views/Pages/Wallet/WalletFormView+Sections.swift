//
//  WalletFormView+Sections.swift
//  SmartContractApp
//
//  Created by Claude Code
//

import SwiftUI

// MARK: - View Sections

extension WalletFormView {

    // MARK: - Edit Mode Section

    var editModeSection: some View {
        Section(header: Text("Wallet Details")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Wallet Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Enter wallet name", text: $alias)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .accessibilityIdentifier(.wallet.aliasTextField)
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

    // MARK: - Create Mode Section

    @ViewBuilder
    var createModeSection: some View {
        Section(header: Text("Wallet Details")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Wallet Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Enter wallet name", text: $alias)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .accessibilityIdentifier(.wallet.aliasTextField)
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

    // MARK: - Random Wallet Section

    var randomWalletSection: some View {
        Section(header: Text("Random Wallet")) {
            Text(
                "A new wallet will be generated with a secure 12-word mnemonic phrase. Both the mnemonic and derived private key will be stored in your device's keychain."
            )
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }

    // MARK: - Private Key Section

    var privateKeySection: some View {
        Section(header: Text("Private Key")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Private Key (64 hex characters)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                SecureField("0x...", text: $privateKeyInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .fontDesign(.monospaced)
                    .accessibilityIdentifier(.wallet.privateKeyField)
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

    // MARK: - Mnemonic Section

    var mnemonicSection: some View {
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

    // MARK: - Address Preview Section

    var addressPreviewSection: some View {
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

    // MARK: - Metadata Section

    func metadataSection(wallet: EVMWallet) -> some View {
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
}
