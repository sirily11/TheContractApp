//
//  WalletHeaderView.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import SwiftUI
import EvmCore
import BigInt

/// Header view displaying wallet address and balance
struct WalletHeaderView: View {
    // MARK: - Properties

    let wallets: [EVMWallet]
    @Binding var selectedWalletId: Int
    let endpoint: Endpoint? // RPC endpoint for balance fetching
    let refreshInterval: TimeInterval // Balance refresh interval in seconds

    @State private var balance: String = "0.0"
    @State private var isLoadingBalance = false
    @State private var showCopied = false
    @State private var balanceTask: Task<Void, Never>?

    // MARK: - Computed Properties

    private var selectedWallet: EVMWallet? {
        wallets.first { $0.id == selectedWalletId } ?? wallets.first
    }

    private var address: String {
        selectedWallet?.address ?? "No wallet selected"
    }

    private var nativeTokenSymbol: String {
        endpoint?.nativeTokenSymbol ?? "ETH"
    }

    private var nativeTokenDecimals: Int {
        endpoint?.nativeTokenDecimals ?? 18
    }

    private var formattedBalance: String {
        "\(balance) \(nativeTokenSymbol)"
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
                HStack(spacing: 8) {
                    Text(formattedBalance)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    if isLoadingBalance {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }

                Text("Available Balance")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .task(id: "\(selectedWalletId)-\(endpoint?.id ?? 0)") {
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

// MARK: - Preview

#Preview("With Balance") {
    @Previewable @State var selectedId = 1
    let wallets = [
        EVMWallet(id: 1, alias: "Main Wallet", address: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb", keychainPath: "preview1"),
        EVMWallet(id: 2, alias: "Secondary", address: "0x1234567890abcdef1234567890abcdef12345678", keychainPath: "preview2")
    ]
    let endpoint = Endpoint(
        id: 1,
        name: "Mainnet",
        url: "https://eth.llamarpc.com",
        chainId: "1",
        nativeTokenSymbol: "ETH",
        nativeTokenName: "Ethereum"
    )

    WalletHeaderView(
        wallets: wallets,
        selectedWalletId: $selectedId,
        endpoint: endpoint,
        refreshInterval: 10.0
    )
    .frame(width: 400)
}

#Preview("Zero Balance") {
    @Previewable @State var selectedId = 1
    let wallets = [
        EVMWallet(id: 1, alias: "Empty Wallet", address: "0x1234567890abcdef1234567890abcdef12345678", keychainPath: "preview1")
    ]
    let endpoint = Endpoint(
        id: 1,
        name: "Sepolia",
        url: "https://sepolia.gateway.tenderly.co",
        chainId: "11155111",
        nativeTokenSymbol: "ETH",
        nativeTokenName: "Ethereum"
    )

    WalletHeaderView(
        wallets: wallets,
        selectedWalletId: $selectedId,
        endpoint: endpoint,
        refreshInterval: 10.0
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
    let endpoint = Endpoint(
        id: 1,
        name: "Mainnet",
        url: "https://eth.llamarpc.com",
        chainId: "1",
        nativeTokenSymbol: "ETH",
        nativeTokenName: "Ethereum"
    )

    WalletHeaderView(
        wallets: wallets,
        selectedWalletId: $selectedId,
        endpoint: endpoint,
        refreshInterval: 10.0
    )
    .frame(width: 400)
}
