//
//  FunctionHistoryRowView.swift
//  SmartContractApp
//
//  Created by Claude on 11/17/25.
//

import EvmCore
import SwiftData
import SwiftUI

/// Displays a single function call history item
/// Shows function name, parameters, result, timestamp, and status
struct FunctionHistoryRowView: View {
    let functionCall: ContractFunctionCall

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Function name, status badge, and timestamp
            HStack {
                HStack(spacing: 8) {
                    Text(functionCall.functionName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    statusBadge
                }

                Spacer()

                Text(functionCall.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Parameters
            if let params = functionCall.getParameters(), !params.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Parameters:")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    ForEach(Array(params.enumerated()), id: \.offset) { index, param in
                        HStack {
                            Text("\(param.name):")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(String(describing: param.value.value))
                                .font(.caption)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(8)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(6)
            }

            // Result or Error
            if let result = functionCall.result {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Result:")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text(result)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                }
                .padding(8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
            } else if let errorMessage = functionCall.errorMessage {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Error:")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(3)
                }
                .padding(8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)
            }

            // Transaction hash (for write functions)
            if let txHash = functionCall.transactionHash {
                HStack {
                    Image(systemName: "link")
                        .font(.caption2)
                    Text("Tx: \(truncatedHash(txHash))")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }

            // Gas used (for write functions)
            if let gasUsed = functionCall.gasUsed {
                HStack {
                    Image(systemName: "fuelpump")
                        .font(.caption2)
                    Text("Gas: \(gasUsed)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        Text(statusText)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(4)
    }

    private var statusText: String {
        switch functionCall.status {
        case .pending:
            return "Pending"
        case .success:
            return "Success"
        case .failed:
            return "Failed"
        case .reverted:
            return "Reverted"
        }
    }

    private var statusColor: Color {
        switch functionCall.status {
        case .pending:
            return .orange
        case .success:
            return .green
        case .failed, .reverted:
            return .red
        }
    }

    // MARK: - Helper Methods

    /// Truncate transaction hash for display
    private func truncatedHash(_ hash: String) -> String {
        guard hash.count > 10 else { return hash }
        let start = hash.prefix(6)
        let end = hash.suffix(4)
        return "\(start)...\(end)"
    }
}

// MARK: - Preview

#Preview("Successful Read Call") {
    FunctionHistoryRowView(functionCall: .sampleReadCall)
        .padding()
}

#Preview("Successful Write Call") {
    FunctionHistoryRowView(functionCall: .sampleWriteCall)
        .padding()
}

#Preview("Failed Call") {
    FunctionHistoryRowView(functionCall: .sampleFailedCall)
        .padding()
}

#Preview("Reverted Call") {
    FunctionHistoryRowView(functionCall: .sampleRevertedCall)
        .padding()
}

#Preview("Pending Call") {
    FunctionHistoryRowView(functionCall: .samplePendingCall)
        .padding()
}
