//
//  WalletSignerViewModel.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import BigInt
import Combine
import EvmCore
import Foundation
import Observation
import SwiftData

@Observable
final class WalletSignerViewModel {
    // MARK: - Properties

    var modelContext: ModelContext!
    private var continuation: AsyncStream<Data>.Continuation?
    private(set) var currentShowingTransactions: [QueuedTransaction] = []

    // MARK: - Combine Transaction Stream

    /// Subject for transaction events
    private let transactionEventSubject = PassthroughSubject<TransactionEvent, Never>()

    /// Publisher for transaction events that views can subscribe to
    var transactionEventPublisher: AnyPublisher<TransactionEvent, Never> {
        transactionEventSubject.eraseToAnyPublisher()
    }

    /// Cancellable subscriptions
    private var cancellables = Set<AnyCancellable>()

    /// The currently selected wallet for signing
    var currentWallet: EVMWallet?

    /// Number of pending transactions waiting for signature
    var pendingTransactionCount: Int {
        return currentShowingTransactions.count
    }

    // MARK: - Selection Management

    /// Update the selected wallet (called from app-level wrapper)
    /// - Parameter wallet: The wallet to select
    func setSelectedWallet(_ wallet: EVMWallet?) {
        currentWallet = wallet
    }

    /// Get the current selected wallet
    /// - Returns: The currently selected wallet, if any
    func getCurrentWallet() -> EVMWallet? {
        return currentWallet
    }

    // MARK: - Transaction Processing State

    /// Whether a transaction is currently being processed on-chain
    var isProcessingTransaction = false

    /// Error message from the last transaction attempt
    var transactionError: String?

    /// Result hash from the last successful transaction
    var lastTransactionHash: String?

    /// Timestamp when processing started (for minimum display duration)
    private var processingStartTime: Date?

    /// Minimum duration to show processing screen (in seconds)
    private let minimumProcessingDuration: TimeInterval = 2.0

    // MARK: - WalletSigner Protocol

    enum SignerError: LocalizedError {
        case noWalletSelected
        case privateKeyRetrievalFailed
        case signerCreationFailed

        var errorDescription: String? {
            switch self {
            case .noWalletSelected:
                return "No wallet selected for signing"
            case .privateKeyRetrievalFailed:
                return "Failed to retrieve private key from keychain"
            case .signerCreationFailed:
                return "Failed to create signer from private key"
            }
        }
    }

    func getWalletSigner() throws -> Signer {
        guard let wallet = currentWallet else {
            throw SignerError.noWalletSelected
        }

        guard let privateKey = try? wallet.getPrivateKey() else {
            throw SignerError.privateKeyRetrievalFailed
        }

        guard let signer = try? PrivateKeySigner(hexPrivateKey: privateKey) else {
            throw SignerError.signerCreationFailed
        }

        return signer
    }

    var signingRequestStream: AsyncStream<Data> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    // MARK: - Initialization

    init(currentWallet: EVMWallet? = nil) {
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
                    let signer = try self.getWalletSigner()

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
        // Cancel each transaction individually
        let transactionsToCancel = currentShowingTransactions
        currentShowingTransactions = []

        // Send cancelled event for each transaction
        for transaction in transactionsToCancel {
            transactionEventSubject.send(.cancelled(transaction))
        }
    }

    /// Cancel a specific signing request by index
    /// - Parameter index: The index of the transaction to cancel
    func cancelSigningRequest(at index: Int) async {
        guard index >= 0, index < currentShowingTransactions.count else {
            return
        }
        currentShowingTransactions.remove(at: index)
        transactionEventSubject.send(.cancelled(currentShowingTransactions[index]))
    }

    // MARK: - Helper Methods

    /// Reject a transaction
    /// - Parameter transaction: The transaction to reject
    func rejectTransaction(_ transaction: QueuedTransaction) throws {
        // remove transaction from queue
        if let index = currentShowingTransactions.firstIndex(where: { $0.id == transaction.id }) {
            currentShowingTransactions.remove(at: index)
        }
        transactionEventSubject.send(.rejected(transaction))
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

    /// Estimate gas for a queued transaction
    /// - Parameters:
    ///   - transaction: The queued transaction to estimate gas for
    ///   - endpoint: RPC endpoint to use for estimation
    /// - Returns: Estimated gas limit as a hex string
    func estimateGasForTransaction(_ transaction: QueuedTransaction, endpoint: Endpoint) async throws -> String {
        guard let endpointUrl = URL(string: endpoint.url) else {
            throw WalletSignerError.invalidEndpoint
        }

        let transport = HttpTransport(url: endpointUrl)
        let client = EvmClient(transport: transport)

        // Get sender address from current wallet
        guard let wallet = currentWallet else {
            throw WalletSignerError.noWalletSelected
        }

        // Handle contract creation (deployment) - to is empty, bytecode is present
        if transaction.contractFunctionName == .constructor {
            guard let bytecode = transaction.bytecode, !bytecode.isEmpty else {
                throw WalletSignerError.missingBytecode
            }

            // For contract creation, use bytecode as data
            // Note: Constructor arguments are encoded separately during actual deployment
            // Gas estimate with just bytecode will be slightly conservative, which is fine
            let deployData = bytecode.hasPrefix("0x") ? bytecode : "0x" + bytecode

            // Contract creation params: no 'to' address
            let params = TransactionParams(
                from: wallet.address,
                value: transaction.value,
                data: deployData
            )

            let gasEstimate = try await client.estimateGas(params: params)
            return "0x" + String(gasEstimate, radix: 16)
        }

        // Create transaction params for gas estimation (normal transaction)
        var params = TransactionParams(
            from: wallet.address,
            to: transaction.to,
            value: transaction.value
        )

        // Include data if present (for contract calls)
        if let data = transaction.data, !data.isEmpty {
            params = TransactionParams(
                from: wallet.address,
                to: transaction.to,
                value: transaction.value,
                data: data
            )
        }

        // Estimate gas for the transaction
        let gasEstimate = try await client.estimateGas(params: params)

        // Return as hex string
        return "0x" + String(gasEstimate, radix: 16)
    }

    func removeTransactionFromQueue(tx: QueuedTransaction) {
        currentShowingTransactions.removeAll { $0.id == tx.id }
    }

    func makeFunctionCall(tx: QueuedTransaction, endpoint: Endpoint) async throws -> (String, String?) {
        guard let abi = tx.abi else {
            throw WalletSignerError.missingAbi
        }

        guard let endpointUrl = URL(string: endpoint.url) else {
            throw WalletSignerError.invalidEndpoint
        }

        let transport = HttpTransport(url: endpointUrl)
        let client = EvmClient(transport: transport)

        // Get the signer
        let signer = try getWalletSigner()

        // Create client with signer
        let signerClient = client.withSigner(signer: signer)

        switch tx.contractFunctionName {
        case .function(let name):

            let contract = try EvmContract(address: .init(fromHexString: tx.to), abi: abi, evmSigner: signerClient)
            let result = try await contract.callFunction(name: name, args: tx.contractParameters.map { $0.value }, value: tx.value)
            return (result.transactionHash ?? "", nil)
        case .constructor:
            guard let bytecode = tx.bytecode else {
                throw WalletSignerError.invalidTransactionData
            }
            let contract = DeployableEvmContract(bytecode: bytecode, abi: abi, evmSigner: signerClient)
            let (result, addr) = try await contract.deploy(constructorArgs: tx.contractParameters.map { $0.value }, importCallback: nil, value: tx.value, gasLimit: nil, gasPrice: nil)
            return (addr ?? "", result.address.value)
        case .none:
            throw WalletSignerError.invalidTransactionData
        }
    }

    /// Create and send a transaction
    /// - Parameters:
    ///   - to: Recipient address
    ///   - value: Amount to send in wei
    ///   - gasLimit: Gas limit for the transaction
    ///   - endpoint: RPC endpoint to use for sending
    /// - Returns: Transaction hash
    func sendTransaction(to: String, value: TransactionValue, gasLimit: BigInt, endpoint: Endpoint) async throws -> String {
        guard let wallet = currentWallet else {
            throw WalletSignerError.noWalletSelected
        }

        guard let endpointUrl = URL(string: endpoint.url) else {
            throw WalletSignerError.invalidEndpoint
        }

        let transport = HttpTransport(url: endpointUrl)
        let client = EvmClient(transport: transport)

        // Get the signer
        let signer = try getWalletSigner()

        // Create client with signer
        let signerClient = client.withSigner(signer: signer)

        // Create transaction params
        let params = TransactionParams(
            from: wallet.address,
            to: to,
            gas: .init(hex: "0x" + String(gasLimit, radix: 16)),
            value: value
        )

        // Send the transaction
        let pendingTransaction = try await signerClient.signAndSendTransaction(params: params)

        // Create a Transaction record
        let transaction = Transaction(
            blockHash: pendingTransaction.txHash,
            type: .send,
            from: wallet.address,
            to: to,
            value: String(value.toWei().value),
            timestamp: Date(),
            status: .pending,
            wallet: wallet
        )
        modelContext.insert(transaction)
        try modelContext.save()

        // wait
        let result = try await pendingTransaction.wait()

        if result.isSuccessful {
            transaction.status = .success
        } else {
            transaction.status = .failed
        }

        try modelContext.save()
        return pendingTransaction.txHash
    }

    /// Queue a transaction for approval before sending
    /// - Parameters:
    ///   - to: Recipient address
    ///   - value: Amount to send in wei
    ///   - gasEstimate: Estimated gas limit
    /// - Returns: The queued transaction
    func queueTransaction(to: String, value: TransactionValue) throws -> QueuedTransaction {
        let gasEstimate = 21000 // Default for simple ETH transfer
        let queuedTx = QueuedTransaction(
            to: to,
            value: value,
            data: nil,
            gasEstimate: "0x" + String(gasEstimate, radix: 16)
        )
        currentShowingTransactions.append(queuedTx)

        // Emit queued event
        transactionEventSubject.send(.queued(queuedTx))

        return queuedTx
    }

    func queueTransaction(tx: QueuedTransaction) {
        currentShowingTransactions.append(tx)
        transactionEventSubject.send(.queued(tx))
    }

    /// Process an approved transaction (called after user approves via UI)
    /// - Parameters:
    ///   - queuedTransaction: The queued transaction to process
    ///   - endpoint: RPC endpoint to use for sending
    /// - Returns: Transaction hash
    func processApprovedTransaction(_ queuedTransaction: QueuedTransaction, endpoint: Endpoint) async throws -> String {
        // Reset state and track start time
        isProcessingTransaction = true
        processingStartTime = Date()
        transactionError = nil
        lastTransactionHash = nil

        do {
            let value = queuedTransaction.value

            // Use gas estimate if available, otherwise use default
            let gasLimit: BigInt
            if let gasEstimateStr = queuedTransaction.gasEstimate,
               let gasEstimate = BigInt(gasEstimateStr)
            {
                gasLimit = gasEstimate
            } else {
                // Default gas limit for simple ETH transfer
                gasLimit = BigInt(21000)
            }

            var txHash: String!
            var contractAddr: String?
            if queuedTransaction.isContractCall {
                let (transactionHash, contractAddress) = try await makeFunctionCall(tx: queuedTransaction, endpoint: endpoint)
                txHash = transactionHash
                contractAddr = contractAddress
            } else {
                txHash = try await sendTransaction(
                    to: queuedTransaction.to,
                    value: value,
                    gasLimit: gasLimit,
                    endpoint: endpoint
                )
            }

            // Ensure minimum display duration
            await ensureMinimumProcessingDuration()

            // Update state on success
            lastTransactionHash = txHash
            isProcessingTransaction = false

            // Emit sent event
            if let contractAddr {
                transactionEventSubject.send(.contractCreated(txHash: txHash, contractAddress: contractAddr, transaction: queuedTransaction))
            } else {
                transactionEventSubject.send(.sent(txHash: txHash, transaction: queuedTransaction))
            }

            // remove queued transaction
            removeTransactionFromQueue(tx: queuedTransaction)
            return txHash
        } catch {
            // Ensure minimum display duration even on error
            await ensureMinimumProcessingDuration()

            // Update state on failure
            transactionError = error.localizedDescription
            isProcessingTransaction = false

            // Emit error event
            transactionEventSubject.send(.error(error, transaction: queuedTransaction))

            throw error
        }
    }

    /// Ensures the processing screen is shown for at least the minimum duration
    private func ensureMinimumProcessingDuration() async {
        guard let startTime = processingStartTime else { return }

        let elapsed = Date().timeIntervalSince(startTime)
        let remaining = minimumProcessingDuration - elapsed

        if remaining > 0 {
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1000000000))
        }
    }
}

// MARK: - Transaction Events

/// Events emitted by the transaction stream
enum TransactionEvent {
    case queued(QueuedTransaction)
    case approved(QueuedTransaction)
    case rejected(QueuedTransaction)
    case sent(txHash: String, transaction: QueuedTransaction)
    case contractCreated(txHash: String, contractAddress: String, transaction: QueuedTransaction)
    case cancelled(QueuedTransaction)
    case error(Error, transaction: QueuedTransaction?)
}

// MARK: - Errors

enum WalletSignerError: LocalizedError {
    case noWalletSelected
    case notImplemented
    case signingFailed(Error)
    case invalidEndpoint
    case invalidTransactionData
    case missingBytecode
    case missingAbi
    case invalidReceiverAddress

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
        case .missingBytecode:
            return "Transaction data does not contain a bytecode"
        case .missingAbi:
            return "Transaction data does not contain an ABI"
        case .invalidReceiverAddress:
            return "Transaction data does not contain a valid receiver address"
        }
    }
}
