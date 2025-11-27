//
//  SignTransactionView+Sections.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import BigInt
import EvmCore
import SwiftUI

// MARK: - Supporting Views

private struct ParameterRow: View {
    let parameter: TransactionParameter

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(parameter.name): \(parameter.type)")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(formattedValue)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.primary)
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
        }
    }

    private var formattedValue: String {
        if parameter.type.displayString.lowercased().contains("address") {
            return TransactionFormatter.truncateAddress(parameter.value.toString())
        }
        return parameter.value.toString()
    }
}

// MARK: - View Sections

extension SignTransactionView {
    var resultSection: some View {
        Section {
            VStack(spacing: 12) {
                if authenticationResult == true {
                    // Success state
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)

                    Text("Transaction Sent!")
                        .font(.title2)
                        .fontWeight(.bold)

                    if let hash = walletSigner.lastTransactionHash {
                        CopyableView(
                            text: hash,
                            displayText: TransactionFormatter.truncateData(hash, maxLength: 40),
                            label: "Transaction Hash:",
                            style: .success
                        )
                    }

                    Text("Your transaction has been successfully signed and broadcast to the network.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                } else {
                    // Failure state
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)

                    Text("Transaction Failed")
                        .font(.title2)
                        .fontWeight(.bold)

                    if let error = walletSigner.transactionError {
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    var warningSection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)

                Text("Review Transaction")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Please review the transaction details carefully before signing.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    var transactionSection: some View {
        Section("Transaction Details") {
            // Type
            HStack {
                Label("Type", systemImage: transaction.contractFunctionName == .constructor ? "hammer" : (transaction.isContractCall ? "doc.text" : "arrow.up.circle"))
                    .foregroundColor(.secondary)
                Spacer()
                Text(transaction.contractFunctionName == .constructor ? "Contract Deployment" : (transaction.isContractCall ? "Contract Call" : "ETH Transfer"))
            }

            // To (hide for contract deployment since there's no recipient)
            if transaction.contractFunctionName != .constructor && !transaction.to.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("To", systemImage: "arrow.right")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(TransactionFormatter.truncateAddress(transaction.to))
                        .font(.system(.body, design: .monospaced))
                }
            }

            // Value
            HStack {
                Label("Value", systemImage: "diamond")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(String(transaction.value.toEthers().value)) ETH")
                    .foregroundColor(transaction.value.toHexString() != "0x" ? .blue : .secondary)
            }
        }
    }

    @ViewBuilder
    var endpointSection: some View {
        if let endpointName = transaction.endpointName {
            Section("Network") {
                // Endpoint name
                HStack {
                    Label("Network", systemImage: "network")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(endpointName)
                        .fontWeight(.medium)
                }

                // Endpoint URL
                if let endpointUrl = transaction.endpointUrl {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("RPC URL", systemImage: "link")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(endpointUrl)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    @ViewBuilder
    var contractSection: some View {
        if let functionName = transaction.contractFunctionName {
            Section("Contract Call") {
                // Function name
                HStack {
                    Label("Function", systemImage: "function")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(functionName.toString())
                        .font(.system(.body, design: .monospaced))
                }

                // Contract address (or "New Contract" for deployments)
                VStack(alignment: .leading, spacing: 4) {
                    Label(functionName == .constructor ? "Deployment" : "Contract Address", systemImage: "building.2")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if functionName == .constructor {
                        Text("New contract will be created")
                            .font(.system(.caption))
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        Text(transaction.to)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }

                // Parameters
                if !transaction.contractParameters.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Parameters (\(transaction.contractParameters.count))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        ForEach(transaction.contractParameters) { param in
                            ParameterRow(parameter: param)
                        }
                    }
                }
            }
        }
    }

    var dataSection: some View {
        Section("Raw Data") {
            // For deployments, show bytecode; for other calls, show data
            if let bytecode = transaction.bytecode, !bytecode.isEmpty, transaction.contractFunctionName == .constructor {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Bytecode", systemImage: "chevron.left.forwardslash.chevron.right")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(TransactionFormatter.truncateData(bytecode, maxLength: 60))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
            } else if let data = transaction.data, !data.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Data", systemImage: "chevron.left.forwardslash.chevron.right")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(TransactionFormatter.truncateData(data, maxLength: 60))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
            } else {
                Text("No data")
                    .foregroundColor(.secondary)
            }
        }
    }

    var gasSection: some View {
        Section("Network Fee") {
            if isEstimatingGas {
                HStack {
                    Label("Estimating Gas", systemImage: "fuelpump")
                        .foregroundColor(.secondary)
                    Spacer()
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                }
            } else if let error = gasEstimationError {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Gas Estimation Failed", systemImage: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let estimatedGas = estimatedGas {
                HStack {
                    Label("Estimated Gas", systemImage: "fuelpump")
                        .foregroundColor(.secondary)
                    Spacer()
                    if let gasValue = BigInt(estimatedGas.hasPrefix("0x") ? String(estimatedGas.dropFirst(2)) : estimatedGas, radix: 16) {
                        Text("\(gasValue) units")
                    } else {
                        Text(estimatedGas)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            } else if let gasEstimate = transaction.gasEstimate {
                HStack {
                    Label("Estimated Gas", systemImage: "fuelpump")
                        .foregroundColor(.secondary)
                    Spacer()
                    if let gasValue = BigInt(gasEstimate.hasPrefix("0x") ? String(gasEstimate.dropFirst(2)) : gasEstimate, radix: 16) {
                        Text("\(gasValue) units")
                    } else {
                        Text("\(gasEstimate) units")
                    }
                }
            } else {
                Text("Gas estimate not available")
                    .foregroundColor(.secondary)
            }
        }
    }

    var actionsSection: some View {
        Section {
            if authenticationResult == true {
                EmptyView()
            } else if authenticationResult == false {
                // Failure - show retry and close buttons
                Button(action: {
                    Task {
                        await authenticateAndApprove()
                    }
                }) {
                    HStack {
                        Spacer()
                        Image(systemName: "arrow.clockwise")
                        Text("Retry")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .disabled(isAuthenticating || walletSigner.isProcessingTransaction)
                .listRowBackground(Color.blue)
                .buttonStyle(.glass)
                .foregroundColor(.white)
                .accessibilityIdentifier(.signing.retryButton)

            } else {
                // Waiting for approval - show approve and reject buttons
                Button(action: {
                    Task {
                        await authenticateAndApprove()
                    }
                }) {
                    HStack {
                        Image(systemName: biometricHelper.biometricIconName())
                            .font(.system(size: 20))
                        if isAuthenticating {
                            Text("Authenticating...")
                        } else {
                            Text("Approve with \(biometricHelper.biometricType())")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isAuthenticating || walletSigner.isProcessingTransaction)
                .buttonStyle(.glass)
                .accessibilityIdentifier(.signing.approveButton)

                // Reject
                Button(action: rejectTransaction) {
                    HStack {
                        Spacer()
                        Text("Reject")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .disabled(isAuthenticating || walletSigner.isProcessingTransaction)
                .foregroundColor(.red)
                .accessibilityIdentifier(.signing.rejectButton)
            }
        }
    }
}
