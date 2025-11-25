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
        case .openAI:
            model = .openAI(OpenAICompatibleModel(id: modelId))
        case .openRouter:
            model = .openRouter(OpenAICompatibleModel(id: modelId, reasoningConfig: .default))
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
            guard let data = jsonString.data(using: .utf8) else {
                return nil
            }
            // Decode Message directly from JSON (preserves all fields including tool calls)
            return try? JSONDecoder().decode(Message.self, from: data)
        }

        return Chat(
            id: chatHistory.id,
            gameId: chatHistory.id.uuidString,
            messages: messages
        )
    }

    /// Save or update a message in chat history (handles streaming updates)
    func saveMessages(_ messages: [Message], to chat: ChatHistory) {
        let messages = messages.map {
            if let data = try? JSONEncoder().encode($0),
               let json = String(data: data, encoding: .utf8)
            {
                return json
            }
            return nil
        }.compactMap { $0 }
        chat.messages = messages
        chat.updatedAt = Date()
        try? modelContext.save()
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
        switch provider.type {
        case .openAI:
            let models: [Model] = provider.availableModels.map { modelId in
                .openAI(OpenAICompatibleModel(id: modelId))
            }

            // Create OpenAI client with custom endpoint if provided
            let client: OpenAIClient
            if let baseURL = URL(string: provider.endpoint) {
                client = OpenAIClient(apiKey: provider.apiKey, baseURL: baseURL)
            } else {
                client = OpenAIClient(apiKey: provider.apiKey)
            }

            return Source.openAI(client: client, models: models)

        case .openRouter:
            let models: [Model] = provider.availableModels.map { modelId in
                .openRouter(OpenAICompatibleModel(id: modelId))
            }

            let client = OpenRouterClient(
                apiKey: provider.apiKey,
                appName: "SmartContractApp"
            )

            return Source.openRouter(client: client, models: models)
        }
    }
}
