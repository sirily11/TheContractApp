//
//  SignTransactionView.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import EvmCore
import SwiftData
import SwiftUI

/// View for reviewing and signing a queued transaction
struct SignTransactionView: View {
    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let transaction: QueuedTransaction

    @State private var isAuthenticating = false
    @State private var authenticationResult: Bool?
    @State private var showingResultAlert = false

    private let biometricHelper = BiometricAuthHelper()

    // MARK: - Body

    var body: some View {
        Form {
            // Warning section
            warningSection

            // Transaction details
            transactionSection

            // Contract details (if applicable)
            if transaction.isContractCall {
                contractSection
            }

            // Raw data
            dataSection

            // Gas estimate
            gasSection

            // Action buttons
            actionsSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationTitle("Sign Transaction")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        #else
            .toolbarBackground(.hidden, for: .automatic)
        #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert(alertTitle, isPresented: $showingResultAlert) {
                Button("OK") {
                    if authenticationResult == true {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
    }

    // MARK: - Form Sections

    private var warningSection: some View {
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

    private var transactionSection: some View {
        Section("Transaction Details") {
            // Type
            HStack {
                Label("Type", systemImage: transaction.isContractCall ? "doc.text" : "arrow.up.circle")
                    .foregroundColor(.secondary)
                Spacer()
                Text(transaction.isContractCall ? "Contract Call" : "ETH Transfer")
            }

            // To
            VStack(alignment: .leading, spacing: 4) {
                Label("To", systemImage: "arrow.right")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(TransactionFormatter.truncateAddress(transaction.to))
                    .font(.system(.body, design: .monospaced))
            }

            // Value
            HStack {
                Label("Value", systemImage: "diamond")
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(transaction.value.toEthers().value))
                    .foregroundColor(transaction.value.toHexString() != "0x" ? .blue : .secondary)
            }
        }
    }

    @ViewBuilder
    private var contractSection: some View {
        if let functionName = transaction.contractFunctionName {
            Section("Contract Call") {
                // Function name
                HStack {
                    Label("Function", systemImage: "function")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(functionName)
                        .font(.system(.body, design: .monospaced))
                }

                // Contract address
                VStack(alignment: .leading, spacing: 4) {
                    Label("Contract Address", systemImage: "building.2")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(transaction.to)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }

                // Parameters
                if let parameters = transaction.getContractParameters(), !parameters.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Parameters (\(parameters.count))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        ForEach(parameters) { param in
                            ParameterRow(parameter: param)
                        }
                    }
                }
            }
        }
    }

    private var dataSection: some View {
        Section("Raw Data") {
            if let data = transaction.data, !data.isEmpty {
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

    private var gasSection: some View {
        Section("Network Fee") {
            if let gasEstimate = transaction.gasEstimate {
                HStack {
                    Label("Estimated Gas", systemImage: "fuelpump")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(gasEstimate) units")
                }
            } else {
                Text("Gas estimate not available")
                    .foregroundColor(.secondary)
            }
        }
    }

    private var actionsSection: some View {
        Section {
            // Approve with FaceID
            Button(action: authenticateAndApprove) {
                HStack {
                    if isAuthenticating {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Image(systemName: "faceid")
                            .font(.system(size: 20))
                        Text("Approve with \(biometricHelper.biometricType())")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(isAuthenticating)
            .listRowBackground(Color.blue)
            .foregroundColor(.white)

            // Reject
            Button(action: rejectTransaction) {
                HStack {
                    Spacer()
                    Text("Reject")
                        .fontWeight(.semibold)
                    Spacer()
                }
            }
            .disabled(isAuthenticating)
            .foregroundColor(.red)
        }
    }

    // MARK: - Alert Properties

    private var alertTitle: String {
        if let result = authenticationResult {
            return result ? "Transaction Approved" : "Authentication Failed"
        }
        return "Transaction Rejected"
    }

    private var alertMessage: String {
        if let result = authenticationResult {
            return result
                ? "The transaction has been approved and will be broadcast to the network."
                : "Biometric authentication failed. Please try again."
        }
        return "The transaction has been rejected and will not be broadcast."
    }

    // MARK: - Actions

    private func authenticateAndApprove() {
        isAuthenticating = true

        // Use mock authentication for UI demo
        biometricHelper.mockAuthenticate(shouldSucceed: true, delay: 1.5) { success in
            isAuthenticating = false
            authenticationResult = success

            if success {}

            showingResultAlert = true
        }
    }

    private func rejectTransaction() {
        // Reject transaction (mock implementation)
        dismiss()
    }
}

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
        if parameter.type.lowercased().contains("address") {
            return TransactionFormatter.truncateAddress(parameter.value)
        }
        return parameter.value
    }
}

// MARK: - Preview

#Preview("ETH Transfer") {
    NavigationStack {
        SignTransactionView(transaction: .sampleETHTransfer)
    }
    .modelContainer(TransactionMockDataGenerator.createPreviewContainer())
}

#Preview("ERC20 Transfer") {
    NavigationStack {
        SignTransactionView(transaction: .sampleERC20Transfer)
    }
    .modelContainer(TransactionMockDataGenerator.createPreviewContainer())
}

#Preview("Complex Contract Call") {
    NavigationStack {
        SignTransactionView(transaction: .sampleSwap)
    }
    .modelContainer(TransactionMockDataGenerator.createPreviewContainer())
}

#Preview("Approve Transaction") {
    NavigationStack {
        SignTransactionView(transaction: .sampleApprove)
    }
    .modelContainer(TransactionMockDataGenerator.createPreviewContainer())
}
