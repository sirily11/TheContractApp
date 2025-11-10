//
//  TransactionDetailView.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import SwiftUI

/// Detailed view of a transaction
struct TransactionDetailView: View {

    // MARK: - Properties

    let transaction: Transaction

    @State private var showingShareSheet = false

    // MARK: - Body

    var body: some View {
        Form {
            // Status section
            statusSection

            // Transaction info section
            transactionInfoSection

            // Addresses section
            addressesSection

            // Value and gas section
            valueAndGasSection

            // Timing and block section
            timingSection

            // Contract details (if applicable)
            if transaction.isContractCall {
                contractSection
            }

            // Raw data section
            rawDataSection
        }
        .formStyle(.grouped)
        .navigationTitle("Transaction Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: copyTransactionHash) {
                        Label("Copy Hash", systemImage: "doc.on.doc")
                    }

                    Button(action: { showingShareSheet = true }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    // MARK: - Sections

    private var statusSection: some View {
        Section {
            HStack {
                Label(
                    transaction.status.rawValue.capitalized,
                    systemImage: statusIcon
                )
                .foregroundColor(statusColor)

                Spacer()

                statusBadge
            }
        }
    }

    private var transactionInfoSection: some View {
        Section("Transaction") {
            // Hash
            VStack(alignment: .leading, spacing: 4) {
                Text("Hash")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(transaction.hash)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }

            // Type
            HStack {
                Text("Type")
                    .foregroundColor(.secondary)
                Spacer()
                Label(
                    transaction.type.rawValue.capitalized,
                    systemImage: typeIcon
                )
                .foregroundColor(typeColor)
            }
        }
    }

    private var addressesSection: some View {
        Section("Addresses") {
            // From
            VStack(alignment: .leading, spacing: 4) {
                Text("From")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(transaction.from)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }

            // To
            VStack(alignment: .leading, spacing: 4) {
                Text("To")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(transaction.to)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
    }

    private var valueAndGasSection: some View {
        Section("Value & Gas") {
            // Value
            HStack {
                Text("Value")
                    .foregroundColor(.secondary)
                Spacer()
                Text(TransactionFormatter.formatWeiToETH(transaction.value))
                    .fontWeight(.medium)
            }

            // Gas used
            if let gasUsed = transaction.gasUsed {
                HStack {
                    Text("Gas Used")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(gasUsed)
                        .font(.system(.body, design: .monospaced))
                }
            }

            // Gas price
            if let gasPrice = transaction.gasPrice {
                HStack {
                    Text("Gas Price")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(TransactionFormatter.formatGasPrice(gasPrice))
                        .font(.system(.body, design: .monospaced))
                }
            }

            // Total gas cost
            if let gasUsed = transaction.gasUsed,
               let gasPrice = transaction.gasPrice {
                HStack {
                    Text("Total Gas Cost")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(TransactionFormatter.formatGasCost(gasUsed: gasUsed, gasPrice: gasPrice))
                        .fontWeight(.medium)
                }
            }
        }
    }

    private var timingSection: some View {
        Section("Timing") {
            // Timestamp
            HStack {
                Text("Time")
                    .foregroundColor(.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(TransactionFormatter.relativeTime(from: transaction.timestamp))
                    Text(transaction.timestamp, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Block number
            if let blockNumber = transaction.blockNumber {
                HStack {
                    Text("Block")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("#\(blockNumber)")
                        .font(.system(.body, design: .monospaced))
                }
            }
        }
    }

    private var rawDataSection: some View {
        Section("Raw Data") {
            if let abiData = transaction.contractAbiData {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Encoded Data")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(abiData)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(5)
                }
            } else {
                Text("No additional data")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
        }
    }

    // MARK: - Computed Properties

    private var statusIcon: String {
        switch transaction.status {
        case .success:
            return "checkmark.circle.fill"
        case .pending:
            return "clock.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch transaction.status {
        case .success:
            return .green
        case .pending:
            return .orange
        case .failed:
            return .red
        }
    }

    private var statusBadge: some View {
        Text(transaction.status.rawValue.capitalized)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(6)
    }

    private var typeIcon: String {
        switch transaction.type {
        case .send:
            return "arrow.up.circle"
        case .receive:
            return "arrow.down.circle"
        case .contractCall:
            return "doc.text"
        }
    }

    private var typeColor: Color {
        switch transaction.type {
        case .send:
            return .blue
        case .receive:
            return .green
        case .contractCall:
            return .purple
        }
    }

    // MARK: - Actions

    private func copyTransactionHash() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transaction.hash, forType: .string)
        #else
        UIPasteboard.general.string = transaction.hash
        #endif
    }
}

// MARK: - Preview

#Preview("Sent Transaction") {
    NavigationStack {
        TransactionDetailView(transaction: .sampleSent)
    }
}

#Preview("Received Transaction") {
    NavigationStack {
        TransactionDetailView(transaction: .sampleReceived)
    }
}

#Preview("Contract Call") {
    NavigationStack {
        TransactionDetailView(transaction: .sampleContractCall)
    }
}

#Preview("Pending Transaction") {
    NavigationStack {
        TransactionDetailView(transaction: .samplePending)
    }
}

#Preview("Failed Transaction") {
    NavigationStack {
        TransactionDetailView(transaction: .sampleFailed)
    }
}

#Preview("Complex Contract") {
    NavigationStack {
        TransactionDetailView(transaction: .sampleComplexContract)
    }
}
