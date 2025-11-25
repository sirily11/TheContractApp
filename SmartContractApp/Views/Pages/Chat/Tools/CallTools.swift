//
//  CallTools.swift
//  SmartContractApp
//
//  Created by Claude on 11/22/25.
//

@preconcurrency import Agent
import BigInt
import EvmCore
import Foundation
import JSONSchema
import SwiftData

// MARK: - Call Tools

enum CallTools {
    /// Creates the call_contract_read tool for calling view/pure functions
    static func callReadTool(
        context: ModelContext,
        walletSigner: WalletSignerViewModel
    ) -> AgentTool<CallReadInput, CallReadOutput> {
        AgentTool(
            name: "call_contract_read",
            description: """
                Call a read-only (view/pure) function on a smart contract. \
                Returns the result immediately without requiring a transaction.
                """,
            parameters: .object(
                description: "Call read function parameters",
                properties: [
                    "contractId": .string(description: "ID of the contract to call"),
                    "functionName": .string(description: "Name of the function to call"),
                    "args": .object(
                        description: "Function arguments as key-value pairs",
                        properties: [:],
                        required: []
                    )
                ],
                required: ["contractId", "functionName"]
            ),
            execute: { input in
                return try await callReadFunction(
                    input: input,
                    context: context,
                    walletSigner: walletSigner
                )
            }
        )
    }

    /// Creates the call_contract_write tool for calling state-changing functions
    static func callWriteTool(
        context: ModelContext,
        walletSigner: WalletSignerViewModel,
        registry: ToolRegistry
    ) -> AgentTool<CallWriteInput, CallWriteOutput> {
        AgentTool(
            name: "call_contract_write",
            description: """
                Call a state-changing function on a smart contract. \
                Requires user approval to sign and send the transaction.
                """,
            parameters: .object(
                description: "Call write function parameters",
                properties: [
                    "contractId": .string(description: "ID of the contract to call"),
                    "functionName": .string(description: "Name of the function to call"),
                    "args": .object(
                        description: "Function arguments as key-value pairs",
                        properties: [:],
                        required: []
                    ),
                    "value": .string(description: "ETH value to send with the call")
                ],
                required: ["contractId", "functionName"]
            ),
            toolType: .ui,
            execute: { input in
                return try await callWriteFunction(
                    input: input,
                    context: context,
                    walletSigner: walletSigner,
                    registry: registry
                )
            }
        )
    }

    // MARK: - Private Methods

    private static func callReadFunction(
        input: CallReadInput,
        context: ModelContext,
        walletSigner: WalletSignerViewModel
    ) async throws -> CallReadOutput {
        // Get contract
        guard let contractId = UUID(uuidString: input.contractId) else {
            throw SmartContractToolError.invalidId(input.contractId)
        }

        let descriptor = FetchDescriptor<EVMContract>(
            predicate: #Predicate { $0.id == contractId }
        )
        let contracts = try context.fetch(descriptor)

        guard let contract = contracts.first else {
            throw SmartContractToolError.notFound(entity: "Contract", id: input.contractId)
        }

        guard contract.status == .deployed else {
            throw SmartContractToolError.contractNotDeployed(contract.name)
        }

        guard let abi = contract.abi else {
            throw SmartContractToolError.noAbiAttached(contract.name)
        }

        guard let endpoint = contract.endpoint else {
            throw SmartContractToolError.notFound(entity: "Endpoint", id: contract.endpointId.uuidString)
        }

        // Parse ABI
        let parser = try AbiParser(fromJsonString: abi.abiContent)

        // Find function in ABI
        guard let abiFunction = parser.items.first(where: {
            $0.type == .function && $0.name == input.functionName
        }) else {
            throw SmartContractToolError.functionNotFound(input.functionName)
        }

        // Convert args to TransactionParameters
        var params: [TransactionParameter] = []
        if let args = input.args {
            for abiInput in abiFunction.inputs ?? [] {
                if let value = args[abiInput.name ?? ""] {
                    let param = try TransactionParameter(
                        name: abiInput.name ?? "",
                        typeString: abiInput.type,
                        value: AnyCodable(value)
                    )
                    params.append(param)
                }
            }
        }

        // Create client
        guard let endpointUrl = URL(string: endpoint.url) else {
            throw SmartContractToolError.invalidEndpointUrl(endpoint.url)
        }

        let transport = HttpTransport(url: endpointUrl)
        let client = EvmClient(transport: transport)

        // Get signer
        let signer = try walletSigner.getWalletSigner()
        let signerClient = client.withSigner(signer: signer)

        // Create contract instance
        let evmContract = try EvmContract(
            address: Address(fromHexString: contract.address),
            abi: parser.items,
            evmSigner: signerClient
        )

        // Execute call
        let args = params.map { $0.value }
        let result = try await evmContract.callFunction(
            name: input.functionName,
            args: args,
            value: .ether(.init(bigInt: .zero))
        )

        // Format result
        let formattedResult = formatResult(result.result.value)

        return CallReadOutput(
            success: true,
            result: formattedResult,
            message: "Function call successful"
        )
    }

    private static func callWriteFunction(
        input: CallWriteInput,
        context: ModelContext,
        walletSigner: WalletSignerViewModel,
        registry: ToolRegistry
    ) async throws -> CallWriteOutput {
        // Get contract
        guard let contractId = UUID(uuidString: input.contractId) else {
            throw SmartContractToolError.invalidId(input.contractId)
        }

        let descriptor = FetchDescriptor<EVMContract>(
            predicate: #Predicate { $0.id == contractId }
        )
        let contracts = try context.fetch(descriptor)

        guard let contract = contracts.first else {
            throw SmartContractToolError.notFound(entity: "Contract", id: input.contractId)
        }

        guard contract.status == .deployed else {
            throw SmartContractToolError.contractNotDeployed(contract.name)
        }

        guard let abi = contract.abi else {
            throw SmartContractToolError.noAbiAttached(contract.name)
        }

        // Parse ABI
        let parser = try AbiParser(fromJsonString: abi.abiContent)

        // Find function in ABI
        guard let abiFunction = parser.items.first(where: {
            $0.type == .function && $0.name == input.functionName
        }) else {
            throw SmartContractToolError.functionNotFound(input.functionName)
        }

        // Convert args to TransactionParameters
        var params: [TransactionParameter] = []
        if let args = input.args {
            for abiInput in abiFunction.inputs ?? [] {
                if let value = args[abiInput.name ?? ""] {
                    let param = try TransactionParameter(
                        name: abiInput.name ?? "",
                        typeString: abiInput.type,
                        value: AnyCodable(value)
                    )
                    params.append(param)
                }
            }
        }

        // Parse value
        let txValue: TransactionValue
        if let valueStr = input.value {
            if let weiValue = BigInt(valueStr) {
                txValue = .wei(.init(bigInt: weiValue))
            } else if let etherValue = Double(valueStr) {
                let weiAmount = BigInt(etherValue * 1e18)
                txValue = .wei(.init(bigInt: weiAmount))
            } else {
                txValue = .ether(.init(bigInt: .zero))
            }
        } else {
            txValue = .ether(.init(bigInt: .zero))
        }

        // Create queued transaction
        let queuedTx = QueuedTransaction(
            to: contract.address,
            value: txValue,
            data: nil,
            gasEstimate: nil,
            contractFunctionName: .function(name: input.functionName),
            contractParameters: params,
            status: .pending,
            bytecode: nil,
            abi: parser.items
        )

        // Store pending call for UI
        let pendingCall = PendingWriteCall(
            id: UUID(),
            input: input,
            contract: contract,
            queuedTransaction: queuedTx
        )

        await registry.setPendingWriteCall(pendingCall)

        // Queue the transaction
        walletSigner.queueTransaction(tx: queuedTx)

        return CallWriteOutput(
            success: true,
            txHash: nil,
            message: "Transaction queued. Please approve in the wallet.",
            pendingConfirmation: true
        )
    }

    // MARK: - Helper Methods

    private static func formatResult(_ value: Any) -> String {
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
}

// MARK: - Pending Write Call

struct PendingWriteCall: Sendable {
    let id: UUID
    let input: CallWriteInput
    let contract: EVMContract
    let queuedTransaction: QueuedTransaction
}
