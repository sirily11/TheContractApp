//
//  SendView.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import BigInt
import EvmCore
import SwiftUI

struct SendView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @Environment(WalletSignerViewModel.self) private var walletSignerViewModel
    @Environment(\.dismiss) private var dismiss

    // Dependencies
    let wallet: EVMWallet?
    let endpoint: Endpoint?

    // Step management
    @State var currentStep: SendStep = .selectAsset

    // Balance fetching
    @State var balance: String = "0.0"
    @State var isLoadingBalance = false
    @State private var balanceTask: Task<Void, Never>?

    // Form data
    @State var selectedAsset: Asset?
    @State var recipientAddress: String = ""
    @State var amount: String = ""
    @State var gasEstimate: BigInt?
    @State var isEstimatingGas: Bool = false
    @State var estimateError: String?

    // Validation and error handling
    @State var showingError: Bool = false
    @State var errorMessage: String = ""

    // MARK: - Computed Properties

    var walletAddress: String {
        wallet?.address ?? "No wallet selected"
    }

    var nativeTokenSymbol: String {
        endpoint?.nativeTokenSymbol ?? "ETH"
    }

    var nativeTokenName: String {
        endpoint?.nativeTokenName ?? "Ethereum"
    }

    var nativeTokenDecimals: Int {
        endpoint?.nativeTokenDecimals ?? 18
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Step content
                switch currentStep {
                case .selectAsset:
                    selectAssetStep
                case .enterDetails:
                    enterDetailsStep
                }

                Spacer()
            }
            .navigationTitle("Send")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    // Cancel button
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isPresented = false
                        }
                    }

                    // Back button (leading)
                    if currentStep != .selectAsset {
                        ToolbarItem(placement: .navigation) {
                            Button("Back") {
                                withAnimation {
                                    currentStep = currentStep.previous ?? .selectAsset
                                }
                            }
                        }
                    }

                    // Next/Send button (trailing)
                    ToolbarItem(placement: .confirmationAction) {
                        if currentStep == .enterDetails {
                            Button("Send") {
                                sendTransaction()
                            }
                            .disabled(!isReviewValid)
                        } else {
                            Button("Next") {
                                handleNext()
                            }
                            .disabled(!canProceed)
                        }
                    }
                }
                .alert("Error", isPresented: $showingError) {
                    Button("OK") {}
                } message: {
                    Text(errorMessage)
                }
        }
        #if os(iOS)
        .presentationDetents([.large])
        #endif
        .task(id: "\(wallet?.id ?? 0)-\(endpoint?.id ?? 0)") {
            // Cancel previous task when wallet or endpoint changes
            balanceTask?.cancel()

            // Fetch balance once when view appears
            balanceTask = Task {
                await fetchBalance()
            }
        }
        .onDisappear {
            balanceTask?.cancel()
        }
    }

    // MARK: - Validation

    var canProceed: Bool {
        switch currentStep {
        case .selectAsset:
            return selectedAsset != nil
        case .enterDetails:
            return isAddressValid && isAmountValid
        }
    }

    var isAddressValid: Bool {
        // Basic Ethereum address validation
        let trimmed = recipientAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("0x") && trimmed.count == 42
    }

    var isAmountValid: Bool {
        guard let amountValue = Double(amount), amountValue > 0 else {
            return false
        }
        guard let balanceValue = Double(balance) else {
            return false
        }
        return amountValue <= balanceValue
    }

    var isReviewValid: Bool {
        return isAddressValid && isAmountValid
    }

    // MARK: - Actions

    private func handleNext() {
        switch currentStep {
        case .selectAsset:
            // Auto-select native token
            if selectedAsset == nil {
                selectedAsset = Asset(
                    name: nativeTokenName,
                    symbol: nativeTokenSymbol,
                    balance: balance,
                    icon: "dollarsign.circle.fill",
                    color: .blue
                )
            }
            withAnimation {
                currentStep = .enterDetails
            }
        case .enterDetails:
            // Estimate gas before proceeding to review
            sendTransaction()
        }
    }

    private func sendTransaction() {
        _ = try? walletSignerViewModel.queueTransaction(to: recipientAddress, value: .ether(.init(float: Double(amount) ?? 0)))
        dismiss()
    }

    // MARK: - Balance Fetching

    /// Fetches the balance from the blockchain using the selected endpoint
    private func fetchBalance() async {
        // Guard against missing dependencies
        guard let endpoint = endpoint,
              let wallet = wallet,
              let endpointUrl = URL(string: endpoint.url)
        else {
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
            let address = try Address(fromHexString: wallet.address)

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

// MARK: - Send Step Enum

enum SendStep: Int, CaseIterable, Comparable {
    case selectAsset = 0
    case enterDetails = 1

    var title: String {
        switch self {
        case .selectAsset:
            return "Select"
        case .enterDetails:
            return "Details"
        }
    }

    var next: SendStep? {
        SendStep(rawValue: rawValue + 1)
    }

    var previous: SendStep? {
        SendStep(rawValue: rawValue - 1)
    }

    static func < (lhs: SendStep, rhs: SendStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Asset Model (Temporary)

struct Asset: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let symbol: String
    let balance: String
    let icon: String
    let color: Color
}

// MARK: - Preview

#Preview {
    @Previewable @State var isPresented = true

    let wallet = EVMWallet(
        id: 1,
        alias: "Main Wallet",
        address: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb0",
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

    SendView(
        isPresented: $isPresented,
        wallet: wallet,
        endpoint: endpoint
    )
}
