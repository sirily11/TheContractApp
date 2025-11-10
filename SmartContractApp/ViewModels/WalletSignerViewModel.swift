//
//  WalletSignerViewModel.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import EvmCore
import Foundation
import Observation
import SwiftData
import BigInt

@Observable
final class WalletSignerViewModel: WalletSigner {
    // MARK: - Properties

    private let modelContext: ModelContext
    private var continuation: AsyncStream<Data>.Continuation?

    /// The currently selected wallet for signing
    var currentWallet: EVMWallet?

    /// Number of pending transactions waiting for signature
    var pendingTransactionCount: Int {
        let descriptor = FetchDescriptor<QueuedTransaction>()
        guard let allTransactions = try? modelContext.fetch(descriptor) else {
            return 0
        }
        return allTransactions.filter { $0.status == .pending }.count
    }

    // MARK: - WalletSigner Protocol

    var walletSigner: Signer {
        get {
            guard let wallet = currentWallet else {
                fatalError("No wallet selected for signing")
            }

            guard let privateKey = try? wallet.getPrivateKey() else {
                fatalError("Failed to retrieve private key from keychain")
            }

            guard let signer = try? PrivateKeySigner(hexPrivateKey: privateKey) else {
                fatalError("Failed to create signer from private key")
            }

            return signer
        }
    }

    var signingRequestStream: AsyncStream<Data> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    // MARK: - Initialization

    init(modelContext: ModelContext, currentWallet: EVMWallet? = nil) {
        self.modelContext = modelContext
        self.currentWallet = currentWallet
    }

    // MARK: - Queue Management

    /// Queue a new signing request
    /// - Parameter tx: Transaction data to sign
    /// - Returns: The signed transaction data
    func queueSigningRequest(tx: Data) async throws -> Data {
        // Notify stream listeners
        continuation?.yield(tx)

        // For now, this creates a queued transaction and waits for user approval
        // In a real implementation, this would:
        // 1. Create a QueuedTransaction in the database
        // 2. Wait for user approval via the UI
        // 3. Return the signed data once approved

        throw WalletSignerError.notImplemented
    }

    /// Sign and send a transaction with progress updates
    /// - Parameter tx: Transaction data to sign and send
    /// - Returns: AsyncThrowingStream with signing progress updates
    func signAndSend(tx: Data) -> AsyncThrowingStream<SigningProgress, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    continuation.yield(.preparing)

                    // Get the signer
                    let signer = self.walletSigner

                    continuation.yield(.signing)

                    // Sign the transaction
                    let signature = try await signer.sign(message: tx)

                    // Combine transaction data with signature
                    var signedData = tx
                    signedData.append(signature)

                    // In a real implementation, this would send the transaction to the network
                    // and return the transaction hash
                    // For now, we'll just complete with the signed data

                    continuation.yield(.completed(signedData: signedData))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Cancel all pending signing requests
    func cancelAllSigningRequests() async {
        let descriptor = FetchDescriptor<QueuedTransaction>()

        do {
            let allTransactions = try modelContext.fetch(descriptor)
            let pendingTransactions = allTransactions.filter { $0.status == .pending }

            for transaction in pendingTransactions {
                transaction.reject()
            }
            try modelContext.save()
        } catch {
            print("Error canceling all signing requests: \(error)")
        }
    }

    /// Cancel a specific signing request by index
    /// - Parameter index: The index of the transaction to cancel
    func cancelSigningRequest(at index: Int) async {
        let descriptor = FetchDescriptor<QueuedTransaction>(
            sortBy: [SortDescriptor(\.queuedAt, order: .forward)]
        )

        do {
            let allTransactions = try modelContext.fetch(descriptor)
            let pendingTransactions = allTransactions.filter { $0.status == .pending }

            guard index >= 0 && index < pendingTransactions.count else {
                print("Invalid index: \(index)")
                return
            }

            pendingTransactions[index].reject()
            try modelContext.save()
        } catch {
            print("Error canceling signing request at index \(index): \(error)")
        }
    }

    // MARK: - Helper Methods

    /// Get all pending transactions
    func getPendingTransactions() throws -> [QueuedTransaction] {
        let descriptor = FetchDescriptor<QueuedTransaction>(
            sortBy: [SortDescriptor(\.queuedAt, order: .forward)]
        )

        let allTransactions = try modelContext.fetch(descriptor)
        return allTransactions.filter { $0.status == .pending }
    }

    /// Approve a transaction and sign it
    /// - Parameter transaction: The transaction to approve
    func approveTransaction(_ transaction: QueuedTransaction) async throws {
        guard currentWallet != nil else {
            throw WalletSignerError.noWalletSelected
        }

        transaction.approve()
        try modelContext.save()

        // In a real implementation, this would:
        // 1. Create the transaction object from QueuedTransaction data
        // 2. Sign it using the wallet signer
        // 3. Send it to the network
        // 4. Create a Transaction record with the hash
        // 5. Delete or mark the QueuedTransaction as processed
    }

    /// Reject a transaction
    /// - Parameter transaction: The transaction to reject
    func rejectTransaction(_ transaction: QueuedTransaction) throws {
        transaction.reject()
        try modelContext.save()
    }

    // MARK: - Transaction Sending

    /// Estimate gas for a transaction
    /// - Parameters:
    ///   - to: Recipient address
    ///   - value: Amount to send in wei
    ///   - endpoint: RPC endpoint to use for estimation
    /// - Returns: Estimated gas limit
    func estimateGas(to: String, value: BigInt, endpoint: Endpoint) async throws -> BigInt {
        guard let endpointUrl = URL(string: endpoint.url) else {
            throw WalletSignerError.invalidEndpoint
        }

        let transport = HttpTransport(url: endpointUrl)
        let client = EvmClient(transport: transport)

        // Get sender address from current wallet
        guard let wallet = currentWallet else {
            throw WalletSignerError.noWalletSelected
        }

        // Create transaction params for gas estimation
        let params = TransactionParams(
            from: wallet.address,
            to: to,
            value: TransactionValue(wei: Wei(bigInt: value))
        )

        // Estimate gas for the transaction
        let gasEstimate = try await client.estimateGas(params: params)

        return gasEstimate
    }

    /// Create and send a transaction
    /// - Parameters:
    ///   - to: Recipient address
    ///   - value: Amount to send in wei
    ///   - gasLimit: Gas limit for the transaction
    ///   - endpoint: RPC endpoint to use for sending
    /// - Returns: Transaction hash
    func sendTransaction(to: String, value: BigInt, gasLimit: BigInt, endpoint: Endpoint) async throws -> String {
        guard let wallet = currentWallet else {
            throw WalletSignerError.noWalletSelected
        }

        guard let endpointUrl = URL(string: endpoint.url) else {
            throw WalletSignerError.invalidEndpoint
        }

        let transport = HttpTransport(url: endpointUrl)
        let client = EvmClient(transport: transport)

        // Get the signer
        let signer = walletSigner

        // Create client with signer
        let signerClient = client.withSigner(signer: signer)

        // Create transaction params
        let params = TransactionParams(
            from: wallet.address,
            to: to,
            gas: "0x" + String(gasLimit, radix: 16),
            value: TransactionValue(wei: Wei(bigInt: value))
        )

        // Send the transaction
        let txHash = try await signerClient.sendTransaction(params: params)

        // Create a Transaction record
        let transaction = Transaction(
            hash: txHash,
            type: .send,
            from: wallet.address,
            to: to,
            value: String(value),
            timestamp: Date(),
            status: .pending,
            wallet: wallet
        )
        modelContext.insert(transaction)
        try modelContext.save()

        return txHash
    }

    /// Queue a transaction for approval before sending
    /// - Parameters:
    ///   - to: Recipient address
    ///   - value: Amount to send in wei
    ///   - gasEstimate: Estimated gas limit
    /// - Returns: The queued transaction
    func queueTransaction(to: String, value: BigInt, gasEstimate: BigInt) throws -> QueuedTransaction {
        let queuedTx = QueuedTransaction(
            to: to,
            value: String(value),
            data: nil,
            gasEstimate: String(gasEstimate)
        )

        modelContext.insert(queuedTx)
        try modelContext.save()

        return queuedTx
    }

    /// Process an approved transaction (called after user approves via UI)
    /// - Parameters:
    ///   - queuedTransaction: The queued transaction to process
    ///   - endpoint: RPC endpoint to use for sending
    /// - Returns: Transaction hash
    func processApprovedTransaction(_ queuedTransaction: QueuedTransaction, endpoint: Endpoint) async throws -> String {
        guard let value = BigInt(queuedTransaction.value) else {
            throw WalletSignerError.invalidTransactionData
        }

        // Use gas estimate if available, otherwise use default
        let gasLimit: BigInt
        if let gasEstimateStr = queuedTransaction.gasEstimate,
           let gasEstimate = BigInt(gasEstimateStr) {
            gasLimit = gasEstimate
        } else {
            // Default gas limit for simple ETH transfer
            gasLimit = BigInt(21000)
        }

        let txHash = try await sendTransaction(
            to: queuedTransaction.to,
            value: value,
            gasLimit: gasLimit,
            endpoint: endpoint
        )

        // Remove the queued transaction
        modelContext.delete(queuedTransaction)
        try modelContext.save()

        return txHash
    }
}

// MARK: - Errors

enum WalletSignerError: LocalizedError {
    case noWalletSelected
    case notImplemented
    case signingFailed(Error)
    case invalidEndpoint
    case invalidTransactionData

    var errorDescription: String? {
        switch self {
        case .noWalletSelected:
            return "No wallet selected for signing"
        case .notImplemented:
            return "This feature is not yet implemented"
        case .signingFailed(let error):
            return "Signing failed: \(error.localizedDescription)"
        case .invalidEndpoint:
            return "Invalid RPC endpoint URL"
        case .invalidTransactionData:
            return "Invalid transaction data"
        }
    }
}
