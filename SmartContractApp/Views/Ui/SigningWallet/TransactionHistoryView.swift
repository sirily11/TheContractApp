//
//  TransactionHistoryView.swift
//  SmartContractApp
//
//  Created by bard on 11/10/25.
//

import SwiftData
import SwiftUI

/// View displaying transaction history with filtering and pagination
struct TransactionHistoryView: View {
    // MARK: - Properties

    @Query(sort: \Transaction.timestamp, order: .reverse)
    private var allTransactions: [Transaction]

    @State private var selectedFilter: TransactionFilter = .all
    @State private var itemsPerPage = 20
    @State private var currentPage = 0

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Filter bar
            TransactionFilterBar(selectedFilter: $selectedFilter)

            // Transaction list
            if filteredTransactions.isEmpty {
                emptyStateView
                Spacer()
            } else {
                transactionList
            }
        }
    }

    // MARK: - Views

    private var transactionList: some View {
        List {
            ForEach(paginatedTransactions) { transaction in
                NavigationLink(value: transaction) {
                    TransactionRowView(transaction: transaction)
                }
            }

            // Load more section
            if hasMorePages {
                loadMoreSection
            }
        }
        #if os(iOS)
        .listStyle(.plain)
        #else
        .listStyle(.sidebar)
        #endif
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Transactions",
            systemImage: "tray",
            description: Text(emptyStateDescription)
        )
    }

    private var loadMoreSection: some View {
        HStack {
            Spacer()
            Button("Load More") {
                loadMore()
            }
            .buttonStyle(.bordered)
            .padding(.vertical, 8)
            Spacer()
        }
        .listRowSeparator(.hidden)
    }

    // MARK: - Computed Properties

    private var filteredTransactions: [Transaction] {
        switch selectedFilter {
        case .all:
            return allTransactions
        case .sent:
            return allTransactions.filter { $0.type == .send }
        case .received:
            return allTransactions.filter { $0.type == .receive }
        case .contracts:
            return allTransactions.filter { $0.type == .contractCall }
        }
    }

    private var paginatedTransactions: [Transaction] {
        let endIndex = min((currentPage + 1) * itemsPerPage, filteredTransactions.count)
        return Array(filteredTransactions.prefix(endIndex))
    }

    private var hasMorePages: Bool {
        paginatedTransactions.count < filteredTransactions.count
    }

    private var emptyStateDescription: LocalizedStringKey {
        switch selectedFilter {
        case .all:
            return "You haven't made any transactions yet"
        case .sent:
            return "You haven't sent any transactions"
        case .received:
            return "You haven't received any transactions"
        case .contracts:
            return "You haven't interacted with any contracts"
        }
    }

    // MARK: - Actions

    private func loadMore() {
        currentPage += 1
    }
}

// MARK: - Preview

#Preview("With Transactions") {
    NavigationStack {
        TransactionHistoryView()
            .navigationTitle("History")
    }
    .modelContainer(TransactionMockDataGenerator.createPopulatedPreviewContainer())
}

#Preview("Empty State") {
    NavigationStack {
        TransactionHistoryView()
            .navigationTitle("History")
    }
    .modelContainer(TransactionMockDataGenerator.createPreviewContainer())
}

#Preview("Many Transactions") {
    let container = {
        let container = TransactionMockDataGenerator.createPreviewContainer()
        let context = container.mainContext

        // Generate 50 transactions for pagination testing
        let transactions = TransactionMockDataGenerator.generateTransactions(
            count: 50,
            walletAddress: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
        )

        for transaction in transactions {
            context.insert(transaction)
        }

        return container
    }()

    NavigationStack {
        TransactionHistoryView()
            .navigationTitle("History")
    }
    .modelContainer(container)
}

#Preview("Filtered - Sent Only") {
    @Previewable @State var filter: TransactionFilter = .sent

    NavigationStack {
        VStack {
            TransactionFilterBar(selectedFilter: $filter)
            TransactionHistoryView()
        }
        .navigationTitle("History")
    }
    .modelContainer(TransactionMockDataGenerator.createPopulatedPreviewContainer())
}
