//
//  SignTransactionView.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import BigInt
import EvmCore
import LocalAuthentication
import SwiftData
import SwiftUI

/// View for reviewing and signing a queued transaction
struct SignTransactionView: View {
    // MARK: - Properties

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Environment(WalletSignerViewModel.self) var walletSigner

    let transaction: QueuedTransaction

    // Local UI state (biometric authentication)
    @State var isAuthenticating = false
    @State var authenticationResult: Bool?

    // Gas estimation state
    @State var isEstimatingGas = false
    @State var estimatedGas: String?
    @State var gasEstimationError: String?

    @AppStorage("selectedEndpointId") private var selectedEndpointIdString: String = ""
    @AppStorage("selectedWalletId") private var selectedWalletIdString: String = ""

    @Query(sort: \Endpoint.name) private var endpoints: [Endpoint]
    @Query(sort: \EVMWallet.alias) private var wallets: [EVMWallet]

    let biometricHelper = BiometricAuthHelper()

    // MARK: - Computed Properties

    private var selectedEndpointId: UUID? {
        UUID(uuidString: selectedEndpointIdString)
    }

    private var selectedWalletId: UUID? {
        UUID(uuidString: selectedWalletIdString)
    }

    var selectedEndpoint: Endpoint? {
        if let id = selectedEndpointId {
            return endpoints.first { $0.id == id }
        }
        return endpoints.first
    }

    var selectedWallet: EVMWallet? {
        if let id = selectedWalletId {
            return wallets.first { $0.id == id }
        }
        return wallets.first
    }

    // MARK: - Body

    var body: some View {
        Group {
            if walletSigner.isProcessingTransaction {
                // Show pending screen while processing on-chain
                TransactionPendingView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .id("pending")
            } else {
                // Show transaction details form
                Form {
                    // Result section (shown after transaction is processed)
                    if authenticationResult != nil {
                        resultSection
                    } else {
                        // Warning section (shown before transaction is processed)
                        warningSection
                    }

                    // Transaction details
                    transactionSection

                    // Endpoint/Network info (if available)
                    endpointSection

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
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .id("form")
            }
        }
        .animation(.easeInOut(duration: 0.3), value: walletSigner.isProcessingTransaction)
        .navigationTitle("Sign Transaction")
        .task {
            await estimateGasFee()
        }
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
