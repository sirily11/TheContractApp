//
//  TransactionFilterBar.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import SwiftUI

/// Filter options for transaction list
enum TransactionFilter: String, CaseIterable {
    case all = "All"
    case sent = "Sent"
    case received = "Received"
    case contracts = "Contracts"

    var icon: String {
        switch self {
        case .all:
            return "list.bullet"
        case .sent:
            return "arrow.up.circle"
        case .received:
            return "arrow.down.circle"
        case .contracts:
            return "doc.text"
        }
    }
}

/// Filter bar for transaction history
struct TransactionFilterBar: View {
    // MARK: - Properties

    @Binding var selectedFilter: TransactionFilter

    // MARK: - Body

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TransactionFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        filter: filter,
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
    }
}

// MARK: - Filter Chip Component

private struct FilterChip: View {
    let filter: TransactionFilter
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.system(size: 14))

                Text(filter.rawValue)
                    .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        isSelected ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.1)
    }

    private var foregroundColor: Color {
        isSelected ? .blue : .primary
    }

    private var borderColor: Color {
        isSelected ? .blue.opacity(0.3) : .clear
    }
}

// MARK: - Preview

#Preview("All Selected") {
    @Previewable @State var filter: TransactionFilter = .all

    VStack {
        TransactionFilterBar(selectedFilter: $filter)

        Text("Selected: \(filter.rawValue)")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding()

        Spacer()
    }
    .frame(width: 400)
}

#Preview("Sent Selected") {
    @Previewable @State var filter: TransactionFilter = .sent

    TransactionFilterBar(selectedFilter: $filter)
        .frame(width: 400)
}

#Preview("Contracts Selected") {
    @Previewable @State var filter: TransactionFilter = .contracts

    TransactionFilterBar(selectedFilter: $filter)
        .frame(width: 400)
}

#Preview("Interactive") {
    @Previewable @State var filter: TransactionFilter = .all

    VStack(spacing: 20) {
        TransactionFilterBar(selectedFilter: $filter)

        Text("Current Filter: \(filter.rawValue)")
            .font(.headline)

        List {
            Text("Transaction 1")
            Text("Transaction 2")
            Text("Transaction 3")
        }
    }
}
