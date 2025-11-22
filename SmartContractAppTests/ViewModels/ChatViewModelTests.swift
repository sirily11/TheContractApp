//
//  ChatViewModelTests.swift
//  SmartContractAppTests
//
//  Created by Claude on 11/20/25.
//

import Agent
import Foundation
import SwiftData
import Testing
@testable import SmartContractApp

@Suite("ChatViewModel Tests")
struct ChatViewModelTests {
    // MARK: - Test Helpers

    /// Create a test model container with ChatHistory and AIProvider
    private func createTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: ChatHistory.self, AIProvider.self,
            configurations: config
        )
    }

    /// Create a test AIProvider
    private func createTestProvider(
        name: String = "Test Provider",
        apiKey: String = "test-key",
        models: [String] = ["gpt-4", "gpt-3.5-turbo"]
    ) -> AIProvider {
        return AIProvider(
            name: name,
            type: .openAI,
            apiKey: apiKey,
            endpoint: "https://api.openai.com/v1",
            availableModels: models
        )
    }

    // MARK: - Message Conversion Tests

    @Test("agentMessageToStored converts user message correctly")
    func testAgentMessageToStored_UserMessage() {
        let viewModel = ChatViewModel()

        let userMessage = Message.openai(.user(.init(content: "Hello, world!")))
        let stored = viewModel.agentMessageToStored(userMessage)

        #expect(stored != nil)
        #expect(stored?.role == .user)
        #expect(stored?.content == "Hello, world!")
    }

    @Test("agentMessageToStored converts assistant message correctly")
    func testAgentMessageToStored_AssistantMessage() {
        let viewModel = ChatViewModel()

        let assistantMessage = Message.openai(.assistant(.init(
            content: "Hi there!",
            toolCalls: nil,
            audio: nil
        )))
        let stored = viewModel.agentMessageToStored(assistantMessage)

        #expect(stored != nil)
        #expect(stored?.role == .assistant)
        #expect(stored?.content == "Hi there!")
    }

    @Test("storedMessageToAgentMessage converts back correctly")
    func testStoredMessageToAgentMessage() {
        let viewModel = ChatViewModel()

        let stored = StoredMessage(role: .user, content: "Test content")
        let message = viewModel.storedMessageToAgentMessage(stored)

        if case .openai(let openAIMsg) = message,
           case .user(let userMsg) = openAIMsg
        {
            #expect(userMsg.content == "Test content")
        } else {
            Issue.record("Expected user message")
        }
    }

    // MARK: - Message Persistence Tests

    @Test("saveMessage persists message to ChatHistory")
    @MainActor
    func testSaveMessage() throws {
        let container = try createTestContainer()
        let viewModel = ChatViewModel()
        viewModel.modelContext = container.mainContext

        let chat = ChatHistory(title: "Test Chat")
        container.mainContext.insert(chat)

        #expect(chat.messages.count == 0)

        // Save first message
        let userMessage = Message.openai(.user(.init(content: "First message")))
        viewModel.saveMessage(userMessage, to: chat)

        #expect(chat.messages.count == 1)

        // Save second message
        let assistantMessage = Message.openai(.assistant(.init(
            content: "First response",
            toolCalls: nil,
            audio: nil
        )))
        viewModel.saveMessage(assistantMessage, to: chat)

        #expect(chat.messages.count == 2)
    }

    @Test("convertToChat restores all messages from ChatHistory")
    @MainActor
    func testConvertToChat() throws {
        let container = try createTestContainer()
        let viewModel = ChatViewModel()
        viewModel.modelContext = container.mainContext

        let chat = ChatHistory(title: "Test Chat")
        container.mainContext.insert(chat)

        // Save multiple messages
        let userMessage1 = Message.openai(.user(.init(content: "First user message")))
        viewModel.saveMessage(userMessage1, to: chat)

        let assistantMessage1 = Message.openai(.assistant(.init(
            content: "First assistant response",
            toolCalls: nil,
            audio: nil
        )))
        viewModel.saveMessage(assistantMessage1, to: chat)

        let userMessage2 = Message.openai(.user(.init(content: "Second user message")))
        viewModel.saveMessage(userMessage2, to: chat)

        let assistantMessage2 = Message.openai(.assistant(.init(
            content: "Second assistant response",
            toolCalls: nil,
            audio: nil
        )))
        viewModel.saveMessage(assistantMessage2, to: chat)

        // Convert back to Chat
        let agentChat = viewModel.convertToChat(chat)

        // Verify all messages are restored
        #expect(agentChat.messages.count == 4, "Expected 4 messages but got \(agentChat.messages.count)")

        // Verify message contents
        let messageContents = agentChat.messages.compactMap { message -> String? in
            switch message {
            case .openai(let openAIMsg):
                switch openAIMsg {
                case .user(let userMsg):
                    return userMsg.content
                case .assistant(let assistantMsg):
                    return assistantMsg.content
                default:
                    return nil
                }
            }
        }

        #expect(messageContents[0] == "First user message")
        #expect(messageContents[1] == "First assistant response")
        #expect(messageContents[2] == "Second user message")
        #expect(messageContents[3] == "Second assistant response")
    }

    // MARK: - Multi-Turn Conversation Tests

    @Test("Multi-turn conversation preserves all messages")
    @MainActor
    func testMultiTurnConversation() throws {
        let container = try createTestContainer()
        let viewModel = ChatViewModel()
        viewModel.modelContext = container.mainContext

        let chat = ChatHistory(title: "Test Chat")
        container.mainContext.insert(chat)

        // Simulate multi-turn conversation
        // Turn 1: User sends first message
        let userMessage1 = Message.openai(.user(.init(content: "Hello, how are you?")))
        viewModel.saveMessage(userMessage1, to: chat)
        #expect(chat.messages.count == 1, "After first user message: expected 1")

        // Turn 1: Assistant responds
        let assistantMessage1 = Message.openai(.assistant(.init(
            content: "I'm doing well, thank you! How can I help you today?",
            toolCalls: nil,
            audio: nil
        )))
        viewModel.saveMessage(assistantMessage1, to: chat)
        #expect(chat.messages.count == 2, "After first assistant response: expected 2")

        // Turn 2: User sends second message
        let userMessage2 = Message.openai(.user(.init(content: "Can you explain smart contracts?")))
        viewModel.saveMessage(userMessage2, to: chat)
        #expect(chat.messages.count == 3, "After second user message: expected 3")

        // Turn 2: Assistant responds
        let assistantMessage2 = Message.openai(.assistant(.init(
            content: "Smart contracts are self-executing contracts with terms written in code.",
            toolCalls: nil,
            audio: nil
        )))
        viewModel.saveMessage(assistantMessage2, to: chat)
        #expect(chat.messages.count == 4, "After second assistant response: expected 4")

        // Verify all messages are still present after converting to Chat
        let agentChat = viewModel.convertToChat(chat)
        #expect(agentChat.messages.count == 4, "All 4 messages should be preserved")

        // Verify the first message is still there (the bug was first message disappearing)
        if case .openai(let firstMsg) = agentChat.messages[0],
           case .user(let userMsg) = firstMsg
        {
            #expect(userMsg.content == "Hello, how are you?", "First message should be preserved")
        } else {
            Issue.record("First message should be a user message")
        }
    }

    @Test("Multiple convertToChat calls preserve messages")
    @MainActor
    func testMultipleConvertToChat() throws {
        let container = try createTestContainer()
        let viewModel = ChatViewModel()
        viewModel.modelContext = container.mainContext

        let chat = ChatHistory(title: "Test Chat")
        container.mainContext.insert(chat)

        // Save first message
        let userMessage1 = Message.openai(.user(.init(content: "First message")))
        viewModel.saveMessage(userMessage1, to: chat)

        // First conversion
        let agentChat1 = viewModel.convertToChat(chat)
        #expect(agentChat1.messages.count == 1)

        // Save more messages
        let assistantMessage = Message.openai(.assistant(.init(
            content: "Response",
            toolCalls: nil,
            audio: nil
        )))
        viewModel.saveMessage(assistantMessage, to: chat)

        let userMessage2 = Message.openai(.user(.init(content: "Second message")))
        viewModel.saveMessage(userMessage2, to: chat)

        // Second conversion - should have all messages
        let agentChat2 = viewModel.convertToChat(chat)
        #expect(agentChat2.messages.count == 3, "Should have all 3 messages after re-conversion")

        // Verify first message still exists
        if case .openai(let firstMsg) = agentChat2.messages[0],
           case .user(let userMsg) = firstMsg
        {
            #expect(userMsg.content == "First message", "First message should still be 'First message'")
        } else {
            Issue.record("First message should be a user message")
        }
    }

    // MARK: - Provider Selection Tests

    @Test("selectProvider updates currentModel and currentSource")
    @MainActor
    func testSelectProvider() throws {
        let container = try createTestContainer()
        let viewModel = ChatViewModel()
        viewModel.modelContext = container.mainContext

        let provider = createTestProvider()
        container.mainContext.insert(provider)

        viewModel.selectProvider(provider)

        #expect(viewModel.currentProvider?.id == provider.id)
        #expect(viewModel.currentSource?.displayName == provider.name)
        #expect(viewModel.currentModel != nil)
    }

    @Test("selectModel updates currentModel")
    @MainActor
    func testSelectModel() throws {
        let container = try createTestContainer()
        let viewModel = ChatViewModel()
        viewModel.modelContext = container.mainContext

        let provider = createTestProvider(models: ["gpt-4", "gpt-3.5-turbo"])
        container.mainContext.insert(provider)

        viewModel.selectProvider(provider)
        viewModel.selectModel("gpt-3.5-turbo")

        if case .openAI(let model) = viewModel.currentModel {
            #expect(model.id == "gpt-3.5-turbo")
        } else {
            Issue.record("Expected OpenAI model")
        }
    }

    // MARK: - updateChatProvider Tests

    @Test("updateChatProvider updates chat metadata")
    @MainActor
    func testUpdateChatProvider() throws {
        let container = try createTestContainer()
        let viewModel = ChatViewModel()
        viewModel.modelContext = container.mainContext

        let chat = ChatHistory(title: "Test Chat")
        let provider = createTestProvider()
        container.mainContext.insert(chat)
        container.mainContext.insert(provider)

        let originalUpdatedAt = chat.updatedAt

        // Small delay to ensure different timestamp
        Thread.sleep(forTimeInterval: 0.01)

        viewModel.updateChatProvider(chat, provider: provider, modelId: "gpt-4")

        #expect(chat.providerId == provider.id)
        #expect(chat.model == "gpt-4")
        #expect(chat.updatedAt > originalUpdatedAt)
    }
}
