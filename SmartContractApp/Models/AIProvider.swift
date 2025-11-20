//
//  AIProvider.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/20/25.
//

import Foundation
import SwiftData

enum ProviderType: String, Codable, CaseIterable, Identifiable {
    case openAI
    case openRouter

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI:
            return "OpenAI"
        case .openRouter:
            return "OpenRouter"
        }
    }

    var defaultEndpoint: String {
        switch self {
        case .openAI:
            return "https://api.openai.com/v1"
        case .openRouter:
            return "https://openrouter.ai/api/v1"
        }
    }

    /// Whether the user can customize the endpoint URL
    var supportsCustomEndpoint: Bool {
        switch self {
        case .openAI:
            return true
        case .openRouter:
            return false
        }
    }

    /// Whether the provider supports auto-fetching models
    var supportsAutoFetchModels: Bool {
        switch self {
        case .openAI:
            return true
        case .openRouter:
            return true
        }
    }
}

@Model
final class AIProvider {
    var id: UUID
    var name: String
    var type: ProviderType
    var apiKey: String
    var endpoint: String
    var availableModels: [String]
    var autoFetchModels: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        type: ProviderType = .openAI,
        apiKey: String = "",
        endpoint: String = "",
        availableModels: [String] = [],
        autoFetchModels: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.apiKey = apiKey
        self.endpoint = endpoint.isEmpty ? type.defaultEndpoint : endpoint
        self.availableModels = availableModels
        self.autoFetchModels = autoFetchModels
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
