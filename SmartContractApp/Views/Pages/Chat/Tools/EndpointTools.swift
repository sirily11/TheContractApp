//
//  EndpointTools.swift
//  SmartContractApp
//
//  Created by Claude on 11/22/25.
//

@preconcurrency import Agent
import Foundation
import JSONSchema
import SwiftData

// MARK: - Endpoint Manager Tool

enum EndpointTools {
    /// Creates the endpoint_manager tool for CRUD operations on endpoints
    static func endpointManagerTool(context: ModelContext) -> AgentTool<EndpointManagerInput, EndpointManagerOutput> {
        AgentTool(
            name: "endpoint_manager",
            description: """
                Manage RPC endpoints. Actions: list (get all endpoints), get (get endpoint by id), \
                create (create new endpoint), update (update endpoint), delete (delete endpoint).
                """,
            parameters: .object(
                description: "Endpoint manager parameters",
                properties: [
                    "action": .enum(
                        description: "The action to perform",
                        values: [.string("list"), .string("get"), .string("create"), .string("update"), .string("delete")]
                    ),
                    "id": .string(description: "Endpoint ID (required for get/update/delete)"),
                    "data": .object(
                        description: "Endpoint data (for create/update)",
                        properties: [
                            "name": .string(description: "Endpoint name"),
                            "url": .string(description: "RPC URL"),
                            "chainId": .string(description: "Chain ID"),
                            "autoDetect": .boolean(description: "Auto-detect chain ID from RPC"),
                            "nativeTokenSymbol": .string(description: "Native token symbol (e.g., ETH)"),
                            "nativeTokenName": .string(description: "Native token name (e.g., Ethereum)"),
                            "nativeTokenDecimals": .integer(description: "Native token decimals")
                        ],
                        required: []
                    )
                ],
                required: ["action"]
            ),
            execute: { input in
                switch input.action {
                case .list:
                    return try await listEndpoints(context: context)
                case .get:
                    guard let id = input.id else {
                        throw SmartContractToolError.missingRequiredField("id")
                    }
                    return try await getEndpoint(context: context, id: id)
                case .create:
                    guard let data = input.data else {
                        throw SmartContractToolError.missingRequiredField("data")
                    }
                    return try await createEndpoint(context: context, data: data)
                case .update:
                    guard let id = input.id else {
                        throw SmartContractToolError.missingRequiredField("id")
                    }
                    guard let data = input.data else {
                        throw SmartContractToolError.missingRequiredField("data")
                    }
                    return try await updateEndpoint(context: context, id: id, data: data)
                case .delete:
                    guard let id = input.id else {
                        throw SmartContractToolError.missingRequiredField("id")
                    }
                    return try await deleteEndpoint(context: context, id: id)
                }
            }
        )
    }

    // MARK: - Private Methods

    private static func listEndpoints(context: ModelContext) async throws -> EndpointManagerOutput {
        let descriptor = FetchDescriptor<Endpoint>(
            sortBy: [SortDescriptor(\Endpoint.createdAt, order: .reverse)]
        )
        let endpoints = try context.fetch(descriptor)

        let endpointInfos = endpoints.map { endpoint in
            EndpointInfo(
                id: endpoint.id.uuidString,
                name: endpoint.name,
                url: endpoint.url,
                chainId: endpoint.chainId,
                autoDetect: endpoint.autoDetectChainId,
                nativeTokenSymbol: endpoint.nativeTokenSymbol,
                nativeTokenName: endpoint.nativeTokenName,
                nativeTokenDecimals: endpoint.nativeTokenDecimals
            )
        }

        return EndpointManagerOutput(
            success: true,
            message: "Found \(endpoints.count) endpoint(s)",
            endpoint: nil,
            endpoints: endpointInfos
        )
    }

    private static func getEndpoint(context: ModelContext, id: String) async throws -> EndpointManagerOutput {
        guard let uuid = UUID(uuidString: id) else {
            throw SmartContractToolError.invalidId(id)
        }

        let descriptor = FetchDescriptor<Endpoint>(
            predicate: #Predicate { $0.id == uuid }
        )
        let endpoints = try context.fetch(descriptor)

        guard let endpoint = endpoints.first else {
            throw SmartContractToolError.notFound(entity: "Endpoint", id: id)
        }

        let endpointInfo = EndpointInfo(
            id: endpoint.id.uuidString,
            name: endpoint.name,
            url: endpoint.url,
            chainId: endpoint.chainId,
            autoDetect: endpoint.autoDetectChainId,
            nativeTokenSymbol: endpoint.nativeTokenSymbol,
            nativeTokenName: endpoint.nativeTokenName,
            nativeTokenDecimals: endpoint.nativeTokenDecimals
        )

        return EndpointManagerOutput(
            success: true,
            message: "Endpoint found",
            endpoint: endpointInfo,
            endpoints: nil
        )
    }

    private static func createEndpoint(context: ModelContext, data: EndpointData) async throws -> EndpointManagerOutput {
        guard let name = data.name, !name.isEmpty else {
            throw SmartContractToolError.missingRequiredField("name")
        }
        guard let url = data.url, !url.isEmpty else {
            throw SmartContractToolError.missingRequiredField("url")
        }

        // Validate URL
        guard URL(string: url) != nil else {
            throw SmartContractToolError.invalidEndpointUrl(url)
        }

        let endpoint = Endpoint(
            name: name,
            url: url,
            chainId: data.chainId ?? "1",
            autoDetectChainId: data.autoDetect ?? false,
            nativeTokenSymbol: data.nativeTokenSymbol ?? "ETH",
            nativeTokenName: data.nativeTokenName ?? "Ethereum",
            nativeTokenDecimals: data.nativeTokenDecimals ?? 18
        )

        context.insert(endpoint)
        try context.save()

        let endpointInfo = EndpointInfo(
            id: endpoint.id.uuidString,
            name: endpoint.name,
            url: endpoint.url,
            chainId: endpoint.chainId,
            autoDetect: endpoint.autoDetectChainId,
            nativeTokenSymbol: endpoint.nativeTokenSymbol,
            nativeTokenName: endpoint.nativeTokenName,
            nativeTokenDecimals: endpoint.nativeTokenDecimals
        )

        return EndpointManagerOutput(
            success: true,
            message: "Endpoint '\(name)' created successfully",
            endpoint: endpointInfo,
            endpoints: nil
        )
    }

    private static func updateEndpoint(context: ModelContext, id: String, data: EndpointData) async throws -> EndpointManagerOutput {
        guard let uuid = UUID(uuidString: id) else {
            throw SmartContractToolError.invalidId(id)
        }

        let descriptor = FetchDescriptor<Endpoint>(
            predicate: #Predicate { $0.id == uuid }
        )
        let endpoints = try context.fetch(descriptor)

        guard let endpoint = endpoints.first else {
            throw SmartContractToolError.notFound(entity: "Endpoint", id: id)
        }

        // Update fields if provided
        if let name = data.name {
            endpoint.name = name
        }
        if let url = data.url {
            guard URL(string: url) != nil else {
                throw SmartContractToolError.invalidEndpointUrl(url)
            }
            endpoint.url = url
        }
        if let chainId = data.chainId {
            endpoint.chainId = chainId
        }
        if let autoDetect = data.autoDetect {
            endpoint.autoDetectChainId = autoDetect
        }
        if let symbol = data.nativeTokenSymbol {
            endpoint.nativeTokenSymbol = symbol
        }
        if let name = data.nativeTokenName {
            endpoint.nativeTokenName = name
        }
        if let decimals = data.nativeTokenDecimals {
            endpoint.nativeTokenDecimals = decimals
        }

        endpoint.updatedAt = Date()
        try context.save()

        let endpointInfo = EndpointInfo(
            id: endpoint.id.uuidString,
            name: endpoint.name,
            url: endpoint.url,
            chainId: endpoint.chainId,
            autoDetect: endpoint.autoDetectChainId,
            nativeTokenSymbol: endpoint.nativeTokenSymbol,
            nativeTokenName: endpoint.nativeTokenName,
            nativeTokenDecimals: endpoint.nativeTokenDecimals
        )

        return EndpointManagerOutput(
            success: true,
            message: "Endpoint updated successfully",
            endpoint: endpointInfo,
            endpoints: nil
        )
    }

    private static func deleteEndpoint(context: ModelContext, id: String) async throws -> EndpointManagerOutput {
        guard let uuid = UUID(uuidString: id) else {
            throw SmartContractToolError.invalidId(id)
        }

        let descriptor = FetchDescriptor<Endpoint>(
            predicate: #Predicate { $0.id == uuid }
        )
        let endpoints = try context.fetch(descriptor)

        guard let endpoint = endpoints.first else {
            throw SmartContractToolError.notFound(entity: "Endpoint", id: id)
        }

        let name = endpoint.name
        context.delete(endpoint)
        try context.save()

        return EndpointManagerOutput(
            success: true,
            message: "Endpoint '\(name)' deleted successfully",
            endpoint: nil,
            endpoints: nil
        )
    }
}
