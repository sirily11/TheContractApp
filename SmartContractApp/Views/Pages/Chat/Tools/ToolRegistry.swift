//
//  ToolRegistry.swift
//  SmartContractApp
//
//  Created by Claude on 11/22/25.
//

import Agent
import AgentLayout
import EvmCore
import Foundation
import Observation
import SwiftData
import SwiftUI

// MARK: - Tool Registry

/// Central registry for all AI agent tools
/// Manages tool creation and pending operations that require user interaction
@Observable
@MainActor
final class ToolRegistry {
    // MARK: - Dependencies

    var modelContext: ModelContext!
    var walletSigner: WalletSignerViewModel!

    init() {}

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
        return { [weak self] message, messages, provider, status in
            guard let self = self else {
                return (AnyView(EmptyView()), .skip)
            }

            print(message, messages)

            // if the message is tool message
            if case .openai(let openAiMessage) = message {
                if case .tool(let openAiToolMessage) = openAiMessage {
                    return createToolMessageRenderer(message: openAiToolMessage, messages: messages, provider: provider, status: status)
                }
            }

//            // Check if this message is a deployment result
//            if let pending = self.pendingDeployment {
//                let view = DeploymentConfirmationView(
//                    deployment: pending,
//                    status: status,
//                    provider: provider,
//                    onComplete: {
//                        self.clearPendingDeployment()
//                    }
//                )
//                return (AnyView(view), .append)
//            }
//
//            // Check if this message is a write call result
//            if let pending = self.pendingWriteCall {
//                let view = WriteCallConfirmationView(
//                    writeCall: pending,
//                    status: status,
//                    provider: provider,
//                    onComplete: {
//                        self.clearPendingWriteCall()
//                    }
//                )
//                return (AnyView(view), .append)
//            }

            return (AnyView(EmptyView()), .skip)
        }
    }

    func createToolMessageRenderer(message: OpenAIToolMessage, messages: [Message], provider: (any ChatProvider)?, status: ToolStatus) -> (AnyView, RenderAction) {
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
}
