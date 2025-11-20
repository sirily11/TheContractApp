//
//  ModelFetchService.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/20/25.
//

import Foundation

// MARK: - Model Response Types

struct OpenAIModelsResponse: Codable {
    let data: [OpenAIModel]
}

struct OpenAIModel: Codable {
    let id: String
    let object: String?
    let created: Int?
    let ownedBy: String?

    enum CodingKeys: String, CodingKey {
        case id
        case object
        case created
        case ownedBy = "owned_by"
    }
}

struct OpenRouterModelsResponse: Codable {
    let data: [OpenRouterModel]
}

struct OpenRouterModel: Codable {
    let id: String
    let name: String?
    let description: String?
    let contextLength: Int?
    let pricing: OpenRouterPricing?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case contextLength = "context_length"
        case pricing
    }
}

struct OpenRouterPricing: Codable {
    let prompt: String?
    let completion: String?
}

// MARK: - Model Fetch Service

enum ModelFetchError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case unauthorized
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid endpoint URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .unauthorized:
            return "Invalid API key"
        case .serverError(let code):
            return "Server error (code: \(code))"
        }
    }
}

actor ModelFetchService {
    static let shared = ModelFetchService()

    private init() {}

    /// Fetch available models from a provider
    /// - Parameters:
    ///   - providerType: The type of provider
    ///   - endpoint: The API endpoint URL
    ///   - apiKey: The API key for authentication
    /// - Returns: Array of model IDs
    func fetchModels(
        providerType: ProviderType,
        endpoint: String,
        apiKey: String
    ) async throws -> [String] {
        switch providerType {
        case .openAI:
            return try await fetchOpenAIModels(endpoint: endpoint, apiKey: apiKey)
        case .openRouter:
            return try await fetchOpenRouterModels(endpoint: endpoint, apiKey: apiKey)
        }
    }

    // MARK: - Private Methods

    private func fetchOpenAIModels(endpoint: String, apiKey: String) async throws -> [String] {
        let urlString = endpoint.hasSuffix("/") ? "\(endpoint)models" : "\(endpoint)/models"
        guard let url = URL(string: urlString) else {
            throw ModelFetchError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ModelFetchError.networkError(
                NSError(domain: "ModelFetchService", code: -1, userInfo: nil))
        }

        if httpResponse.statusCode == 401 {
            throw ModelFetchError.unauthorized
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ModelFetchError.serverError(httpResponse.statusCode)
        }

        do {
            let modelsResponse = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)
            // Filter to chat models only (gpt-*)
            return modelsResponse.data
                .map { $0.id }
                .filter { $0.hasPrefix("gpt-") || $0.contains("chat") }
                .sorted()
        } catch {
            throw ModelFetchError.decodingError(error)
        }
    }

    private func fetchOpenRouterModels(endpoint: String, apiKey: String) async throws -> [String] {
        let urlString = endpoint.hasSuffix("/") ? "\(endpoint)models" : "\(endpoint)/models"
        guard let url = URL(string: urlString) else {
            throw ModelFetchError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ModelFetchError.networkError(
                NSError(domain: "ModelFetchService", code: -1, userInfo: nil))
        }

        if httpResponse.statusCode == 401 {
            throw ModelFetchError.unauthorized
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ModelFetchError.serverError(httpResponse.statusCode)
        }

        do {
            let modelsResponse = try JSONDecoder().decode(OpenRouterModelsResponse.self, from: data)
            return modelsResponse.data
                .map { $0.id }
                .sorted()
        } catch {
            throw ModelFetchError.decodingError(error)
        }
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch {
            throw ModelFetchError.networkError(error)
        }
    }
}
