//
//  ChatViewModel.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/20/25.
//

import Agent
import Foundation
import Observation
import SwiftData

// MARK: - Stored Message Type

/// Simple struct for persisting messages to JSON
struct StoredMessage: Codable {
    enum Role: String, Codable {
        case user
        case assistant
        case system
        case tool
    }

    let id: String
    let role: Role
    let content: String
    let timestamp: Date

    init(id: String = UUID().uuidString, role: Role, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

// MARK: - Chat View Model

@Observable
final class ChatViewModel {
    // MARK: - Dependencies

    var modelContext: ModelContext!

    // MARK: - State

    var providers: [AIProvider] = []
    var currentProvider: AIProvider?
    var currentModel: Model?
    var currentSource: Source?
    var sources: [Source] = []
    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// Load all providers from the database
    func loadProviders() {
        let descriptor = FetchDescriptor<AIProvider>(
            sortBy: [SortDescriptor(\.name)]
        )

        do {
            providers = try modelContext.fetch(descriptor)
            sources = providers.map { convertToSource($0) }

            // Auto-select first provider if none selected
            if currentProvider == nil, let first = providers.first {
                selectProvider(first)
            }
        } catch {
            errorMessage = "Failed to load providers: \(error.localizedDescription)"
        }
    }

    /// Select a provider and update current model/source
    func selectProvider(_ provider: AIProvider) {
        currentProvider = provider
        currentSource = convertToSource(provider)

        // Select first available model
        if let firstModel = provider.availableModels.first {
            selectModel(firstModel)
        } else {
            currentModel = nil
        }
    }

    /// Select a model by ID
    func selectModel(_ modelId: String) {
        guard let provider = currentProvider else { return }

        // Create Model based on provider type
        let model: Model
        switch provider.type {
        case .openAI, .openRouter:
            model = .openAI(OpenAICompatibleModel(id: modelId, name: modelId))
        }

        currentModel = model
    }

    /// Get provider for a chat (by providerId)
    func getProvider(for chat: ChatHistory) -> AIProvider? {
        guard let providerId = chat.providerId else { return nil }
        return providers.first { $0.id == providerId }
    }

    /// Convert ChatHistory messages to AgentKit Chat
    func convertToChat(_ chatHistory: ChatHistory) -> Chat {
        let messages = chatHistory.messages.compactMap { jsonString -> Message? in
            guard let data = jsonString.data(using: .utf8),
                let stored = try? JSONDecoder().decode(StoredMessage.self, from: data)
            else {
                return nil
            }

            return storedMessageToAgentMessage(stored)
        }

        return Chat(
            id: chatHistory.id,
            gameId: chatHistory.id.uuidString,
            messages: messages
        )
    }

    /// Convert AgentKit Message to stored format
    func agentMessageToStored(_ message: Message) -> StoredMessage? {
        switch message {
        case .openai(let openAIMessage):
            switch openAIMessage {
            case .user(let userMessage):
                return StoredMessage(
                    role: .user,
                    content: userMessage.content
                )
            case .assistant(let assistantMessage):
                return StoredMessage(
                    role: .assistant,
                    content: assistantMessage.content ?? ""
                )
            case .system(let systemMessage):
                return StoredMessage(
                    role: .system,
                    content: systemMessage.content
                )
            case .tool(let toolMessage):
                return StoredMessage(
                    role: .tool,
                    content: toolMessage.content
                )
            }
        }
    }

    /// Convert stored message to AgentKit Message
    func storedMessageToAgentMessage(_ stored: StoredMessage) -> Message {
        switch stored.role {
        case .user:
            return .openai(.user(.init(content: stored.content)))
        case .assistant:
            return .openai(.assistant(.init(content: stored.content, audio: nil)))
        case .system:
            return .openai(.system(.init(content: stored.content)))
        case .tool:
            return .openai(.tool(.init(content: stored.content, toolCallId: stored.id)))
        }
    }

    /// Save a message to chat history
    func saveMessage(_ message: Message, to chat: ChatHistory) {
        guard let stored = agentMessageToStored(message),
            let data = try? JSONEncoder().encode(stored),
            let json = String(data: data, encoding: .utf8)
        else {
            return
        }

        chat.messages.append(json)
        chat.updatedAt = Date()
    }

    /// Update chat with provider and model info
    func updateChatProvider(_ chat: ChatHistory, provider: AIProvider, modelId: String) {
        chat.providerId = provider.id
        chat.model = modelId
        chat.updatedAt = Date()
    }

    /// Fetch models for a provider if auto-fetch is enabled
    func fetchModelsIfNeeded(for provider: AIProvider) async {
        guard provider.autoFetchModels,
            provider.availableModels.isEmpty,
            provider.type.supportsAutoFetchModels
        else {
            return
        }

        do {
            let models = try await ModelFetchService.shared.fetchModels(
                providerType: provider.type,
                endpoint: provider.endpoint,
                apiKey: provider.apiKey
            )

            await MainActor.run {
                provider.availableModels = models
                provider.updatedAt = Date()

                // Update source
                if currentProvider?.id == provider.id {
                    currentSource = convertToSource(provider)
                    if let firstModel = models.first {
                        selectModel(firstModel)
                    }
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to fetch models: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Private Methods

    /// Convert AIProvider to AgentKit Source
    private func convertToSource(_ provider: AIProvider) -> Source {
        let models: [Model] = provider.availableModels.map { modelId in
            switch provider.type {
            case .openAI, .openRouter:
                return .openAI(OpenAICompatibleModel(id: modelId, name: modelId))
            }
        }

        let apiType: ApiType
        switch provider.type {
        case .openAI, .openRouter:
            apiType = .openAI
        }

        return Source(
            displayName: provider.name,
            endpoint: provider.endpoint,
            apiKey: provider.apiKey,
            apiType: apiType,
            models: models
        )
    }
}
