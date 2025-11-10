//
//  QueuedTransactionsView.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import SwiftData
import SwiftUI

/// View displaying queued transactions awaiting signature
struct QueuedTransactionsView: View {
    // MARK: - Properties

    @Binding var navigationPath: [QueuedTransaction]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(WalletSignerViewModel.self) private var walletSigner

    @State private var transactionToDelete: QueuedTransaction?
    @State private var showingDeleteAlert = false
    @State private var errorMessage: String?
    @State private var showingError = false

    // MARK: - Body

    var body: some View {
        Group {
            if walletSigner.currentShowingTransactions.isEmpty {
                emptyStateView
            } else {
                transactionList
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }

            if !walletSigner.currentShowingTransactions.isEmpty {
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        rejectAllTransactions()
                    } label: {
                        Label("Reject All", systemImage: "xmark.circle.fill")
                    }
                }
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
        LazyVStack {
            ForEach(walletSigner.currentShowingTransactions) { transaction in
                QueuedTransactionRowView(transaction: transaction)
                    .onTapGesture { _ in
                        navigationPath.append(transaction)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            transactionToDelete = transaction
                            showingDeleteAlert = true
                        } label: {
                            Label("Reject", systemImage: "xmark.circle")
                        }
                    }
            }
        }
        .padding(.horizontal)
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
            try walletSigner.rejectTransaction(transaction)
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }

        transactionToDelete = nil
    }

    private func rejectAllTransactions() {
        Task {
            await walletSigner.cancelAllSigningRequests()
        }
    }
}

// MARK: - Preview

#Preview("With Queued Transactions") {
    @Previewable @State var navigationPath: [QueuedTransaction] = []

    NavigationStack(path: $navigationPath) {
        QueuedTransactionsView(navigationPath: $navigationPath)
            .navigationDestination(for: QueuedTransaction.self) { tx in
                SignTransactionView(transaction: tx)
            }
    }
    .modelContainer(TransactionMockDataGenerator.createPopulatedPreviewContainer())
}

#Preview("Empty State") {
    @Previewable @State var navigationPath: [QueuedTransaction] = []

    NavigationStack(path: $navigationPath) {
        QueuedTransactionsView(navigationPath: $navigationPath)
            .navigationDestination(for: QueuedTransaction.self) { tx in
                SignTransactionView(transaction: tx)
            }
    }
    .modelContainer(TransactionMockDataGenerator.createPreviewContainer())
}
