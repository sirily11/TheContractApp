//
//  WalletRowView.swift
//  SmartContractApp
//
//  Created by Claude Code
//

import SwiftUI

struct WalletRowView: View {
    let wallet: EVMWallet

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(wallet.alias)
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                if wallet.isFromMnemonic {
                    Image(systemName: "list.bullet.rectangle.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }

            Text(truncatedAddress(wallet.address))
                .font(.caption)
                .foregroundColor(.secondary)
                .fontDesign(.monospaced)

            Text("Created \(wallet.createdAt, style: .relative) ago")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func truncatedAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        let start = String(address.prefix(6))
        let end = String(address.suffix(4))
        return "\(start)...\(end)"
    }
}

#Preview {
    List {
        WalletRowView(
            wallet: EVMWallet(
                alias: "My Main Wallet",
                address: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
                keychainPath: "wallet_preview",
                isFromMnemonic: true
            )
        )

        WalletRowView(
            wallet: EVMWallet(
                alias: "Trading Wallet",
                address: "0x1234567890abcdef1234567890abcdef12345678",
                keychainPath: "wallet_preview2",
                isFromMnemonic: false
            )
        )
    }
}
