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

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI:
            return "OpenAI"
        }
    }

    var defaultEndpoint: String {
        switch self {
        case .openAI:
            return "https://api.openai.com/v1"
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
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        type: ProviderType = .openAI,
        apiKey: String = "",
        endpoint: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.apiKey = apiKey
        self.endpoint = endpoint.isEmpty ? type.defaultEndpoint : endpoint
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
