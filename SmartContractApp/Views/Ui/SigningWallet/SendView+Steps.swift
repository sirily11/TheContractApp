//
//  SendView+Steps.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import SwiftUI
import BigInt

extension SendView {
    // MARK: - Step 1: Select Asset

    @ViewBuilder
    var selectAssetStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Select Asset to Send")
                    .font(.headline)
                    .padding(.horizontal)

                VStack(spacing: 12) {
                    // Native token asset
                    AssetSelectionRow(
                        asset: Asset(
                            name: nativeTokenName,
                            symbol: nativeTokenSymbol,
                            balance: balance,
                            icon: "dollarsign.circle.fill",
                            color: .blue
                        ),
                        isSelected: selectedAsset?.symbol == nativeTokenSymbol
                    ) {
                        selectedAsset = Asset(
                            name: nativeTokenName,
                            symbol: nativeTokenSymbol,
                            balance: balance,
                            icon: "dollarsign.circle.fill",
                            color: .blue
                        )
                    }

                    // Placeholder for future ERC20 tokens
                    VStack(spacing: 8) {
                        Image(systemName: "plus.circle.dashed")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)

                        Text("ERC20 tokens coming soon")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    // MARK: - Step 2: Enter Details

    @ViewBuilder
    var enterDetailsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Selected asset display
                if let asset = selectedAsset {
                    HStack {
                        Image(systemName: asset.icon)
                            .font(.title2)
                            .foregroundColor(asset.color)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(asset.name)
                                .font(.headline)
                            Text("\(asset.balance) \(asset.symbol)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
                }

                // Recipient address
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recipient Address")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    TextField("0x...", text: $recipientAddress)
                        .textFieldStyle(.roundedBorder)
                        #if os(iOS)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.asciiCapable)
                        #endif
                        .font(.system(.body, design: .monospaced))

                    if !recipientAddress.isEmpty && !isAddressValid {
                        Label("Invalid Ethereum address", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                // Amount
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Amount")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Spacer()

                        if let asset = selectedAsset {
                            Button(action: {
                                amount = asset.balance
                            }) {
                                Text("Max")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }

                    HStack {
                        TextField("0.0", text: $amount)
                            .textFieldStyle(.roundedBorder)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .font(.title3)

                        if let asset = selectedAsset {
                            Text(asset.symbol)
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }

                    if !amount.isEmpty {
                        if let amountValue = Double(amount),
                           let balanceValue = Double(balance) {
                            if amountValue > balanceValue {
                                Label("Insufficient balance", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            } else if amountValue > 0 {
                                // Show USD equivalent placeholder
                                Text("≈ $0.00 USD")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Spacer(minLength: 20)
            }
            .padding()
        }
    }

    // MARK: - Step 3: Review

    @ViewBuilder
    var reviewStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Review Transaction")
                    .font(.headline)

                // Transaction summary
                VStack(spacing: 0) {
                    // From
                    ReviewRow(
                        label: "From",
                        value: formatAddress(walletAddress),
                        isMonospaced: true
                    )

                    Divider()

                    // To
                    ReviewRow(
                        label: "To",
                        value: formatAddress(recipientAddress),
                        isMonospaced: true
                    )

                    Divider()

                    // Amount
                    if let asset = selectedAsset {
                        ReviewRow(
                            label: "Amount",
                            value: "\(amount) \(asset.symbol)"
                        )
                    }

                    Divider()

                    // Gas estimate
                    if isEstimatingGas {
                        HStack {
                            Text("Gas Fee")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Spacer()

                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        .padding()
                    } else if let gas = gasEstimate {
                        ReviewRow(
                            label: "Gas Fee",
                            value: formatGas(gas)
                        )
                    } else if let error = estimateError {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Gas Fee")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text(error)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding()
                    }

                    Divider()

                    // Total
                    if let asset = selectedAsset, let gas = gasEstimate {
                        ReviewRow(
                            label: "Total",
                            value: "\(amount) \(asset.symbol) + gas",
                            isBold: true
                        )
                    }
                }
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(12)

                // Warning
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Review carefully")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("Transactions cannot be reversed once confirmed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)

                Spacer(minLength: 20)
            }
            .padding()
        }
    }

    // MARK: - Helper Methods

    private func formatAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        let start = address.prefix(6)
        let end = address.suffix(4)
        return "\(start)...\(end)"
    }

    private func formatGas(_ gas: BigInt) -> String {
        // Simplified gas formatting
        // TODO: Calculate actual gas cost based on gas price
        return "~\(gas) gas"
    }
}

// MARK: - Asset Selection Row

struct AssetSelectionRow: View {
    let asset: Asset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: asset.icon)
                    .font(.title2)
                    .foregroundColor(asset.color)
                    .frame(width: 44, height: 44)
                    .background(asset.color.opacity(0.1))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(asset.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(asset.symbol)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(asset.balance)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(asset.symbol)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.secondary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Review Row

struct ReviewRow: View {
    let label: String
    let value: String
    var isMonospaced: Bool = false
    var isBold: Bool = false

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(isMonospaced ? .system(.subheadline, design: .monospaced) : .subheadline)
                .fontWeight(isBold ? .semibold : .regular)
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding()
    }
}
