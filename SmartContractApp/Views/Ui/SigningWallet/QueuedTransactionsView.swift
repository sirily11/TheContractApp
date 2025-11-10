//
//  QueuedTransactionsView.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import SwiftUI
import SwiftData

/// View displaying queued transactions awaiting signature
struct QueuedTransactionsView: View {

    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.walletSigner) private var walletSigner

    @Query(sort: \QueuedTransaction.queuedAt, order: .reverse)
    private var allTransactions: [QueuedTransaction]

    private var pendingTransactions: [QueuedTransaction] {
        allTransactions.filter { $0.status == .pending }
    }

    @State private var selectedTransaction: QueuedTransaction?
    @State private var showingSignView = false
    @State private var transactionToDelete: QueuedTransaction?
    @State private var showingDeleteAlert = false
    @State private var errorMessage: String?
    @State private var showingError = false

    // MARK: - Body

    var body: some View {
        Group {
            if pendingTransactions.isEmpty {
                emptyStateView
            } else {
                transactionList
            }
        }
        .navigationTitle("Queued Transactions")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }

            if !pendingTransactions.isEmpty {
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        rejectAllTransactions()
                    } label: {
                        Label("Reject All", systemImage: "xmark.circle.fill")
                    }
                }
            }
        }
        .sheet(item: $selectedTransaction) { transaction in
            NavigationStack {
                SignTransactionView(transaction: transaction)
            }
        }
        .alert("Reject Transaction", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                transactionToDelete = nil
            }
            Button("Reject", role: .destructive) {
                rejectTransaction()
            }
        } message: {
            Text("Are you sure you want to reject this transaction?")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Views

    private var transactionList: some View {
        List {
            Section {
                ForEach(pendingTransactions) { transaction in
                    Button(action: {
                        selectedTransaction = transaction
                    }) {
                        QueuedTransactionRowView(transaction: transaction)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            transactionToDelete = transaction
                            showingDeleteAlert = true
                        } label: {
                            Label("Reject", systemImage: "xmark.circle")
                        }
                    }
                }
            } header: {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Pending Signatures (\(pendingTransactions.count))")
                }
            } footer: {
                Text("Tap to review and sign, or swipe left to reject")
                    .font(.caption)
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Pending Transactions",
            systemImage: "checkmark.circle",
            description: Text("You don't have any transactions waiting for signature")
        )
    }

    // MARK: - Actions

    private func rejectTransaction() {
        guard let transaction = transactionToDelete else { return }

        do {
            if let walletSigner = walletSigner as? WalletSignerViewModel {
                // Use the view model if available
                try walletSigner.rejectTransaction(transaction)
            } else {
                // Fall back to direct manipulation
                transaction.reject()
            }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }

        transactionToDelete = nil
    }

    private func rejectAllTransactions() {
        Task {
            if let walletSigner = walletSigner {
                // Use the view model's cancelAllSigningRequests
                await walletSigner.cancelAllSigningRequests()
            } else {
                // Fall back to direct manipulation
                for transaction in pendingTransactions {
                    transaction.reject()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("With Queued Transactions") {
    NavigationStack {
        QueuedTransactionsView()
    }
    .modelContainer(TransactionMockDataGenerator.createPopulatedPreviewContainer())
}

#Preview("Empty State") {
    NavigationStack {
        QueuedTransactionsView()
    }
    .modelContainer(TransactionMockDataGenerator.createPreviewContainer())
}

#Preview("Many Transactions") {
    let container = {
        let container = TransactionMockDataGenerator.createPreviewContainer()
        let context = container.mainContext

        // Generate many queued transactions
        let transactions = TransactionMockDataGenerator.generateQueuedTransactions(count: 10)
        transactions.forEach { tx in
            context.insert(tx)
        }

        return container
    }()

    NavigationStack {
        QueuedTransactionsView()
    }
    .modelContainer(container)
}

#Preview("Single Transaction") {
    let container = {
        let container = TransactionMockDataGenerator.createPreviewContainer()
        let context = container.mainContext

        context.insert(QueuedTransaction.sampleERC20Transfer)

        return container
    }()

    NavigationStack {
        QueuedTransactionsView()
    }
    .modelContainer(container)
}
