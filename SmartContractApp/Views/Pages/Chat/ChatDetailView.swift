//
//  ChatDetailView.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/20/25.
//

import Agent
import AgentLayout
import SwiftData
import SwiftUI

struct ChatDetailView: View {
    let chat: ChatHistory?

    @Environment(ChatViewModel.self) private var chatViewModel
    @Environment(ToolRegistry.self) private var toolRegistry
    @Environment(ChatProvider.self) private var chatProvider
    @Query(sort: \AIProvider.name) private var providers: [AIProvider]

    @State private var agentChat: Chat?
    @State private var currentChatId: UUID? // Track which chat is initialized to prevent unnecessary re-initialization

    var body: some View {
        Group {
            if providers.isEmpty {
                noProvidersView
            } else if let chat = chat {
                chatContentView(for: chat)
            } else {
                noChatSelectedView
            }
        }
        .onAppear {
            chatViewModel.loadProviders()
        }
    }

    // MARK: - No Providers View

    private var noProvidersView: some View {
        ContentUnavailableView {
            Label("No Providers Configured", systemImage: "server.rack")
        } description: {
            Text("Add an AI provider in Settings to start chatting")
        } actions: {
            Button("Open Settings") {
                openSettings()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier(.chat.openSettingsButton)
        }
    }

    // MARK: - No Chat Selected View

    private var noChatSelectedView: some View {
        ContentUnavailableView(
            "No Chat Selected",
            systemImage: "bubble.right",
            description: Text("Select a chat from the sidebar or create a new one")
        )
    }

    // MARK: - Chat Content View

    @ViewBuilder
    private func chatContentView(for chat: ChatHistory) -> some View {
        if let agentChat = agentChat,
           let currentModel = chatViewModel.currentModel,
           let currentSource = chatViewModel.currentSource
        {
            AgentLayout(
                chatProvider: chatProvider,
                chat: agentChat,
                currentModel: Binding(
                    get: { currentModel },
                    set: { newModel in
                        let modelId: String
                        switch newModel {
                        case .openAI(let model):
                            modelId = model.id

                        case .openRouter(let model):
                            modelId = model.id

                        case .custom(let model):
                            modelId = model.id
                        }
                        chatViewModel.selectModel(modelId)
                        chat.model = modelId
                        chat.updatedAt = Date()
                    }
                ),
                currentSource: Binding(
                    get: { currentSource },
                    set: { newSource in
                        // Find the provider matching this source
                        if let provider = providers.first(where: { $0.name == newSource.displayName }) {
                            chatViewModel.selectProvider(provider)
                            chat.providerId = provider.id
                            chat.updatedAt = Date()

                            // Fetch models if needed
                            Task {
                                await chatViewModel.fetchModelsIfNeeded(for: provider)
                            }
                        }
                    }
                ),
                sources: chatViewModel.sources,
                tools: toolRegistry.createTools(), onSend: { message in
                    handleSendMessage(message, chat: chat)
                }, onMessage: { message in
                    // Save or update assistant messages and tool results to persistent storage
                    // Uses saveOrUpdateMessage to handle streaming updates where the same message ID
                    // is updated multiple times (e.g., during streaming responses)
                    chatViewModel.saveOrUpdateMessage(message, to: chat)
                }, onDelete: { index in
                    // Remove message from chat history
                    chatViewModel.removeMessage(at: index, from: chat)

                    // Trigger a re-render by updating the chat
                    setupChat(chat)
                }, onEdit: { index, newMessage in
                    // Edit message in chat history
                    chatViewModel.editMessage(at: index, with: newMessage, in: chat)

                    // Trigger a re-render by updating the chat
                    setupChat(chat)
                }, renderMessage: toolRegistry.createMessageRenderer()
            )
            .frame(maxWidth: 960)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: chat.id) { _, _ in
                setupChat(chat)
            }
            .onAppear {
                setupChat(chat)
            }
        } else {
            ContentUnavailableView {
                Label("Loading...", systemImage: "ellipsis")
            } description: {
                Text("Setting up chat...")
            }
            .onAppear {
                // Only call setupChat if agentChat is nil
                // This prevents re-initialization when the view switches to loading state
                // due to currentModel/currentSource being temporarily nil
                if agentChat == nil {
                    setupChat(chat)
                }
            }
        }
    }

    // MARK: - Setup

    private func setupChat(_ chat: ChatHistory) {
        // Only reinitialize agentChat if it's a different chat to prevent losing in-flight messages
        // This fixes the issue where switching to loading view (due to currentModel/currentSource being nil)
        // would cause setupChat to be called again and reinitialize agentChat from persistent storage
        if currentChatId != chat.id {
            agentChat = chatViewModel.convertToChat(chat)
            currentChatId = chat.id
        }

        // Restore provider selection
        if let providerId = chat.providerId,
           let provider = providers.first(where: { $0.id == providerId })
        {
            chatViewModel.selectProvider(provider)

            // Fetch models if needed
            Task {
                await chatViewModel.fetchModelsIfNeeded(for: provider)
            }
        } else if let first = providers.first {
            // Default to first provider
            chatViewModel.selectProvider(first)

            Task {
                await chatViewModel.fetchModelsIfNeeded(for: first)
            }
        }

        // Restore model selection
        if let modelId = chat.model {
            chatViewModel.selectModel(modelId)
        }
    }

    // MARK: - Message Handling

    private func handleSendMessage(_ message: Message, chat: ChatHistory) {
        // Save the message to chat history
        chatViewModel.saveMessage(message, to: chat)

        // Update provider/model info on chat
        if let provider = chatViewModel.currentProvider,
           let model = chatViewModel.currentModel
        {
            let modelId: String
            switch model {
            case .openAI(let openAIModel):
                modelId = openAIModel.id
            case .openRouter(let openRouterModel):
                modelId = openRouterModel.id
            case .custom(let customModel):
                modelId = customModel.id
            }
            chatViewModel.updateChatProvider(chat, provider: provider, modelId: modelId)
        }
    }

    // MARK: - Actions

    private func openSettings() {
        #if os(macOS)
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        #endif
    }
}

#Preview("With Chat") {
    let container = try! ModelContainer(
        for: ChatHistory.self, AIProvider.self, Endpoint.self, EVMContract.self, EvmAbi.self, EVMWallet.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let chat = ChatHistory(title: "Test Chat", messages: [])
    container.mainContext.insert(chat)

    let provider = AIProvider(
        name: "Test Provider",
        type: .openAI,
        apiKey: "test-key",
        availableModels: ["gpt-4o", "gpt-4o-mini"]
    )
    container.mainContext.insert(provider)

    let viewModel = ChatViewModel()
    viewModel.modelContext = container.mainContext

    let walletSigner = WalletSignerViewModel()
    walletSigner.modelContext = container.mainContext

    let toolRegistry = ToolRegistry()
    toolRegistry.modelContext = container.mainContext
    toolRegistry.walletSigner = walletSigner

    return ChatDetailView(chat: chat)
        .modelContainer(container)
        .environment(viewModel)
        .environment(toolRegistry)
}

#Preview("No Chat") {
    let container = try! ModelContainer(
        for: ChatHistory.self, AIProvider.self, Endpoint.self, EVMContract.self, EvmAbi.self, EVMWallet.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let provider = AIProvider(
        name: "Test Provider",
        type: .openAI,
        apiKey: "test-key",
        availableModels: ["gpt-4o"]
    )
    container.mainContext.insert(provider)

    let viewModel = ChatViewModel()
    viewModel.modelContext = container.mainContext

    let walletSigner = WalletSignerViewModel()
    walletSigner.modelContext = container.mainContext

    let toolRegistry = ToolRegistry()
    toolRegistry.modelContext = container.mainContext
    toolRegistry.walletSigner = walletSigner

    return ChatDetailView(chat: nil)
        .modelContainer(container)
        .environment(viewModel)
        .environment(toolRegistry)
}

#Preview("No Providers") {
    let container = try! ModelContainer(
        for: ChatHistory.self, AIProvider.self, Endpoint.self, EVMContract.self, EvmAbi.self, EVMWallet.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let viewModel = ChatViewModel()
    viewModel.modelContext = container.mainContext

    let walletSigner = WalletSignerViewModel()
    walletSigner.modelContext = container.mainContext

    let toolRegistry = ToolRegistry()
    toolRegistry.modelContext = container.mainContext
    toolRegistry.walletSigner = walletSigner

    return ChatDetailView(chat: nil)
        .modelContainer(container)
        .environment(viewModel)
        .environment(toolRegistry)
}
