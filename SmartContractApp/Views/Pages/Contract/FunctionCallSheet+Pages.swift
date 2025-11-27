//
//  FunctionCallSheet+Pages.swift
//  SmartContractApp
//
//  Created by Claude on 11/17/25.
//

import EvmCore
import SwiftUI

// MARK: - Page Views

extension FunctionCallSheet {
    // MARK: - Parameters Page

    /// First page: Parameter input form
    var parametersPage: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(function.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(contract.name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    stateMutabilityBadge
                }
                .padding()

                Divider()
            }

            ScrollView {
                VStack(spacing: 0) {
                    // Parameters form (or no parameters message)
                    if parameters.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.green)
                            Text("No Parameters Required")
                                .font(.headline)
                            Text("This function can be called without any parameters")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        TransactionParameterFormView(parameters: $parameters)
                    }

                    // Value input for payable functions
                    if isPayableFunction {
                        VStack(spacing: 0) {
                            Divider()
                                .padding(.vertical, 16)

                            VStack(alignment: .leading, spacing: 16) {
                                Text("Transaction Value")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                EthereumValueField(
                                    amount: $ethValue,
                                    selectedUnit: $selectedValueUnit,
                                    showLabel: false
                                )
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 16)
                        }
                    }
                }
            }
        }
        .navigationTitle("Call Function")
    }

    // MARK: - Confirmation Page

    /// Second page (write functions only): Confirm transaction
    var confirmationPage: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                Text("Confirm Transaction")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Review the transaction details before signing")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()

            // Transaction details
            List {
                Section("Function") {
                    LabeledContent("Name", value: function.name)
                    LabeledContent("Contract", value: contract.name)
                }

                if !parameters.isEmpty {
                    Section("Parameters") {
                        ForEach(Array(parameters.enumerated()), id: \.offset) { index, param in
                            LabeledContent(
                                param.name,
                                value: String(describing: param.value.value)
                            )
                        }
                    }
                }

                if isPayableFunction {
                    Section("Transaction Value") {
                        LabeledContent(
                            "Value",
                            value: selectedValueUnit.format(transactionValue)
                        )
                    }
                }

                Section("Network") {
                    if let endpoint = contract.endpoint {
                        LabeledContent("Endpoint", value: endpoint.name)
                        LabeledContent("Chain ID", value: endpoint.chainId)
                    }
                }
            }
        }
        .navigationTitle("Confirm")
    }

    // MARK: - Processing Page

    /// Third page: Show processing/waiting state
    var processingPage: some View {
        VStack(spacing: 24) {
            Spacer()

            // Loading indicator
            ProgressView()
                .scaleEffect(1.5)
                .padding()

            // Status message
            VStack(spacing: 8) {
                Text(processingTitle)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(processingMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Processing")
    }

    // MARK: - Result Page

    /// Fourth page: Show execution result
    var resultPage: some View {
        VStack(spacing: 20) {
            Spacer()

            // Result icon
            Image(systemName: resultIcon)
                .font(.system(size: 60))
                .foregroundColor(resultColor)
                .padding()

            // Result title
            Text(resultTitle)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(resultColor)
                .accessibilityIdentifier(executionState == .completed ? .functionCall.successMessage : .functionCall.errorMessage)

            // Result details
            if let result = result {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Result:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(result)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding(.horizontal)
            }

            if let txHash = transactionHash {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Transaction Hash:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(txHash)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding(.horizontal)
            }

            if let errorMessage = errorMessage {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Error:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding(.horizontal)
            }

            Spacer()
        }
        .navigationTitle(executionState == .completed ? "Success" : "Failed")
    }

    // MARK: - Helper Views

    private var stateMutabilityBadge: some View {
        Text(badgeText)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(badgeColor.opacity(0.2))
            .foregroundColor(badgeColor)
            .cornerRadius(8)
    }

    private var badgeText: String {
        switch function.stateMutability {
        case .view, .pure:
            return "Read"
        case .nonpayable:
            return "Write"
        case .payable:
            return "Payable"
        }
    }

    private var badgeColor: Color {
        switch function.stateMutability {
        case .view, .pure:
            return .green
        case .nonpayable:
            return .orange
        case .payable:
            return .red
        }
    }

    // MARK: - Processing State

    private var processingTitle: String {
        switch executionState {
        case .executing:
            return "Executing Function..."
        case .waitingForSignature:
            return "Waiting for Signature"
        default:
            return "Processing..."
        }
    }

    private var processingMessage: String {
        switch executionState {
        case .executing:
            if isReadFunction {
                return "Reading data from the blockchain..."
            } else {
                return "Preparing transaction..."
            }
        case .waitingForSignature:
            return "Please sign the transaction in your wallet"
        default:
            return "Please wait..."
        }
    }

    // MARK: - Result State

    private var resultIcon: String {
        executionState == .completed ? "checkmark.circle.fill" : "xmark.circle.fill"
    }

    private var resultColor: Color {
        executionState == .completed ? .green : .red
    }

    private var resultTitle: String {
        executionState == .completed ? "Success!" : "Failed"
    }

    // MARK: - Validation

    var canCallFunction: Bool {
        // For now, always allow calling
        // TODO: Add parameter validation
        return true
    }
}
