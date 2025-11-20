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
    @Query(sort: \AIProvider.name) private var providers: [AIProvider]

    @State private var agentChat: Chat?
    @State private var selectedProviderId: UUID?
    @State private var selectedModelId: String?

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
        VStack(spacing: 0) {
            // Provider/Model selector toolbar
            providerModelSelector(for: chat)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // AgentLayout chat interface
            if let agentChat = agentChat,
                let currentModel = chatViewModel.currentModel,
                let currentSource = chatViewModel.currentSource
            {
                AgentLayout(
                    chat: agentChat,
                    currentModel: Binding(
                        get: { currentModel },
                        set: { newModel in
                            if case .openAI(let model) = newModel {
                                chatViewModel.selectModel(model.id)
                                chat.model = model.id
                                chat.updatedAt = Date()
                            }
                        }
                    ),
                    currentSource: Binding(
                        get: { currentSource },
                        set: { _ in }
                    ),
                    sources: chatViewModel.sources,
                    onSend: { message in
                        handleSendMessage(message, chat: chat)
                    }
                )
            } else {
                ContentUnavailableView {
                    Label("Select Provider & Model", systemImage: "cpu")
                } description: {
                    Text("Choose a provider and model to start chatting")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: chat.id) { _, _ in
            setupChat(chat)
        }
        .onAppear {
            setupChat(chat)
        }
    }

    // MARK: - Provider/Model Selector

    @ViewBuilder
    private func providerModelSelector(for chat: ChatHistory) -> some View {
        HStack {
            // Provider Picker
            Picker("Provider", selection: $selectedProviderId) {
                Text("Select Provider").tag(nil as UUID?)
                ForEach(providers) { provider in
                    Text(provider.name).tag(provider.id as UUID?)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 200)
            .accessibilityIdentifier(.chat.providerPicker)
            .onChange(of: selectedProviderId) { _, newValue in
                if let providerId = newValue,
                    let provider = providers.first(where: { $0.id == providerId })
                {
                    chatViewModel.selectProvider(provider)
                    chat.providerId = providerId
                    chat.updatedAt = Date()

                    // Fetch models if needed
                    Task {
                        await chatViewModel.fetchModelsIfNeeded(for: provider)
                    }
                }
            }

            // Model Picker
            if let provider = providers.first(where: { $0.id == selectedProviderId }) {
                Picker("Model", selection: $selectedModelId) {
                    Text("Select Model").tag(nil as String?)
                    ForEach(provider.availableModels, id: \.self) { modelId in
                        Text(modelId).tag(modelId as String?)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 300)
                .accessibilityIdentifier(.chat.modelPicker)
                .onChange(of: selectedModelId) { _, newValue in
                    if let modelId = newValue {
                        chatViewModel.selectModel(modelId)
                        chat.model = modelId
                        chat.updatedAt = Date()
                    }
                }
            }

            Spacer()
        }
    }

    // MARK: - Setup

    private func setupChat(_ chat: ChatHistory) {
        // Convert ChatHistory to AgentKit Chat
        agentChat = chatViewModel.convertToChat(chat)

        // Restore provider selection
        if let providerId = chat.providerId,
            let provider = providers.first(where: { $0.id == providerId })
        {
            selectedProviderId = providerId
            chatViewModel.selectProvider(provider)

            // Fetch models if needed
            Task {
                await chatViewModel.fetchModelsIfNeeded(for: provider)
            }
        } else if let first = providers.first {
            // Default to first provider
            selectedProviderId = first.id
            chatViewModel.selectProvider(first)

            Task {
                await chatViewModel.fetchModelsIfNeeded(for: first)
            }
        }

        // Restore model selection
        if let modelId = chat.model {
            selectedModelId = modelId
            chatViewModel.selectModel(modelId)
        }
    }

    // MARK: - Message Handling

    private func handleSendMessage(_ message: String, chat: ChatHistory) {
        // Create user message
        let userMessage = Message.openai(.user(.init(content: message)))

        // Save to chat history
        chatViewModel.saveMessage(userMessage, to: chat)

        // Update agent chat
        agentChat?.messages.append(userMessage)

        // Update provider/model info on chat
        if let provider = chatViewModel.currentProvider,
            let model = chatViewModel.currentModel
        {
            if case .openAI(let openAIModel) = model {
                chatViewModel.updateChatProvider(chat, provider: provider, modelId: openAIModel.id)
            }
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
        for: ChatHistory.self, AIProvider.self,
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

    return ChatDetailView(chat: chat)
        .modelContainer(container)
        .environment(viewModel)
}

#Preview("No Chat") {
    let container = try! ModelContainer(
        for: ChatHistory.self, AIProvider.self,
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

    return ChatDetailView(chat: nil)
        .modelContainer(container)
        .environment(viewModel)
}

#Preview("No Providers") {
    let container = try! ModelContainer(
        for: ChatHistory.self, AIProvider.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let viewModel = ChatViewModel()
    viewModel.modelContext = container.mainContext

    return ChatDetailView(chat: nil)
        .modelContainer(container)
        .environment(viewModel)
}
