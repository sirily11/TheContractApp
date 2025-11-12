//
//  AssetsView.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import SwiftUI
import EvmCore
import BigInt

/// View displaying wallet assets (tokens and ETH)
struct AssetsView: View {
    // MARK: - Properties

    let selectedWallet: EVMWallet?
    let endpoint: Endpoint? // RPC endpoint for balance fetching
    let refreshInterval: TimeInterval // Balance refresh interval in seconds

    @State private var balance: String = "0.0"
    @State private var isLoadingBalance = false
    @State private var balanceTask: Task<Void, Never>?

    // MARK: - Computed Properties

    private var nativeTokenSymbol: String {
        endpoint?.nativeTokenSymbol ?? "ETH"
    }

    private var nativeTokenName: String {
        endpoint?.nativeTokenName ?? "Ethereum"
    }

    private var nativeTokenDecimals: Int {
        endpoint?.nativeTokenDecimals ?? 18
    }

    // Computed assets array
    private var assets: [Asset] {
        guard selectedWallet != nil, endpoint != nil else {
            return []
        }

        return [
            Asset(
                name: nativeTokenName,
                symbol: nativeTokenSymbol,
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
        .task(id: "\(selectedWallet?.id ?? 0)-\(endpoint?.id ?? 0)") {
            // Cancel previous task when wallet or endpoint changes
            balanceTask?.cancel()

            // Start new periodic balance fetching
            balanceTask = Task {
                await fetchBalance()

                // Set up periodic refresh
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(refreshInterval))
                    if !Task.isCancelled {
                        await fetchBalance()
                    }
                }
            }
        }
        .onDisappear {
            balanceTask?.cancel()
        }
    }

    // MARK: - Balance Fetching

    /// Fetches the balance from the blockchain using the selected endpoint
    private func fetchBalance() async {
        // Guard against missing dependencies
        guard let endpoint = endpoint,
              let selectedWallet = selectedWallet,
              let endpointUrl = URL(string: endpoint.url) else {
            await MainActor.run {
                balance = "0.0"
            }
            return
        }

        await MainActor.run {
            isLoadingBalance = true
        }

        do {
            let transport = HttpTransport(url: endpointUrl)
            let client = EvmClient(transport: transport)

            // Convert wallet address string to Address type
            let address = try Address(fromHexString: selectedWallet.address)

            // Fetch balance in wei
            let balanceWei = try await client.getBalance(address: address)

            // Convert wei to native token amount (e.g., wei to ETH)
            let balanceDecimal = formatBalance(wei: balanceWei, decimals: nativeTokenDecimals)

            await MainActor.run {
                balance = balanceDecimal
                isLoadingBalance = false
            }
        } catch {
            print("Failed to fetch balance: \(error)")
            await MainActor.run {
                balance = "0.0"
                isLoadingBalance = false
            }
        }
    }

    /// Formats wei balance to human-readable format with specified decimals
    /// - Parameters:
    ///   - wei: Balance in wei
    ///   - decimals: Number of decimals for the native token (e.g., 18 for ETH)
    /// - Returns: Formatted balance string
    private func formatBalance(wei: BigInt, decimals: Int) -> String {
        // Convert wei to token amount
        let divisor = BigInt(10).power(decimals)
        let integerPart = wei / divisor
        let remainder = wei % divisor

        // Format with up to 4 decimal places
        if remainder == 0 {
            return String(integerPart)
        } else {
            // Calculate fractional part
            let fractionalValue = Double(remainder) / Double(divisor)
            let totalValue = Double(integerPart) + fractionalValue

            // Format with appropriate decimal places
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 4
            formatter.roundingMode = .down

            return formatter.string(from: NSNumber(value: totalValue)) ?? String(integerPart)
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

#Preview("Assets List with Balance") {
    let wallet = EVMWallet(
        id: 1,
        alias: "Main Wallet",
        address: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
        keychainPath: "preview1"
    )
    let endpoint = Endpoint(
        id: 1,
        name: "Mainnet",
        url: "https://eth.llamarpc.com",
        chainId: "1",
        nativeTokenSymbol: "ETH",
        nativeTokenName: "Ethereum"
    )

    NavigationStack {
        AssetsView(
            selectedWallet: wallet,
            endpoint: endpoint,
            refreshInterval: 10.0
        )
        .navigationTitle("Assets")
    }
}

#Preview("Single Asset Row") {
    List {
        AssetRowView(
            asset: Asset(
                name: "Ethereum",
                symbol: "ETH",
                balance: "12.5",
                icon: "dollarsign.circle.fill",
                color: .blue
            )
        )
    }
    .frame(width: 400, height: 200)
}

#Preview("Empty State") {
    NavigationStack {
        AssetsView(
            selectedWallet: nil,
            endpoint: nil,
            refreshInterval: 10.0
        )
        .navigationTitle("Assets")
    }
    .frame(width: 400, height: 300)
}
