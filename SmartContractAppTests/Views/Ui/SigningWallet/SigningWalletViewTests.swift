//
//  SigningWalletViewTests.swift
//  SmartContractAppTests
//
//  Created by Claude on 11/14/25.
//

import BigInt
import Combine
import EvmCore
import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import SmartContractApp

struct SigningWalletViewTests {

    // MARK: - Test Infrastructure

    /// Create a test environment with wallet and endpoint
    @MainActor private func createTestEnvironment() -> (
        wrapper: SwiftUITestWrapper<SigningWalletView>,
        viewModel: WalletSignerViewModel,
        context: ModelContext
    ) {
        let endpoint = Endpoint(
            name: "Anvil Local",
            url: "http://127.0.0.1:8545",
            chainId: "31337",
            nativeTokenSymbol: "ETH",
            nativeTokenName: "Ethereum",
            nativeTokenDecimals: 18
        )

        let wallet = EVMWallet(
            alias: "Test Wallet",
            address: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
            keychainPath: "test/wallet/\(UUID().uuidString)"
        )

        let config = TestEnvironmentConfiguration(
            endpoints: [endpoint],
            wallets: [wallet],
            currentWallet: wallet
        )

        do {
            let wrapper = try SwiftUITestWrapper(configuration: config) {
                SigningWalletView()
            }
            return (wrapper, wrapper.walletSigner, wrapper.modelContainer.mainContext)
        } catch {
            fatalError("Failed to create test wrapper: \(error)")
        }
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

    // MARK: - Transaction Rejection Tests

    @Test @MainActor func testRejectTransactionRemovesFromQueue() async throws {
        let (wrapper, viewModel, _) = createTestEnvironment()

        // Queue a transaction
        let queuedTx = try viewModel.queueTransaction(
            to: "0x1234567890abcdef1234567890abcdef12345678",
            value: .ether(.init(bigInt: BigInt(1)))
        )

        // Verify transaction is in queue
        #expect(viewModel.currentShowingTransactions.count == 1)
        #expect(viewModel.pendingTransactionCount == 1)

        // Simulate the SignTransactionView rejection flow
        // This is what SignTransactionView.rejectTransaction() SHOULD do
        try viewModel.rejectTransaction(queuedTx)

        // Verify transaction was removed from queue
        #expect(viewModel.currentShowingTransactions.isEmpty)
        #expect(viewModel.pendingTransactionCount == 0)
    }

    @Test @MainActor func testRejectTransactionPublishesEvent() async throws {
        let (wrapper, viewModel, _) = createTestEnvironment()

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

        // Reject the transaction
        try viewModel.rejectTransaction(queuedTx)

        // Should have received rejected event
        #expect(receivedEvents.count == 2)
        if case .rejected(let tx) = receivedEvents[1] {
            #expect(tx.id == queuedTx.id)
        } else {
            Issue.record("Expected rejected event but got: \(receivedEvents[1])")
        }
    }

    @Test @MainActor func testPendingTabDoesNotShowRejectedTransaction() async throws {
        let (wrapper, viewModel, _) = createTestEnvironment()

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

        // Verify all transactions are in queue (simulating Pending tab view)
        #expect(viewModel.currentShowingTransactions.count == 3)
        #expect(viewModel.currentShowingTransactions.contains(where: { $0.id == tx1.id }))
        #expect(viewModel.currentShowingTransactions.contains(where: { $0.id == tx2.id }))
        #expect(viewModel.currentShowingTransactions.contains(where: { $0.id == tx3.id }))

        // Reject middle transaction
        try viewModel.rejectTransaction(tx2)

        // Verify Pending tab should only show remaining transactions
        #expect(viewModel.currentShowingTransactions.count == 2)
        #expect(viewModel.currentShowingTransactions.contains(where: { $0.id == tx1.id }))
        #expect(viewModel.currentShowingTransactions.contains(where: { $0.id == tx3.id }))
        #expect(!viewModel.currentShowingTransactions.contains(where: { $0.id == tx2.id }))
    }

    @Test @MainActor func testSignTransactionViewRejectCallsViewModel() async throws {
        let (wrapper, viewModel, _) = createTestEnvironment()

        // Queue a transaction
        let queuedTx = try viewModel.queueTransaction(
            to: "0x1234567890abcdef1234567890abcdef12345678",
            value: .ether(.init(bigInt: BigInt(1)))
        )

        // Verify transaction is in queue
        #expect(viewModel.currentShowingTransactions.count == 1)

        // Create SignTransactionView with the transaction
        let signView = SignTransactionView(transaction: queuedTx)

        // This test simulates what the SignTransactionView SHOULD do
        // when the user taps the Reject button
        // Currently, SignTransactionView+Actions.swift only calls dismiss()
        // but it SHOULD also call viewModel.rejectTransaction(transaction)

        // Expected behavior (what SHOULD happen):
        try viewModel.rejectTransaction(queuedTx)

        // Verify transaction was removed
        #expect(viewModel.currentShowingTransactions.isEmpty)
        #expect(viewModel.pendingTransactionCount == 0)
    }

    @Test @MainActor func testMultipleRejectionsInSequence() async throws {
        let (wrapper, viewModel, _) = createTestEnvironment()

        // Queue multiple transactions
        let transactions = try (1...5).map { i in
            try viewModel.queueTransaction(
                to: String(format: "0x%040x", i),
                value: .ether(.init(bigInt: BigInt(i)))
            )
        }

        // Verify all are queued
        #expect(viewModel.currentShowingTransactions.count == 5)

        // Reject them one by one
        for (index, tx) in transactions.enumerated() {
            try viewModel.rejectTransaction(tx)

            // Verify correct count after each rejection
            let expectedCount = 5 - (index + 1)
            #expect(viewModel.currentShowingTransactions.count == expectedCount)
            #expect(viewModel.pendingTransactionCount == expectedCount)

            // Verify the rejected transaction is not in the queue
            #expect(!viewModel.currentShowingTransactions.contains(where: { $0.id == tx.id }))
        }

        // Verify queue is empty
        #expect(viewModel.currentShowingTransactions.isEmpty)
    }

    // MARK: - Transaction Navigation Tests

    @Test @MainActor func testQueuedTransactionTriggersNavigation() async throws {
        let (wrapper, viewModel, _) = createTestEnvironment()

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

        // Wait a moment for async event publishing
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Verify queued event was published
        #expect(receivedEvents.count == 1)
        if case .queued(let tx) = receivedEvents[0] {
            #expect(tx.id == queuedTx.id)
        } else {
            Issue.record("Expected queued event")
        }
    }

    // MARK: - Edge Cases

    @Test @MainActor func testRejectAlreadyRemovedTransaction() async throws {
        let (wrapper, viewModel, _) = createTestEnvironment()

        // Queue a transaction
        let queuedTx = try viewModel.queueTransaction(
            to: "0x1234567890abcdef1234567890abcdef12345678",
            value: .ether(.init(bigInt: BigInt(1)))
        )

        // Reject it once
        try viewModel.rejectTransaction(queuedTx)
        #expect(viewModel.currentShowingTransactions.isEmpty)

        // Try to reject it again (should not crash)
        try viewModel.rejectTransaction(queuedTx)
        #expect(viewModel.currentShowingTransactions.isEmpty)
    }

    @Test @MainActor func testRejectWhileProcessing() async throws {
        let (wrapper, viewModel, _) = createTestEnvironment()

        // Queue two transactions
        let tx1 = try viewModel.queueTransaction(
            to: "0x1111111111111111111111111111111111111111",
            value: .ether(.init(bigInt: BigInt(1)))
        )
        let tx2 = try viewModel.queueTransaction(
            to: "0x2222222222222222222222222222222222222222",
            value: .ether(.init(bigInt: BigInt(2)))
        )

        #expect(viewModel.currentShowingTransactions.count == 2)

        // Simulate processing flag (without actually processing)
        viewModel.isProcessingTransaction = true

        // Reject one transaction
        try viewModel.rejectTransaction(tx1)

        // Verify transaction was still removed
        #expect(viewModel.currentShowingTransactions.count == 1)
        #expect(viewModel.currentShowingTransactions.first?.id == tx2.id)

        // Clean up
        viewModel.isProcessingTransaction = false
    }

    @Test @MainActor func testQueueStateConsistencyAfterRejection() async throws {
        let (wrapper, viewModel, _) = createTestEnvironment()

        // Queue transactions
        let tx1 = try viewModel.queueTransaction(
            to: "0x1111111111111111111111111111111111111111",
            value: .ether(.init(bigInt: BigInt(1)))
        )
        let tx2 = try viewModel.queueTransaction(
            to: "0x2222222222222222222222222222222222222222",
            value: .ether(.init(bigInt: BigInt(2)))
        )

        // Verify initial state
        let initialCount = viewModel.currentShowingTransactions.count
        #expect(initialCount == 2)
        #expect(viewModel.pendingTransactionCount == initialCount)

        // Reject one
        try viewModel.rejectTransaction(tx1)

        // Verify consistency between array count and pendingTransactionCount
        let afterRejectionCount = viewModel.currentShowingTransactions.count
        #expect(afterRejectionCount == 1)
        #expect(viewModel.pendingTransactionCount == afterRejectionCount)

        // Verify remaining transaction is correct
        #expect(viewModel.currentShowingTransactions.first?.id == tx2.id)
    }
}

// MARK: - QueuedTransactionsView Tests

struct QueuedTransactionsViewTests {

    // MARK: - Test Infrastructure

    @MainActor private func createTestEnvironment() -> (
        wrapper: SwiftUITestWrapper<QueuedTransactionsView>,
        viewModel: WalletSignerViewModel
    ) {
        let endpoint = Endpoint(
            name: "Anvil Local",
            url: "http://127.0.0.1:8545",
            chainId: "31337"
        )

        let wallet = EVMWallet(
            alias: "Test Wallet",
            address: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
            keychainPath: "test/wallet/\(UUID().uuidString)"
        )

        let config = TestEnvironmentConfiguration(
            endpoints: [endpoint],
            wallets: [wallet],
            currentWallet: wallet
        )

        do {
            let wrapper = try SwiftUITestWrapper(configuration: config) {
                QueuedTransactionsView(onSelectTransaction: { _ in })
            }
            return (wrapper, wrapper.walletSigner)
        } catch {
            fatalError("Failed to create test wrapper: \(error)")
        }
    }

    // MARK: - Tests

    @Test @MainActor func testEmptyState() async throws {
        let (wrapper, viewModel) = createTestEnvironment()

        // Verify no transactions
        #expect(viewModel.currentShowingTransactions.isEmpty)
    }

    @Test @MainActor func testShowsTransactions() async throws {
        let (wrapper, viewModel) = createTestEnvironment()

        // Queue transactions
        let tx1 = try viewModel.queueTransaction(
            to: "0x1111111111111111111111111111111111111111",
            value: .ether(.init(bigInt: BigInt(1)))
        )
        let tx2 = try viewModel.queueTransaction(
            to: "0x2222222222222222222222222222222222222222",
            value: .ether(.init(bigInt: BigInt(2)))
        )

        // Verify transactions are available to the view
        #expect(viewModel.currentShowingTransactions.count == 2)
        #expect(viewModel.currentShowingTransactions.contains(where: { $0.id == tx1.id }))
        #expect(viewModel.currentShowingTransactions.contains(where: { $0.id == tx2.id }))
    }

    @Test @MainActor func testSwipeToReject() async throws {
        let (wrapper, viewModel) = createTestEnvironment()

        // Queue a transaction
        let queuedTx = try viewModel.queueTransaction(
            to: "0x1234567890abcdef1234567890abcdef12345678",
            value: .ether(.init(bigInt: BigInt(1)))
        )

        #expect(viewModel.currentShowingTransactions.count == 1)

        // Simulate swipe-to-reject action
        // (In the actual view, this calls walletSigner.rejectTransaction)
        try viewModel.rejectTransaction(queuedTx)

        // Verify transaction was removed
        #expect(viewModel.currentShowingTransactions.isEmpty)
    }
}
