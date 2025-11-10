//
//  TransactionMockDataGenerator.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import Foundation
import SwiftData
import SwiftUI

/// Utility for generating mock transaction data for previews and testing
struct TransactionMockDataGenerator {

    // MARK: - Preview Container

    /// Creates an in-memory model container for SwiftUI previews
    @MainActor
    static func createPreviewContainer() -> ModelContainer {
        let schema = Schema([
            Transaction.self,
            QueuedTransaction.self,
            EVMWallet.self
        ])

        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)

        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            return container
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }

    /// Creates a populated preview container with sample data
    @MainActor
    static func createPopulatedPreviewContainer() -> ModelContainer {
        let container = createPreviewContainer()
        let context = container.mainContext

        // Insert sample transactions
        Transaction.allSamples.forEach { transaction in
            context.insert(transaction)
        }

        // Insert sample queued transactions
        QueuedTransaction.allPending.forEach { queuedTx in
            context.insert(queuedTx)
        }

        return container
    }

    // MARK: - Batch Transaction Generation

    /// Generates multiple transactions for testing pagination
    /// - Parameters:
    ///   - count: Number of transactions to generate
    ///   - walletAddress: Wallet address for the transactions
    /// - Returns: Array of generated transactions
    static func generateTransactions(count: Int, walletAddress: String = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb") -> [Transaction] {
        var transactions: [Transaction] = []

        for i in 0..<count {
            let types: [TransactionType] = [.send, .receive, .contractCall]
            let statuses: [TransactionStatus] = [.success, .success, .success, .pending, .failed]

            let type = types.randomElement()!
            let status = statuses.randomElement()!

            // Random timestamp within last 30 days
            let randomTimeInterval = TimeInterval.random(in: 0...(30 * 24 * 60 * 60))
            let timestamp = Date().addingTimeInterval(-randomTimeInterval)

            let isOutgoing = type == .send || (type == .contractCall && Bool.random())
            let from = isOutgoing ? walletAddress : randomAddress()
            let to = isOutgoing ? randomAddress() : walletAddress

            // Random value between 0.01 and 10 ETH
            let ethValue = Double.random(in: 0.01...10.0)
            let weiValue = String(format: "%.0f", ethValue * 1e18)

            let transaction = Transaction(
                hash: randomHash(),
                type: type,
                from: from,
                to: to,
                value: weiValue,
                timestamp: timestamp,
                status: status,
                blockNumber: status == .success ? Int.random(in: 18_000_000...18_500_000) : nil,
                gasUsed: status != .pending ? String(Int.random(in: 21000...200000)) : nil,
                gasPrice: String(Int.random(in: 20_000_000_000...50_000_000_000)),
                contractFunctionName: type == .contractCall ? randomFunctionName() : nil,
                contractParameters: type == .contractCall ? randomParameters() : nil
            )

            transactions.append(transaction)
        }

        return transactions.sorted { $0.timestamp > $1.timestamp }
    }

    /// Generates multiple queued transactions for testing
    /// - Parameter count: Number of queued transactions to generate
    /// - Returns: Array of generated queued transactions
    static func generateQueuedTransactions(count: Int) -> [QueuedTransaction] {
        var transactions: [QueuedTransaction] = []

        for i in 0..<count {
            let isContractCall = Bool.random()
            let ethValue = Double.random(in: 0...5.0)
            let weiValue = String(format: "%.0f", ethValue * 1e18)

            // Random queue time within last hour
            let randomTimeInterval = TimeInterval.random(in: 0...3600)
            let queuedAt = Date().addingTimeInterval(-randomTimeInterval)

            let transaction = QueuedTransaction(
                queuedAt: queuedAt,
                to: randomAddress(),
                value: weiValue,
                data: isContractCall ? randomData() : nil,
                gasEstimate: String(Int.random(in: 21000...200000)),
                contractFunctionName: isContractCall ? randomFunctionName() : nil,
                contractParameters: isContractCall ? randomParameters() : nil,
                status: .pending
            )

            transactions.append(transaction)
        }

        return transactions.sorted { $0.queuedAt > $1.queuedAt }
    }

    // MARK: - Random Data Generators

    static func randomAddress() -> String {
        let hex = "0123456789abcdef"
        var address = "0x"
        for _ in 0..<40 {
            address.append(hex.randomElement()!)
        }
        return address
    }

    static func randomHash() -> String {
        let hex = "0123456789abcdef"
        var hash = "0x"
        for _ in 0..<64 {
            hash.append(hex.randomElement()!)
        }
        return hash
    }

    private static func randomData() -> String {
        let hex = "0123456789abcdef"
        var data = "0x"
        let length = Int.random(in: 8...128) * 2  // Even number
        for _ in 0..<length {
            data.append(hex.randomElement()!)
        }
        return data
    }

    private static func randomFunctionName() -> String {
        let functions = [
            "transfer",
            "approve",
            "transferFrom",
            "mint",
            "burn",
            "swap",
            "swapExactETHForTokens",
            "swapTokensForExactETH",
            "addLiquidity",
            "removeLiquidity",
            "stake",
            "unstake",
            "claim",
            "deposit",
            "withdraw"
        ]
        return functions.randomElement()!
    }

    private static func randomParameters() -> Data? {
        let parameters = [
            TransactionParameter(name: "to", type: "address", value: randomAddress()),
            TransactionParameter(name: "amount", type: "uint256", value: String(Int.random(in: 100...10000)))
        ]

        return try? JSONEncoder().encode(parameters)
    }
}

// MARK: - SwiftUI Preview Helper

#Preview("Mock Transaction Data") {
    VStack(spacing: 20) {
        Text("Sample Addresses")
            .font(.headline)

        ForEach(0..<5, id: \.self) { _ in
            Text(TransactionMockDataGenerator.randomAddress())
                .font(.system(.caption, design: .monospaced))
        }

        Divider()

        Text("Sample Hashes")
            .font(.headline)

        ForEach(0..<3, id: \.self) { _ in
            Text(TransactionMockDataGenerator.randomHash())
                .font(.system(.caption2, design: .monospaced))
        }
    }
    .padding()
}
