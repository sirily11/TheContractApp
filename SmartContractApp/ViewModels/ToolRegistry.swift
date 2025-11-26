//
//  ToolRegistry.swift
//  SmartContractApp
//
//  Created by Claude on 11/22/25.
//

import Agent
import AgentLayout
import BigInt
import Combine
import EvmCore
import Foundation
import Observation
import SwiftData
import SwiftUI

// MARK: - Deployment State

/// Deployment state for UI display
enum DeploymentState {
    case idle
    case compiling
    case deploying
    case success(address: String)
    case failed(String)
}

// MARK: - Write Call State

/// Write call state for UI display
enum WriteCallState: Equatable {
    case idle
    case executing
    case success(txHash: String)
    case failed(String)
}

// MARK: - Pending Deployment Info

/// Holds all metadata needed to save contract after successful deployment
struct PendingDeploymentInfo {
    let toolCallId: String
    let name: String
    let sourceCode: String
    let abiJson: String
    let bytecode: String
    let endpointId: UUID
}

// MARK: - Tool Registry

/// Central registry for all AI agent tools
/// Manages tool creation and pending operations that require user interaction
@Observable
@MainActor
final class ToolRegistry {
    // MARK: - Dependencies

    var modelContext: ModelContext!
    var walletSigner: WalletSignerViewModel!

    // MARK: - Pending Deployment Tracking

    var pendingDeployments: [UUID: PendingDeploymentInfo] = [:] // transactionId -> deployment info

    /// Tracks failed/rejected deployments by toolCallId for UI updates
    /// Key: toolCallId, Value: error message (or empty for rejection)
    var deploymentFailures: [String: String] = [:]

    /// Tracks successful deployments by toolCallId for UI updates
    /// Key: toolCallId, Value: contract address
    var deploymentSuccesses: [String: String] = [:]

    // MARK: - Pending Write Call Tracking

    var pendingWriteCalls: [UUID: String] = [:] // transactionId -> toolCallId

    /// Tracks failed/rejected write calls by toolCallId for UI updates
    /// Key: toolCallId, Value: error message
    var writeCallFailures: [String: String] = [:]

    /// Tracks successful write calls by toolCallId for UI updates
    /// Key: toolCallId, Value: transaction hash
    var writeCallSuccesses: [String: String] = [:]

    private var transactionSubscription: Task<Void, Never>?

    private var chatProvider: ChatProvider!

    init() {
        // Start listening to transaction events immediately
        startTransactionSubscription()
    }

    func setChatProvider(_ chatProvider: ChatProvider) {
        self.chatProvider = chatProvider
    }

    // MARK: - Transaction Subscription

    private func startTransactionSubscription() {
        transactionSubscription = Task { [weak self] in
            // Wait for walletSigner to be set
            while self?.walletSigner == nil {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
            guard let signer = self?.walletSigner else { return }

            for await event in signer.transactionEventPublisher.values {
                await self?.handleTransactionEvent(event)
            }
        }
    }

    // MARK: - Tool Creation

    /// Creates all available tools
    func createTools() -> [any AgentToolProtocol] {
        guard let context = modelContext, let signer = walletSigner else {
            return []
        }

        return [
            // CRUD Tools
            EndpointTools.endpointManagerTool(context: context),
            ABITools.abiManagerTool(context: context),
            ContractTools.contractManagerTool(context: context),
            // Compilation Tool
            CompileTools.compileSolidityTool(),
            // Interactive Tools
            DeployTools.deployContractTool(
                context: context,
                walletSigner: signer,
                registry: self
            ),
            CallTools.callReadTool(context: context, walletSigner: signer),
            CallTools.callWriteTool(context: context, walletSigner: signer, registry: self)
        ]
    }

    // MARK: - Message Renderer

    /// Creates a combined message renderer for tool results that need custom UI
    func createMessageRenderer() -> MessageRenderer {
        return { [weak self] message, messages, _, status in
            guard let self = self else {
                return (AnyView(EmptyView()), .skip)
            }

            // if the message is tool message
            if case .openai(let openAiMessage) = message {
                if case .tool(let openAiToolMessage) = openAiMessage {
                    return createOpenAiToolMessageRenderer(message: openAiToolMessage, messages: messages, status: status)
                }

                if case .assistant(let openAiAssistantMessage) = openAiMessage {
                    let foundToolMessage = messages.first { msg in
                        if case .openai(let openAiMessage) = msg {
                            if case .tool(let toolMessage) = openAiMessage {
                                return openAiAssistantMessage.toolCalls?.first?.id == toolMessage.toolCallId
                            }
                        }
                        return false
                    }

                    var toolMessage: OpenAIToolMessage? = nil
                    if let foundToolMessage {
                        if case .openai(let openAiMessage) = foundToolMessage {
                            if case .tool(let foundToolMessage) = openAiMessage {
                                toolMessage = foundToolMessage
                            }
                        }
                    }
                    return createOpenAiAssistantMessageRenderer(resultMessage: toolMessage, message: openAiAssistantMessage, messages: messages, status: status)
                }
            }

            return (AnyView(EmptyView()), .skip)
        }
    }

    /**
        Create a message renderer for assistant messages
     */
    func createOpenAiAssistantMessageRenderer(resultMessage: OpenAIToolMessage?, message: OpenAIAssistantMessage, messages: [Message], status: ToolStatus) -> (AnyView, RenderAction) {
        let toolCall = message.toolCalls?.first
        let content = toolCall?.function?.arguments
        let toolCallId = toolCall?.id

        switch toolCall?.function?.name {
        case DeployTools.name:
            // decode the content to deploy input
            let decoder = JSONDecoder()
            let deployInput = try? decoder.decode(DeployInput.self, from: (content ?? "{}").data(using: .utf8)!)
            guard let deployInput else {
                return (AnyView(Text("JSON is invalid or missing required fields.")), .replace)
            }
            let view = DeployInputView(
                deployInput: deployInput,
                status: status,
                toolCallId: toolCallId,
                toolRegistry: self
            ) { [weak self] in
                guard let self, let toolCallId else { return }
                _ = await self.handleDeploy(input: deployInput, toolCallId: toolCallId)
            }
            return (AnyView(view), .append)

        case CallTools.nameReadTool:
            // decode the content to call read input
            let decoder = JSONDecoder()
            let callInput = try? decoder.decode(CallReadInput.self, from: (content ?? "{}").data(using: .utf8)!)
            guard let callInput else {
                return (AnyView(Text("JSON is invalid or missing required fields.")), .replace)
            }
            let view = CallReadInputView(
                input: callInput,
                status: status,
                resultMessage: resultMessage
            )
            return (AnyView(view), .append)

        case CallTools.nameWriteTool:
            // decode the content to call write input
            let decoder = JSONDecoder()
            let callInput = try? decoder.decode(CallWriteInput.self, from: (content ?? "{}").data(using: .utf8)!)
            guard let callInput else {
                return (AnyView(Text("JSON is invalid or missing required fields.")), .replace)
            }
            let view = CallWriteInputView(
                input: callInput,
                status: status,
                toolCallId: toolCallId,
                toolRegistry: self
            ) { [weak self] in
                guard let self, let toolCallId else { return }
                _ = await self.handleWriteCall(input: callInput, toolCallId: toolCallId)
            }
            return (AnyView(view), .append)

        default:
            break
        }
        return (AnyView(EmptyView()), .skip)
    }

    /**
     Creates a message renderer for tool resultss
     */
    func createOpenAiToolMessageRenderer(message: OpenAIToolMessage, messages: [Message], status: ToolStatus) -> (AnyView, RenderAction) {
        let uiToolNames = [DeployTools.name, CallTools.nameReadTool, CallTools.nameWriteTool]
        // find message in messages that matches message.tool_call_id
        let foundMessage = messages.first { msg in
            if case .openai(let openAiMessage) = msg {
                if case .assistant(let assistantMessage) = openAiMessage {
                    return assistantMessage.toolCalls?.first?.id == message.toolCallId
                }
            }
            return false
        }

        // check tool name
        if let foundMessage = foundMessage,
           case .openai(let openAiMessage) = foundMessage,
           case .assistant(let assistantMessage) = openAiMessage
        {
            if let functionName = assistantMessage.toolCalls?.first?.function?.name {
                // check function name in the list
                if uiToolNames.contains(functionName) {
                    // don't render anything. Replace with empty view
                    return (AnyView(EmptyView()), .replace)
                }
            }
        }

        // other view stays the same
        return (AnyView(EmptyView()), .skip)
    }

    // MARK: - Deploy Handling

    /// Clears failure state for a deployment, called when user clicks retry
    func clearDeploymentFailure(toolCallId: String) {
        deploymentFailures.removeValue(forKey: toolCallId)
    }

    /// Handles deployment when user clicks "Sign & Deploy"
    func handleDeploy(
        input: DeployInput,
        toolCallId: String
    ) async -> DeploymentState {
        guard let context = modelContext, let signer = walletSigner else {
            return .failed("Dependencies not configured")
        }

        // 1. Validate and get endpoint from input (not selected endpoint)
        guard let endpointIdStr = input.endpointId,
              let endpointId = UUID(uuidString: endpointIdStr)
        else {
            return .failed("Invalid endpoint ID")
        }

        let descriptor = FetchDescriptor<Endpoint>(
            predicate: #Predicate { $0.id == endpointId }
        )
        guard let endpoint = try? context.fetch(descriptor).first else {
            return .failed("Endpoint not found")
        }

        // 2. Validate source code
        guard let sourceCode = input.sourceCode, !sourceCode.isEmpty else {
            return .failed("Source code is required")
        }

        // 3. Compile source code
        let viewModel = ContractDeploymentViewModel(modelContext: context, walletSigner: signer)
        let compilationResult: (bytecode: String, abi: String)
        do {
            compilationResult = try await viewModel.compileSolidity(sourceCode)
        } catch {
            return .failed("Compilation failed: \(error.localizedDescription)")
        }

        // 4. Extract constructor parameters from ABI and match with input.constructorArgs
        let parser = try? AbiParser(fromJsonString: compilationResult.abi)
        var constructorParams: [TransactionParameter] = []
        if let constructor = parser?.constructor, let inputs = constructor.inputs {
            for abiInput in inputs {
                let paramName = abiInput.name.isEmpty ? "(unnamed)" : abiInput.name
                let value = input.constructorArgs?[paramName] ?? ""
                let param = TransactionParameter(
                    name: paramName,
                    type: (try? SolidityType(parsing: abiInput.type)) ?? .string,
                    value: AnyCodable(value)
                )
                constructorParams.append(param)
            }
        }

        // 5. Parse value
        let txValue: TransactionValue
        if let valueStr = input.value, let weiValue = BigInt(valueStr) {
            txValue = .wei(.init(bigInt: weiValue))
        } else {
            txValue = .ether(.init(bigInt: .zero))
        }

        // 6. Queue deployment transaction
        do {
            let queuedTx = try await viewModel.deployBytecodeToNetwork(
                compilationResult.bytecode,
                abi: parser?.items ?? [],
                endpoint: endpoint,
                value: txValue,
                constructorParameters: constructorParams
            )

            // 7. Store pending deployment with full metadata for saving contract after success
            let deploymentInfo = PendingDeploymentInfo(
                toolCallId: toolCallId,
                name: input.name ?? "Deployed Contract",
                sourceCode: sourceCode,
                abiJson: compilationResult.abi,
                bytecode: compilationResult.bytecode,
                endpointId: endpoint.id
            )
            pendingDeployments[queuedTx.id] = deploymentInfo

            return .deploying

        } catch {
            return .failed("Failed to queue transaction: \(error.localizedDescription)")
        }
    }

    // MARK: - Write Call Handling

    /// Clears failure state for a write call, called when user clicks retry
    func clearWriteCallFailure(toolCallId: String) {
        writeCallFailures.removeValue(forKey: toolCallId)
    }

    /// Handles write call when user clicks "Sign & Send"
    func handleWriteCall(
        input: CallWriteInput,
        toolCallId: String
    ) async -> WriteCallState {
        guard let context = modelContext, let signer = walletSigner else {
            return .failed("Dependencies not configured")
        }

        // 1. Get contract
        guard let contractId = UUID(uuidString: input.contractId) else {
            return .failed("Invalid contract ID")
        }

        let descriptor = FetchDescriptor<EVMContract>(
            predicate: #Predicate { $0.id == contractId }
        )
        guard let contract = try? context.fetch(descriptor).first else {
            return .failed("Contract not found")
        }

        guard let abi = contract.abi else {
            return .failed("No ABI attached to contract")
        }

        // 2. Parse ABI and find function
        guard let parser = try? AbiParser(fromJsonString: abi.abiContent) else {
            return .failed("Failed to parse ABI")
        }

        guard let abiFunction = parser.items.first(where: {
            $0.type == .function && $0.name == input.functionName
        }) else {
            return .failed("Function '\(input.functionName)' not found in ABI")
        }

        // 3. Build parameters
        var params: [TransactionParameter] = []
        if let args = input.args {
            for abiInput in abiFunction.inputs ?? [] {
                if let value = args[abiInput.name ?? ""] {
                    if let param = try? TransactionParameter(
                        name: abiInput.name ?? "",
                        typeString: abiInput.type,
                        value: AnyCodable(value)
                    ) {
                        params.append(param)
                    }
                }
            }
        }

        // 4. Parse value
        let txValue: TransactionValue
        if let valueStr = input.value, let weiValue = BigInt(valueStr) {
            txValue = .wei(.init(bigInt: weiValue))
        } else if let valueStr = input.value, let etherValue = Double(valueStr) {
            let weiAmount = BigInt(etherValue * 1e18)
            txValue = .wei(.init(bigInt: weiAmount))
        } else {
            txValue = .ether(.init(bigInt: .zero))
        }

        // 5. Create and queue transaction
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

        signer.queueTransaction(tx: queuedTx)

        // 6. Track pending call
        pendingWriteCalls[queuedTx.id] = toolCallId

        return .executing
    }

    // MARK: - Transaction Event Handling

    /// Handles transaction events from WalletSignerViewModel
    @MainActor
    private func handleTransactionEvent(_ event: TransactionEvent) async {
        switch event {
        case .contractCreated(let txHash, let contractAddress, let transaction):
            // Find deployment info by transaction ID
            guard let deploymentInfo = pendingDeployments[transaction.id] else { return }

            // Fetch the endpoint for the relationship
            let endpointId = deploymentInfo.endpointId
            let endpointDescriptor = FetchDescriptor<Endpoint>(
                predicate: #Predicate { $0.id == endpointId }
            )
            let endpoint = try? modelContext.fetch(endpointDescriptor).first

            // Create and save ABI
            let abiRecord = EvmAbi(
                name: "\(deploymentInfo.name) ABI",
                abiContent: deploymentInfo.abiJson
            )
            modelContext.insert(abiRecord)

            // Create and save Contract
            let contract = EVMContract(
                name: deploymentInfo.name,
                address: contractAddress,
                abiId: abiRecord.id,
                status: .deployed,
                type: .solidity,
                endpointId: deploymentInfo.endpointId
            )
            contract.sourceCode = deploymentInfo.sourceCode
            contract.bytecode = deploymentInfo.bytecode
            contract.abi = abiRecord
            contract.endpoint = endpoint
            modelContext.insert(contract)

            try? modelContext.save()

            // Track success for UI update
            deploymentSuccesses[deploymentInfo.toolCallId] = contractAddress

            // Send success result via chatProvider
            let output = DeployOutput(
                success: true,
                contractAddress: contractAddress,
                txHash: txHash,
                message: "Contract deployed and saved successfully at \(contractAddress)",
                pendingConfirmation: false,
                contractId: contract.id.uuidString,
                abiId: abiRecord.id.uuidString
            )
            try? await chatProvider?.sendFunctionResult(id: deploymentInfo.toolCallId, result: output)
            pendingDeployments.removeValue(forKey: transaction.id)

        case .sent(let txHash, let transaction):
            // Check if this is a write call (not a deployment)
            if let toolCallId = pendingWriteCalls[transaction.id] {
                // Track success for UI update
                writeCallSuccesses[toolCallId] = txHash

                // Send success result via chatProvider
                let output = CallWriteOutput(
                    success: true,
                    txHash: txHash,
                    message: "Transaction sent successfully",
                    pendingConfirmation: false
                )
                try? await chatProvider?.sendFunctionResult(id: toolCallId, result: output)
                pendingWriteCalls.removeValue(forKey: transaction.id)
            }

        case .rejected(let transaction):
            // Check if this is a deployment
            if let deploymentInfo = pendingDeployments[transaction.id] {
                // Track rejection for UI update
                deploymentFailures[deploymentInfo.toolCallId] = "Transaction rejected by user"

                let output = DeployOutput(
                    success: false,
                    contractAddress: nil,
                    txHash: nil,
                    message: "Transaction rejected by user",
                    pendingConfirmation: false,
                    contractId: nil,
                    abiId: nil
                )
                try? await chatProvider?.sendFunctionResult(id: deploymentInfo.toolCallId, result: output)
                pendingDeployments.removeValue(forKey: transaction.id)
            }
            // Check if this is a write call
            else if let toolCallId = pendingWriteCalls[transaction.id] {
                // Track rejection for UI update
                writeCallFailures[toolCallId] = "Transaction rejected by user"

                let output = CallWriteOutput(
                    success: false,
                    txHash: nil,
                    message: "Transaction rejected by user",
                    pendingConfirmation: false
                )
                try? await chatProvider?.sendFunctionResult(id: toolCallId, result: output)
                pendingWriteCalls.removeValue(forKey: transaction.id)
            }

        case .error(let error, let transaction):
            guard let transaction else { return }

            // Check if this is a deployment
            if let deploymentInfo = pendingDeployments[transaction.id] {
                // Track error for UI update
                let errorMessage = "Deployment failed: \(error.localizedDescription)"
                deploymentFailures[deploymentInfo.toolCallId] = errorMessage

                let output = DeployOutput(
                    success: false,
                    contractAddress: nil,
                    txHash: nil,
                    message: errorMessage,
                    pendingConfirmation: false,
                    contractId: nil,
                    abiId: nil
                )
                try? await chatProvider?.sendFunctionResult(id: deploymentInfo.toolCallId, result: output)
                pendingDeployments.removeValue(forKey: transaction.id)
            }
            // Check if this is a write call
            else if let toolCallId = pendingWriteCalls[transaction.id] {
                // Track error for UI update
                let errorMessage = "Call failed: \(error.localizedDescription)"
                writeCallFailures[toolCallId] = errorMessage

                let output = CallWriteOutput(
                    success: false,
                    txHash: nil,
                    message: errorMessage,
                    pendingConfirmation: false
                )
                try? await chatProvider?.sendFunctionResult(id: toolCallId, result: output)
                pendingWriteCalls.removeValue(forKey: transaction.id)
            }

        default:
            break
        }
    }
}
