//
//  ContractInteractionViewModel.swift
//  SmartContractApp
//
//  Created by Claude on 11/17/25.
//

import BigInt
import Combine
import EvmCore
import Foundation
import Observation
import SwiftData

// MARK: - Function Execution Progress

enum FunctionExecutionProgress: Equatable {
    case idle
    case preparing
    case executing
    case waitingForSignature
    case sent(txHash: String)
    case completed(result: String)
    case failed(error: String)
}

// MARK: - Function Execution Error

enum FunctionExecutionError: LocalizedError {
    case noWalletSelected
    case invalidEndpoint
    case invalidContractAddress
    case invalidABI
    case functionNotFound(String)
    case parameterEncodingFailed
    case executionFailed(String)
    case decodingFailed(String)
    case transactionFailed(String)
    case userRejected
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .noWalletSelected:
            return "No wallet selected for signing"
        case .invalidEndpoint:
            return "Invalid RPC endpoint URL"
        case .invalidContractAddress:
            return "Invalid contract address"
        case .invalidABI:
            return "Invalid or missing contract ABI"
        case .functionNotFound(let name):
            return "Function '\(name)' not found in contract ABI"
        case .parameterEncodingFailed:
            return "Failed to encode function parameters"
        case .executionFailed(let message):
            return "Function execution failed: \(message)"
        case .decodingFailed(let message):
            return "Failed to decode result: \(message)"
        case .transactionFailed(let message):
            return "Transaction failed: \(message)"
        case .userRejected:
            return "Transaction was rejected by user"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

// MARK: - Contract Interaction View Model

@Observable
final class ContractInteractionViewModel {
    // MARK: - State Properties

    var executionProgress: FunctionExecutionProgress = .idle
    var isExecuting: Bool = false
    var lastError: String?

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let walletSigner: WalletSignerViewModel

    // MARK: - Cancellables

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(modelContext: ModelContext, walletSigner: WalletSignerViewModel) {
        self.modelContext = modelContext
        self.walletSigner = walletSigner
    }

    // MARK: - Function Execution

    /// Execute a read function (view/pure) - instant execution using eth_call
    /// - Parameters:
    ///   - contract: The EVMContract to interact with
    ///   - functionName: The name of the function to call
    ///   - parameters: The function parameters
    /// - Returns: The decoded result
    func executeReadFunction(
        contract: EVMContract,
        functionName: String,
        parameters: [TransactionParameter]
    ) async throws -> String {
        // Reset state
        lastError = nil
        isExecuting = true
        executionProgress = .preparing

        do {
            // Validate contract and endpoint
            guard let endpoint = contract.endpoint else {
                throw FunctionExecutionError.invalidEndpoint
            }

            guard let endpointUrl = URL(string: endpoint.url) else {
                throw FunctionExecutionError.invalidEndpoint
            }

            // Parse ABI
            guard let abi = contract.abi else {
                throw FunctionExecutionError.invalidABI
            }

            let parser = try AbiParser(fromJsonString: abi.abiContent)

            // Create EvmCore client
            let transport = HttpTransport(url: endpointUrl)
            let client = EvmClient(transport: transport)

            // Get signer from wallet
            let signer = try walletSigner.getWalletSigner()
            let signerClient = client.withSigner(signer: signer)

            // Create EvmCore contract instance
            let evmContract = try EvmContract(
                address: Address(fromHexString: contract.address),
                abi: parser.items,
                evmSigner: signerClient
            )

            // Execute function
            executionProgress = .executing

            let args = parameters.map { $0.value }
            let result = try await evmContract.callFunction(
                name: functionName,
                args: args,
                value: .ether(.init(bigInt: .zero))
            )

            // Decode result
            let decodedResult = formatResult(result.result.value)

            // Save to history
            try await saveFunctionCall(
                contract: contract,
                functionName: functionName,
                parameters: parameters,
                result: decodedResult,
                rawResult: "\(result.result.value)",
                transactionHash: nil,
                status: .success
            )

            executionProgress = .completed(result: decodedResult)
            isExecuting = false

            return decodedResult
        } catch {
            lastError = error.localizedDescription
            executionProgress = .failed(error: error.localizedDescription)
            isExecuting = false

            // Save failed call to history
            try? await saveFunctionCall(
                contract: contract,
                functionName: functionName,
                parameters: parameters,
                result: nil,
                rawResult: nil,
                transactionHash: nil,
                status: .failed,
                errorMessage: error.localizedDescription
            )

            throw error
        }
    }

    /// Execute a write function (nonpayable/payable) - queue transaction for signing
    /// - Parameters:
    ///   - contract: The EVMContract to interact with
    ///   - functionName: The name of the function to call
    ///   - parameters: The function parameters
    ///   - value: The value to send with the transaction (default 0)
    /// - Returns: The queued transaction
    func executeWriteFunction(
        contract: EVMContract,
        functionName: String,
        parameters: [TransactionParameter],
        value: TransactionValue = .ether(.init(bigInt: .zero))
    ) async throws -> QueuedTransaction {
        // Reset state
        lastError = nil
        isExecuting = true
        executionProgress = .preparing

        do {
            // Validate contract
            guard let abi = contract.abi else {
                throw FunctionExecutionError.invalidABI
            }

            let parser = try AbiParser(fromJsonString: abi.abiContent)

            // Create queued transaction
            let queuedTx = QueuedTransaction(
                to: contract.address,
                value: value,
                data: nil, // Will be encoded by EvmCore
                gasEstimate: nil, // Will be estimated by wallet
                contractFunctionName: .function(name: functionName),
                contractParameters: parameters,
                status: .pending,
                bytecode: nil,
                abi: parser.items
            )

            // Queue transaction
            walletSigner.queueTransaction(tx: queuedTx)

            executionProgress = .waitingForSignature
            isExecuting = false

            return queuedTx
        } catch {
            lastError = error.localizedDescription
            executionProgress = .failed(error: error.localizedDescription)
            isExecuting = false
            throw error
        }
    }

    /// Subscribe to transaction events and update function call history
    /// - Parameters:
    ///   - contract: The contract being interacted with
    ///   - functionName: The function name
    ///   - parameters: The function parameters
    ///   - queuedTx: The queued transaction to monitor
    func subscribeToTransactionEvents(
        contract: EVMContract,
        functionName: String,
        parameters: [TransactionParameter],
        queuedTx: QueuedTransaction
    ) -> AnyPublisher<FunctionExecutionProgress, Never> {
        walletSigner.transactionEventPublisher
            .filter { event in
                // Filter events for this specific transaction
                switch event {
                case .queued(let tx), .approved(let tx), .rejected(let tx), .cancelled(let tx):
                    return tx.id == queuedTx.id
                case .sent(_, let tx), .contractCreated(_, _, let tx):
                    return tx.id == queuedTx.id
                case .error(_, let tx):
                    return tx?.id == queuedTx.id
                }
            }
            .map { [weak self] event -> FunctionExecutionProgress in
                guard let self = self else { return .idle }

                switch event {
                case .queued:
                    return .waitingForSignature

                case .sent(let txHash, _), .contractCreated(let txHash, _, _):
                    // Save to history with transaction hash
                    Task {
                        try? await self.saveFunctionCall(
                            contract: contract,
                            functionName: functionName,
                            parameters: parameters,
                            result: "Transaction sent: \(txHash)",
                            rawResult: txHash,
                            transactionHash: txHash,
                            status: .success
                        )
                    }
                    return .sent(txHash: txHash)

                case .rejected, .cancelled:
                    // Save failed call
                    Task {
                        try? await self.saveFunctionCall(
                            contract: contract,
                            functionName: functionName,
                            parameters: parameters,
                            result: nil,
                            rawResult: nil,
                            transactionHash: nil,
                            status: .failed,
                            errorMessage: "User rejected transaction"
                        )
                    }
                    return .failed(error: "Transaction rejected by user")

                case .error(let error, _):
                    // Save failed call
                    Task {
                        try? await self.saveFunctionCall(
                            contract: contract,
                            functionName: functionName,
                            parameters: parameters,
                            result: nil,
                            rawResult: nil,
                            transactionHash: nil,
                            status: .failed,
                            errorMessage: error.localizedDescription
                        )
                    }
                    return .failed(error: error.localizedDescription)

                default:
                    return .idle
                }
            }
            .eraseToAnyPublisher()
    }

    // MARK: - Result Formatting

    /// Format a result value for display
    /// - Parameter value: The raw result value
    /// - Returns: A human-readable string
    private func formatResult(_ value: Any) -> String {
        if let stringValue = value as? String {
            return stringValue
        } else if let bigInt = value as? BigInt {
            return bigInt.description
        } else if let bool = value as? Bool {
            return bool ? "true" : "false"
        } else if let array = value as? [Any] {
            return "[\(array.map { formatResult($0) }.joined(separator: ", "))]"
        } else {
            return "\(value)"
        }
    }

    // MARK: - History Management

    /// Save a function call to SwiftData history
    /// - Parameters:
    ///   - contract: The contract that was called
    ///   - functionName: The function name
    ///   - parameters: The function parameters
    ///   - result: The decoded result (if successful)
    ///   - rawResult: The raw hex result
    ///   - transactionHash: The transaction hash (for write functions)
    ///   - status: The call status
    ///   - errorMessage: Error message (if failed)
    private func saveFunctionCall(
        contract: EVMContract,
        functionName: String,
        parameters: [TransactionParameter],
        result: String?,
        rawResult: String?,
        transactionHash: String?,
        status: CallStatus,
        errorMessage: String? = nil
    ) async throws {
        let parametersData = try JSONEncoder().encode(parameters)

        let functionCall = ContractFunctionCall(
            functionName: functionName,
            parameters: parametersData,
            result: result,
            rawResult: rawResult,
            transactionHash: transactionHash,
            status: status,
            errorMessage: errorMessage,
            contractId: contract.id,
            contract: contract
        )

        modelContext.insert(functionCall)
        try modelContext.save()
    }

    /// Load function call history for a contract
    /// - Parameter contract: The contract to load history for
    /// - Returns: Array of function calls
    func loadFunctionHistory(for contract: EVMContract) throws -> [ContractFunctionCall] {
        let contractId = contract.id
        let descriptor = FetchDescriptor<ContractFunctionCall>(
            predicate: #Predicate { $0.contractId == contractId },
            sortBy: [SortDescriptor(\ContractFunctionCall.timestamp, order: .reverse)]
        )

        return try modelContext.fetch(descriptor)
    }

    /// Get the last successful call for a specific function
    /// - Parameters:
    ///   - contract: The contract
    ///   - functionName: The function name
    /// - Returns: The last successful function call, if any
    func getLastSuccessfulCall(
        for contract: EVMContract,
        functionName: String
    ) throws -> ContractFunctionCall? {
        let contractId = contract.id
        let targetFunctionName = functionName
        let successStatus = CallStatus.success
        let descriptor = FetchDescriptor<ContractFunctionCall>(
            predicate: #Predicate {
                $0.contractId == contractId &&
                $0.functionName == targetFunctionName &&
                $0.status == successStatus
            },
            sortBy: [SortDescriptor(\ContractFunctionCall.timestamp, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)
        return results.first
    }

    /// Delete a function call from history
    /// - Parameter call: The function call to delete
    func deleteFunctionCall(_ call: ContractFunctionCall) throws {
        modelContext.delete(call)
        try modelContext.save()
    }

    /// Clear all function call history for a contract
    /// - Parameter contract: The contract to clear history for
    func clearHistory(for contract: EVMContract) throws {
        let calls = try loadFunctionHistory(for: contract)
        for call in calls {
            modelContext.delete(call)
        }
        try modelContext.save()
    }
}
