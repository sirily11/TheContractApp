//
//  WalletHeaderView.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import SwiftUI

/// Header view displaying wallet address and balance
struct WalletHeaderView: View {
    // MARK: - Properties

    let wallets: [EVMWallet]
    @Binding var selectedWalletId: Int
    let balance: String // in ETH

    @State private var showCopied = false

    // MARK: - Computed Properties

    private var selectedWallet: EVMWallet? {
        wallets.first { $0.id == selectedWalletId } ?? wallets.first
    }

    private var address: String {
        selectedWallet?.address ?? "No wallet selected"
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            // Wallet avatar (GitHub-style identicon)
            WalletAvatarView(
                address: address,
                size: 64
            )

            // Combined wallet picker and address display
            if !wallets.isEmpty {
                HStack(spacing: 8) {
                    // Wallet dropdown
                    Menu {
                        ForEach(wallets, id: \.id) { wallet in
                            Button(action: {
                                selectedWalletId = wallet.id
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(wallet.alias)
                                        Text(TransactionFormatter.truncateAddress(wallet.address))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    if wallet.id == selectedWalletId {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(selectedWallet?.alias ?? "Select Wallet")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Text(TransactionFormatter.truncateAddress(address))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)

                    // Copy button
                    Button(action: copyAddress) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("Copy address")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }

            // Balance
            VStack(spacing: 4) {
                Text(balance)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("Available Balance")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func copyAddress() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(address, forType: .string)
        #else
        UIPasteboard.general.string = address
        #endif

        // Show checkmark animation
        withAnimation {
            showCopied = true
        }

        // Reset after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopied = false
            }
        }
    }
}

// MARK: - Preview

#Preview("With Balance") {
    @Previewable @State var selectedId = 1
    let wallets = [
        EVMWallet(id: 1, alias: "Main Wallet", address: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb", keychainPath: "preview1"),
        EVMWallet(id: 2, alias: "Secondary", address: "0x1234567890abcdef1234567890abcdef12345678", keychainPath: "preview2")
    ]

    WalletHeaderView(
        wallets: wallets,
        selectedWalletId: $selectedId,
        balance: "12.5 ETH"
    )
    .frame(width: 400)
}

#Preview("Zero Balance") {
    @Previewable @State var selectedId = 1
    let wallets = [
        EVMWallet(id: 1, alias: "Empty Wallet", address: "0x1234567890abcdef1234567890abcdef12345678", keychainPath: "preview1")
    ]

    WalletHeaderView(
        wallets: wallets,
        selectedWalletId: $selectedId,
        balance: "0 ETH"
    )
    .frame(width: 400)
}

#Preview("Large Balance") {
    @Previewable @State var selectedId = 1
    let wallets = [
        EVMWallet(id: 1, alias: "Whale Wallet", address: "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd", keychainPath: "preview1"),
        EVMWallet(id: 2, alias: "Trading Wallet", address: "0x9876543210fedcba9876543210fedcba98765432", keychainPath: "preview2"),
        EVMWallet(id: 3, alias: "Savings", address: "0x1111111111111111111111111111111111111111", keychainPath: "preview3")
    ]

    WalletHeaderView(
        wallets: wallets,
        selectedWalletId: $selectedId,
        balance: "1,234.56 ETH"
    )
    .frame(width: 400)
}
