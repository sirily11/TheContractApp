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

    var pendingDeployments: [UUID: String] = [:] // transactionId -> toolCallId

    /// Tracks failed/rejected deployments by toolCallId for UI updates
    /// Key: toolCallId, Value: error message (or empty for rejection)
    var deploymentFailures: [String: String] = [:]

    /// Tracks successful deployments by toolCallId for UI updates
    /// Key: toolCallId, Value: contract address
    var deploymentSuccesses: [String: String] = [:]

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
        default:
            break
        }
        return (AnyView(EmptyView()), .skip)
    }

    /**
     Creates a message renderer for tool resultss
     */
    func createOpenAiToolMessageRenderer(message: OpenAIToolMessage, messages: [Message], status: ToolStatus) -> (AnyView, RenderAction) {
        let uiToolNames = [DeployTools.name]
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

            // 7. Store pending deployment: transactionId -> toolCallId
            pendingDeployments[queuedTx.id] = toolCallId

            return .deploying

        } catch {
            return .failed("Failed to queue transaction: \(error.localizedDescription)")
        }
    }

    // MARK: - Transaction Event Handling

    /// Handles transaction events from WalletSignerViewModel
    @MainActor
    private func handleTransactionEvent(_ event: TransactionEvent) async {
        switch event {
        case .contractCreated(let txHash, let contractAddress, let transaction):
            // Find toolCallId by transaction ID
            guard let toolCallId = pendingDeployments[transaction.id] else { return }

            // Track success for UI update
            deploymentSuccesses[toolCallId] = contractAddress

            // Send success result via chatProvider
            let output = DeployOutput(
                success: true,
                contractAddress: contractAddress,
                txHash: txHash,
                message: "Contract deployed successfully at \(contractAddress)",
                pendingConfirmation: false
            )
            try? await chatProvider?.sendFunctionResult(id: toolCallId, result: output)
            pendingDeployments.removeValue(forKey: transaction.id)

        case .rejected(let transaction):
            guard let toolCallId = pendingDeployments[transaction.id] else { return }

            // Track rejection for UI update
            deploymentFailures[toolCallId] = "Transaction rejected by user"

            let output = DeployOutput(
                success: false,
                contractAddress: nil,
                txHash: nil,
                message: "Transaction rejected by user",
                pendingConfirmation: false
            )
            try? await chatProvider?.sendFunctionResult(id: toolCallId, result: output)
            pendingDeployments.removeValue(forKey: transaction.id)

        case .error(let error, let transaction):
            guard let transaction, let toolCallId = pendingDeployments[transaction.id] else { return }

            // Track error for UI update
            let errorMessage = "Deployment failed: \(error.localizedDescription)"
            deploymentFailures[toolCallId] = errorMessage

            let output = DeployOutput(
                success: false,
                contractAddress: nil,
                txHash: nil,
                message: errorMessage,
                pendingConfirmation: false
            )
            try? await chatProvider?.sendFunctionResult(id: toolCallId, result: output)
            pendingDeployments.removeValue(forKey: transaction.id)

        default:
            break
        }
    }
}
