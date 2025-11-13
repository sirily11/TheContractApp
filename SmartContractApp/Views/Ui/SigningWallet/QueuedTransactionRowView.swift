//
//  QueuedTransactionRowView.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import EvmCore
import SwiftUI

/// Row view for displaying a queued transaction awaiting signature
struct QueuedTransactionRowView: View {
    // MARK: - Properties

    let transaction: QueuedTransaction

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // Warning/attention icon
            Circle()
                .fill(Color.orange.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.orange)
                }

            // Transaction details
            VStack(alignment: .leading, spacing: 4) {
                // Title (function name or "Send ETH")
                Text(transactionTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                // Subtitle (to address)
                HStack(spacing: 6) {
                    Text("To: \(TransactionFormatter.truncateAddress(transaction.to))")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Status badge
                    statusBadge
                }
            }

            Spacer()

            // Value and time
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(transaction.value.toEthers().value))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text(TransactionFormatter.shortRelativeTime(from: transaction.queuedAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Computed Properties

    private var transactionTitle: String {
        if let functionName = transaction.contractFunctionName {
            return functionName.toString().capitalized
        }
        return "Send ETH"
    }

    private var statusBadge: some View {
        Group {
            if transaction.status == .pending {
                Text("Pending Signature")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
                    .cornerRadius(4)
            } else if transaction.status == .approved {
                Text("Approved")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(4)
            } else if transaction.status == .rejected {
                Text("Rejected")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.2))
                    .foregroundColor(.red)
                    .cornerRadius(4)
            }
        }
    }
}

// MARK: - Preview

#Preview("ETH Transfer") {
    List {
        QueuedTransactionRowView(transaction: .sampleETHTransfer)
    }
    .frame(width: 400)
}

#Preview("ERC20 Transfer") {
    List {
        QueuedTransactionRowView(transaction: .sampleERC20Transfer)
    }
    .frame(width: 400)
}

#Preview("Approve") {
    List {
        QueuedTransactionRowView(transaction: .sampleApprove)
    }
    .frame(width: 400)
}

#Preview("Swap") {
    List {
        QueuedTransactionRowView(transaction: .sampleSwap)
    }
    .frame(width: 400)
}

#Preview("High Value") {
    List {
        QueuedTransactionRowView(transaction: .sampleHighValue)
    }
    .frame(width: 400)
}

#Preview("All States") {
    List {
        Section("Pending") {
            QueuedTransactionRowView(transaction: .sampleETHTransfer)
            QueuedTransactionRowView(transaction: .sampleERC20Transfer)
            QueuedTransactionRowView(transaction: .sampleSwap)
        }

        Section("Approved") {
            QueuedTransactionRowView(transaction: .sampleApproved)
        }

        Section("Rejected") {
            QueuedTransactionRowView(transaction: .sampleRejected)
        }
    }
    .frame(width: 400)
}
