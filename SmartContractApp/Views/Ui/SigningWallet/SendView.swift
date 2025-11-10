//
//  SendView.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import SwiftUI
import EvmCore
import BigInt

struct SendView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext

    // Dependencies
    let walletAddress: String
    let nativeTokenSymbol: String
    let nativeTokenName: String
    let nativeTokenDecimals: Int
    let balance: String

    // Step management
    @State var currentStep: SendStep = .selectAsset

    // Form data
    @State var selectedAsset: Asset?
    @State var recipientAddress: String = ""
    @State var amount: String = ""
    @State var gasEstimate: BigInt?
    @State var isEstimatingGas: Bool = false
    @State var estimateError: String?

    // Validation and error handling
    @State var showingError: Bool = false
    @State var errorMessage: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Step indicator
                stepIndicator

                Divider()

                // Step content
                switch currentStep {
                case .selectAsset:
                    selectAssetStep
                case .enterDetails:
                    enterDetailsStep
                case .review:
                    reviewStep
                }

                Spacer()

                // Navigation buttons
                navigationButtons
            }
            .navigationTitle("Send")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
        #if os(iOS)
        .presentationDetents([.large])
        #endif
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 12) {
            ForEach(SendStep.allCases, id: \.self) { step in
                HStack(spacing: 8) {
                    Circle()
                        .fill(step <= currentStep ? Color.blue : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)

                    Text(step.title)
                        .font(.caption)
                        .foregroundColor(step <= currentStep ? .primary : .secondary)
                }

                if step != SendStep.allCases.last {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 1)
                }
            }
        }
        .padding()
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if currentStep != .selectAsset {
                Button("Back") {
                    withAnimation {
                        currentStep = currentStep.previous ?? .selectAsset
                    }
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            if currentStep == .review {
                Button("Send") {
                    sendTransaction()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isReviewValid)
            } else {
                Button("Next") {
                    handleNext()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canProceed)
            }
        }
        .padding()
    }

    // MARK: - Validation

    var canProceed: Bool {
        switch currentStep {
        case .selectAsset:
            return selectedAsset != nil
        case .enterDetails:
            return isAddressValid && isAmountValid
        case .review:
            return true
        }
    }

    var isAddressValid: Bool {
        // Basic Ethereum address validation
        let trimmed = recipientAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("0x") && trimmed.count == 42
    }

    var isAmountValid: Bool {
        guard let amountValue = Double(amount), amountValue > 0 else {
            return false
        }
        guard let balanceValue = Double(balance) else {
            return false
        }
        return amountValue <= balanceValue
    }

    var isReviewValid: Bool {
        return isAddressValid && isAmountValid && gasEstimate != nil
    }

    // MARK: - Actions

    private func handleNext() {
        switch currentStep {
        case .selectAsset:
            // Auto-select native token
            if selectedAsset == nil {
                selectedAsset = Asset(
                    name: nativeTokenName,
                    symbol: nativeTokenSymbol,
                    balance: balance,
                    icon: "dollarsign.circle.fill",
                    color: .blue
                )
            }
            withAnimation {
                currentStep = .enterDetails
            }
        case .enterDetails:
            // Estimate gas before proceeding to review
            estimateGas()
        case .review:
            break
        }
    }

    private func estimateGas() {
        isEstimatingGas = true
        estimateError = nil

        // TODO: Implement gas estimation using EvmClient
        // For now, use a placeholder value
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            await MainActor.run {
                gasEstimate = BigInt(21000) // Standard ETH transfer gas
                isEstimatingGas = false
                withAnimation {
                    currentStep = .review
                }
            }
        }
    }

    private func sendTransaction() {
        // TODO: Implement transaction sending via WalletSignerViewModel
        // For now, just close the sheet
        isPresented = false
    }
}

// MARK: - Send Step Enum

enum SendStep: Int, CaseIterable, Comparable {
    case selectAsset = 0
    case enterDetails = 1
    case review = 2

    var title: String {
        switch self {
        case .selectAsset:
            return "Select"
        case .enterDetails:
            return "Details"
        case .review:
            return "Review"
        }
    }

    var next: SendStep? {
        SendStep(rawValue: self.rawValue + 1)
    }

    var previous: SendStep? {
        SendStep(rawValue: self.rawValue - 1)
    }

    static func < (lhs: SendStep, rhs: SendStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Asset Model (Temporary)

struct Asset: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let symbol: String
    let balance: String
    let icon: String
    let color: Color
}

// MARK: - Preview

#Preview {
    @Previewable @State var isPresented = true

    SendView(
        isPresented: $isPresented,
        walletAddress: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb0",
        nativeTokenSymbol: "ETH",
        nativeTokenName: "Ethereum",
        nativeTokenDecimals: 18,
        balance: "1.5"
    )
}
