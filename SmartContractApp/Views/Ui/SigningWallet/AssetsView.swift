//
//  AssetsView.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import SwiftUI

/// View displaying wallet assets (tokens and ETH)
struct AssetsView: View {
    // MARK: - Properties

    // Native token properties (optional - if not provided, empty state is shown)
    var nativeTokenSymbol: String?
    var nativeTokenName: String?
    var balance: String?

    // Computed assets array
    private var assets: [Asset] {
        guard let symbol = nativeTokenSymbol,
              let name = nativeTokenName,
              let balance = balance else {
            return []
        }

        return [
            Asset(
                name: name,
                symbol: symbol,
                balance: balance,
                icon: "dollarsign.circle.fill",
                color: .blue
            )
        ]
    }

    // MARK: - Body

    var body: some View {
        Group {
            if assets.isEmpty {
                ContentUnavailableView(
                    "No Assets",
                    systemImage: "tray",
                    description: Text("Connect a wallet to view assets")
                )
            } else {
                List {
                    ForEach(assets) { asset in
                        AssetRowView(asset: asset)
                    }
                }
                #if os(iOS)
                .listStyle(.insetGrouped)
                #else
                .listStyle(.sidebar)
                #endif
            }
        }
    }
}

// MARK: - Asset Row View

private struct AssetRowView: View {
    let asset: Asset

    var body: some View {
        HStack(spacing: 12) {
            // Asset icon
            Circle()
                .fill(asset.color.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: asset.icon)
                        .font(.system(size: 20))
                        .foregroundColor(asset.color)
                }

            // Asset info
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(asset.symbol)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Balance
            Text(asset.balance)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview("Assets List") {
    NavigationStack {
        AssetsView()
            .navigationTitle("Assets")
    }
}

#Preview("Single Asset") {
    List {
        AssetRowView(
            asset: Asset(
                name: "Ethereum",
                symbol: "ETH",
                balance: "12.5",
                icon: "diamond.fill",
                color: .blue
            )
        )
    }
    .frame(width: 400, height: 200)
}

#Preview("Empty State") {
    List {
        ContentUnavailableView(
            "No Assets",
            systemImage: "tray",
            description: Text("You don't have any assets yet")
        )
    }
    .frame(width: 400, height: 300)
}
