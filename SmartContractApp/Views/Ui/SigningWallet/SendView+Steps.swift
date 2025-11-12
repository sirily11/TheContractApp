//
//  SendView+Steps.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import BigInt
import SwiftUI

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
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    // MARK: - Step 2: Enter Details

    @ViewBuilder
    var enterDetailsStep: some View {
        Form {
            // Selected asset display
            if let asset = selectedAsset {
                HStack {
                    Image(systemName: asset.icon)
                        .font(.title2)
                        .foregroundColor(asset.color)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(asset.name)
                            .font(.headline)
                        HStack(spacing: 4) {
                            Text("\(asset.balance) \(asset.symbol)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if isLoadingBalance {
                                ProgressView()
                                    .scaleEffect(0.6)
                            }
                        }
                    }

                    Spacer()
                }
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

                // Show current balance
                if let asset = selectedAsset {
                    Text("Balance: \(balance) \(asset.symbol)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if !amount.isEmpty {
                    if let amountValue = Double(amount),
                       let balanceValue = Double(balance)
                    {
                        if amountValue > balanceValue {
                            Label("Insufficient balance", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
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
