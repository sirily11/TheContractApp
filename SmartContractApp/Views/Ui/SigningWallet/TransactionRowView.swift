//
//  TransactionRowView.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import SwiftUI

/// Row view for displaying a transaction in a list
struct TransactionRowView: View {

    // MARK: - Properties

    let transaction: Transaction

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // Transaction type icon
            transactionIcon
                .frame(width: 40, height: 40)

            // Transaction details
            VStack(alignment: .leading, spacing: 4) {
                // Title (function name or address)
                Text(transactionTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                // Subtitle (address or time)
                HStack(spacing: 6) {
                    Text(transactionSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if transaction.status != .success {
                        statusBadge
                    }
                }
            }

            Spacer()

            // Value
            VStack(alignment: .trailing, spacing: 4) {
                Text(valueText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(valueColor)

                Text(TransactionFormatter.shortRelativeTime(from: transaction.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Computed Properties

    private var transactionIcon: some View {
        Circle()
            .fill(iconBackgroundColor)
            .overlay {
                Image(systemName: iconName)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }
    }

    private var iconName: String {
        switch transaction.type {
        case .send:
            return "arrow.up"
        case .receive:
            return "arrow.down"
        case .contractCall:
            return "doc.text"
        }
    }

    private var iconColor: Color {
        switch transaction.type {
        case .send:
            return .blue
        case .receive:
            return .green
        case .contractCall:
            return .purple
        }
    }

    private var iconBackgroundColor: Color {
        iconColor.opacity(0.15)
    }

    private var transactionTitle: String {
        if transaction.type == .contractCall, let functionName = transaction.contractFunctionName {
            return functionName.capitalized
        }

        switch transaction.type {
        case .send:
            return "Sent"
        case .receive:
            return "Received"
        case .contractCall:
            return "Contract Call"
        }
    }

    private var transactionSubtitle: String {
        let address = transaction.type == .send ? transaction.to : transaction.from
        return TransactionFormatter.truncateAddress(address, startChars: 6, endChars: 4)
    }

    private var valueText: String {
        let eth = TransactionFormatter.formatWeiToETH(transaction.value, decimals: 4)
        let prefix = transaction.type == .send ? "-" : "+"
        return transaction.value == "0" ? eth : "\(prefix) \(eth)"
    }

    private var valueColor: Color {
        if transaction.value == "0" {
            return .secondary
        }
        return transaction.type == .send ? .red : .green
    }

    private var statusBadge: some View {
        Text(transaction.status.rawValue.capitalized)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusBackgroundColor)
            .foregroundColor(statusForegroundColor)
            .cornerRadius(4)
    }

    private var statusBackgroundColor: Color {
        switch transaction.status {
        case .success:
            return .green.opacity(0.2)
        case .pending:
            return .orange.opacity(0.2)
        case .failed:
            return .red.opacity(0.2)
        }
    }

    private var statusForegroundColor: Color {
        switch transaction.status {
        case .success:
            return .green
        case .pending:
            return .orange
        case .failed:
            return .red
        }
    }
}

// MARK: - Preview

#Preview("Sent Transaction") {
    List {
        TransactionRowView(transaction: .sampleSent)
    }
    .frame(width: 400)
}

#Preview("Received Transaction") {
    List {
        TransactionRowView(transaction: .sampleReceived)
    }
    .frame(width: 400)
}

#Preview("Contract Call") {
    List {
        TransactionRowView(transaction: .sampleContractCall)
    }
    .frame(width: 400)
}

#Preview("Pending Transaction") {
    List {
        TransactionRowView(transaction: .samplePending)
    }
    .frame(width: 400)
}

#Preview("Failed Transaction") {
    List {
        TransactionRowView(transaction: .sampleFailed)
    }
    .frame(width: 400)
}

#Preview("All Transaction Types") {
    List {
        TransactionRowView(transaction: .sampleSent)
        TransactionRowView(transaction: .sampleReceived)
        TransactionRowView(transaction: .sampleContractCall)
        TransactionRowView(transaction: .samplePending)
        TransactionRowView(transaction: .sampleFailed)
        TransactionRowView(transaction: .sampleComplexContract)
    }
    .frame(width: 400)
}
