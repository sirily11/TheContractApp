//
//  ToolRegistryProtocols.swift
//  SmartContractApp
//
//  Created by Claude on 11/29/25.
//

import AgentLayout
import Combine
import EvmCore
import Foundation

// MARK: - Chat Provider Protocol

/// Protocol for chat provider operations used by ToolRegistry
protocol ChatProviderProtocol: AnyObject {
    /// Send a function result back to the chat
    func sendFunctionResult(id: String, result: any Encodable) async throws
}

// MARK: - ChatProvider Conformance

extension ChatProvider: ChatProviderProtocol {}

// MARK: - Wallet Signer Protocol

/// Protocol for wallet signing operations used by ToolRegistry
protocol WalletSignerProtocol: AnyObject {
    /// Publisher for transaction events
    var transactionEventPublisher: AnyPublisher<TransactionEvent, Never> { get }

    /// Queue a transaction for user approval
    func queueTransaction(tx: QueuedTransaction)

    /// Get the wallet signer for signing transactions
    func getWalletSigner() throws -> Signer
}

// MARK: - WalletSignerViewModel Conformance

extension WalletSignerViewModel: WalletSignerProtocol {}

// MARK: - Contract Deployment Protocol

/// Protocol for contract deployment operations used by ToolRegistry
protocol ContractDeploymentProtocol {
    /// Compile Solidity source code
    func compileSolidity(_ source: String, contractName: String?, version: String) async throws -> (bytecode: String, abi: String)

    /// Deploy bytecode to the network (queues the transaction)
    func deployBytecodeToNetwork(_ bytecode: String, abi: [AbiItem], endpoint: Endpoint, value: TransactionValue, constructorParameters: [TransactionParameter]) async throws -> QueuedTransaction
}

// MARK: - ContractDeploymentViewModel Conformance

extension ContractDeploymentViewModel: ContractDeploymentProtocol {}

// MARK: - Contract Deployment Factory Protocol

/// Factory protocol for creating contract deployment instances
protocol ContractDeploymentFactoryProtocol {
    /// Create a contract deployment instance
    func createDeploymentViewModel(modelContext: Any, walletSigner: WalletSignerProtocol) -> ContractDeploymentProtocol
}
