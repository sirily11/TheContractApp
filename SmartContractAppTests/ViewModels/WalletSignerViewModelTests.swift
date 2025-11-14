//
//  WalletSignerViewModelTests.swift
//  SmartContractAppTests
//
//  Created by Claude on 11/14/25.
//

import BigInt
import Combine
import EvmCore
import Foundation
import SwiftData
import Testing
@testable import SmartContractApp

struct WalletSignerViewModelTests {

    // MARK: - Test Infrastructure

    /// Create a test model context
    @MainActor private func createTestContext() -> ModelContext {
        let schema = Schema([
            Transaction.self,
            EVMWallet.self,
            Endpoint.self,
            EvmAbi.self,
            EVMConfig.self,
            EVMContract.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        return container.mainContext
    }

    /// Create a test wallet
    @MainActor private func createTestWallet(context: ModelContext) -> EVMWallet {
        let wallet = EVMWallet(
            alias: "Test Wallet",
            address: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
            keychainPath: "test/wallet/\(UUID().uuidString)"
        )
        context.insert(wallet)
        return wallet
    }

    /// Create a test transaction
    @MainActor private func createTestTransaction() -> QueuedTransaction {
        return QueuedTransaction(
            to: "0x1234567890abcdef1234567890abcdef12345678",
            value: .ether(.init(bigInt: BigInt(1))),
            data: nil,
            gasEstimate: "0x5208"
        )
    }

    // MARK: - Transaction Queue Management Tests

    @Test @MainActor func testQueueTransaction() async throws {
        let context = createTestContext()
        let wallet = createTestWallet(context: context)
        let viewModel = WalletSignerViewModel(modelContext: context, currentWallet: wallet)

        // Verify initial state
        #expect(viewModel.currentShowingTransactions.isEmpty)
        #expect(viewModel.pendingTransactionCount == 0)

        // Queue a transaction
        let queuedTx = try viewModel.queueTransaction(
            to: "0x1234567890abcdef1234567890abcdef12345678",
            value: .ether(.init(bigInt: BigInt(1)))
        )

        // Verify transaction was added
        #expect(viewModel.currentShowingTransactions.count == 1)
        #expect(viewModel.pendingTransactionCount == 1)
        #expect(viewModel.currentShowingTransactions.first?.id == queuedTx.id)
    }

    @Test @MainActor func testRejectTransactionRemovesFromQueue() async throws {
        let context = createTestContext()
        let wallet = createTestWallet(context: context)
        let viewModel = WalletSignerViewModel(modelContext: context, currentWallet: wallet)

        // Queue a transaction
        let queuedTx = try viewModel.queueTransaction(
            to: "0x1234567890abcdef1234567890abcdef12345678",
            value: .ether(.init(bigInt: BigInt(1)))
        )

        // Verify transaction is in queue
        #expect(viewModel.currentShowingTransactions.count == 1)
        #expect(viewModel.pendingTransactionCount == 1)

        // Reject the transaction
        try viewModel.rejectTransaction(queuedTx)

        // Verify transaction was removed
        #expect(viewModel.currentShowingTransactions.isEmpty)
        #expect(viewModel.pendingTransactionCount == 0)
    }

    @Test @MainActor func testRejectTransactionPublishesEvent() async throws {
        let context = createTestContext()
        let wallet = createTestWallet(context: context)
        let viewModel = WalletSignerViewModel(modelContext: context, currentWallet: wallet)

        // Set up event listener
        var receivedEvents: [TransactionEvent] = []
        let cancellable = viewModel.transactionEventPublisher.sink { event in
            receivedEvents.append(event)
        }
        defer { cancellable.cancel() }

        // Queue a transaction
        let queuedTx = try viewModel.queueTransaction(
            to: "0x1234567890abcdef1234567890abcdef12345678",
            value: .ether(.init(bigInt: BigInt(1)))
        )

        // Should have received queued event
        #expect(receivedEvents.count == 1)
        if case .queued(let tx) = receivedEvents[0] {
            #expect(tx.id == queuedTx.id)
        } else {
            Issue.record("Expected queued event")
        }

        // Reject the transaction
        try viewModel.rejectTransaction(queuedTx)

        // Should have received rejected event
        #expect(receivedEvents.count == 2)
        if case .rejected(let tx) = receivedEvents[1] {
            #expect(tx.id == queuedTx.id)
        } else {
            Issue.record("Expected rejected event")
        }
    }

    @Test @MainActor func testRejectMultipleTransactions() async throws {
        let context = createTestContext()
        let wallet = createTestWallet(context: context)
        let viewModel = WalletSignerViewModel(modelContext: context, currentWallet: wallet)

        // Queue multiple transactions
        let tx1 = try viewModel.queueTransaction(
            to: "0x1111111111111111111111111111111111111111",
            value: .ether(.init(bigInt: BigInt(1)))
        )
        let tx2 = try viewModel.queueTransaction(
            to: "0x2222222222222222222222222222222222222222",
            value: .ether(.init(bigInt: BigInt(2)))
        )
        let tx3 = try viewModel.queueTransaction(
            to: "0x3333333333333333333333333333333333333333",
            value: .ether(.init(bigInt: BigInt(3)))
        )

        // Verify all transactions are queued
        #expect(viewModel.currentShowingTransactions.count == 3)
        #expect(viewModel.pendingTransactionCount == 3)

        // Reject middle transaction
        try viewModel.rejectTransaction(tx2)

        // Verify correct transactions remain
        #expect(viewModel.currentShowingTransactions.count == 2)
        #expect(viewModel.pendingTransactionCount == 2)
        #expect(viewModel.currentShowingTransactions.contains(where: { $0.id == tx1.id }))
        #expect(viewModel.currentShowingTransactions.contains(where: { $0.id == tx3.id }))
        #expect(!viewModel.currentShowingTransactions.contains(where: { $0.id == tx2.id }))

        // Reject first transaction
        try viewModel.rejectTransaction(tx1)

        // Verify only last transaction remains
        #expect(viewModel.currentShowingTransactions.count == 1)
        #expect(viewModel.pendingTransactionCount == 1)
        #expect(viewModel.currentShowingTransactions.first?.id == tx3.id)

        // Reject last transaction
        try viewModel.rejectTransaction(tx3)

        // Verify queue is empty
        #expect(viewModel.currentShowingTransactions.isEmpty)
        #expect(viewModel.pendingTransactionCount == 0)
    }

    @Test @MainActor func testRejectNonExistentTransaction() async throws {
        let context = createTestContext()
        let wallet = createTestWallet(context: context)
        let viewModel = WalletSignerViewModel(modelContext: context, currentWallet: wallet)

        // Queue a transaction
        let queuedTx = try viewModel.queueTransaction(
            to: "0x1234567890abcdef1234567890abcdef12345678",
            value: .ether(.init(bigInt: BigInt(1)))
        )

        // Create a transaction that's not in the queue
        let nonExistentTx = QueuedTransaction(
            to: "0x9999999999999999999999999999999999999999",
            value: .ether(.init(bigInt: BigInt(1))),
            data: nil,
            gasEstimate: "0x5208"
        )

        // Verify initial state
        #expect(viewModel.currentShowingTransactions.count == 1)

        // Reject non-existent transaction (should not crash)
        try viewModel.rejectTransaction(nonExistentTx)

        // Verify original transaction is still in queue
        #expect(viewModel.currentShowingTransactions.count == 1)
        #expect(viewModel.currentShowingTransactions.first?.id == queuedTx.id)
    }

    @Test @MainActor func testRemoveTransactionFromQueue() async throws {
        let context = createTestContext()
        let wallet = createTestWallet(context: context)
        let viewModel = WalletSignerViewModel(modelContext: context, currentWallet: wallet)

        // Queue transactions
        let tx1 = try viewModel.queueTransaction(
            to: "0x1111111111111111111111111111111111111111",
            value: .ether(.init(bigInt: BigInt(1)))
        )
        let tx2 = try viewModel.queueTransaction(
            to: "0x2222222222222222222222222222222222222222",
            value: .ether(.init(bigInt: BigInt(2)))
        )

        #expect(viewModel.currentShowingTransactions.count == 2)

        // Remove first transaction
        viewModel.removeTransactionFromQueue(tx: tx1)

        // Verify removal
        #expect(viewModel.currentShowingTransactions.count == 1)
        #expect(viewModel.currentShowingTransactions.first?.id == tx2.id)
    }

    // MARK: - Event Publishing Tests

    @Test @MainActor func testQueueTransactionPublishesEvent() async throws {
        let context = createTestContext()
        let wallet = createTestWallet(context: context)
        let viewModel = WalletSignerViewModel(modelContext: context, currentWallet: wallet)

        // Set up event listener
        var receivedEvents: [TransactionEvent] = []
        let cancellable = viewModel.transactionEventPublisher.sink { event in
            receivedEvents.append(event)
        }
        defer { cancellable.cancel() }

        // Queue a transaction
        let queuedTx = try viewModel.queueTransaction(
            to: "0x1234567890abcdef1234567890abcdef12345678",
            value: .ether(.init(bigInt: BigInt(1)))
        )

        // Verify queued event was published
        #expect(receivedEvents.count == 1)
        if case .queued(let tx) = receivedEvents[0] {
            #expect(tx.id == queuedTx.id)
        } else {
            Issue.record("Expected queued event")
        }
    }
}
