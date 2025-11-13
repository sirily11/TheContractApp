//
//  TransactionDetailView+ContractSection.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import EvmCore
import SwiftUI

// MARK: - Contract Section Extension

extension TransactionDetailView {
    /// Contract call details section
    @ViewBuilder
    var contractSection: some View {
        if let functionName = transaction.contractFunctionName {
            Section("Contract Call Details") {
                // Function name
                functionNameRow(functionName: functionName)

                // Function signature
                if let parameters = transaction.getContractParameters() {
                    functionSignatureRow(functionName: functionName, parameters: parameters)

                    Divider()

                    // Parameters
                    parametersSection(parameters: parameters)
                }

                Divider()

                // Receiver (contract address)
                receiverRow
            }
        }
    }

    // MARK: - Contract Detail Rows

    private func functionNameRow(functionName: String) -> some View {
        HStack {
            Text("Function")
                .foregroundColor(.secondary)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "function")
                    .foregroundColor(.purple)
                Text(functionName)
                    .font(.system(.body, design: .monospaced))
            }
        }
    }

    private func functionSignatureRow(functionName: String, parameters: [TransactionParameter]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Signature")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(TransactionFormatter.formatFunctionSignature(
                functionName: functionName,
                parameters: parameters
            ))
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.purple.opacity(0.1))
            .cornerRadius(6)
        }
    }

    private func parametersSection(parameters: [TransactionParameter]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Parameters (\(parameters.count))")
                .font(.subheadline)
                .fontWeight(.medium)

            ForEach(parameters) { parameter in
                parameterDetailView(parameter: parameter)

                if parameter.id != parameters.last?.id {
                    Divider()
                }
            }
        }
    }

    private func parameterDetailView(parameter: TransactionParameter) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Parameter name and type
            HStack {
                Text(parameter.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text(parameter.type)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.2))
                    .foregroundColor(.purple)
                    .cornerRadius(4)
            }

            // Parameter value
            Text(parameter.value.toString())
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
        }
    }

    private var receiverRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Contract Address")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                Image(systemName: "building.2")
                    .foregroundColor(.purple)

                Text(transaction.to)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
    }
}
