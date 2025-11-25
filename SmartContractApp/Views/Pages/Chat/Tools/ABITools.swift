//
//  ABITools.swift
//  SmartContractApp
//
//  Created by Claude on 11/22/25.
//

@preconcurrency import Agent
import EvmCore
import Foundation
import JSONSchema
import SwiftData

// MARK: - ABI Manager Tool

enum ABITools {
    /// Creates the abi_manager tool for CRUD operations on ABIs
    static func abiManagerTool(context: ModelContext) -> AgentTool<ABIManagerInput, ABIManagerOutput> {
        AgentTool(
            name: "abi_manager",
            description: """
                Manage contract ABIs. Actions: list (get all ABIs), get (get ABI by id), \
                create (create new ABI), update (update ABI), delete (delete ABI), \
                parse (parse ABI and list functions).
                """,
            parameters: .object(
                description: "ABI manager parameters",
                properties: [
                    "action": .enum(
                        description: "The action to perform",
                        values: [.string("list"), .string("get"), .string("create"), .string("update"), .string("delete"), .string("parse")]
                    ),
                    "id": .string(description: "ABI ID (required for get/update/delete/parse)"),
                    "data": .object(
                        description: "ABI data (for create/update)",
                        properties: [
                            "name": .string(description: "ABI name"),
                            "content": .string(description: "ABI JSON content"),
                            "sourceUrl": .string(description: "Source URL"),
                            "sourceFileName": .string(description: "Source file name")
                        ],
                        required: []
                    )
                ],
                required: ["action"]
            ),
            execute: { input in
                switch input.action {
                case "list":
                    return try await listAbis(context: context)
                case "get":
                    guard let id = input.id else {
                        throw SmartContractToolError.missingRequiredField("id")
                    }
                    return try await getAbi(context: context, id: id)
                case "create":
                    guard let data = input.data else {
                        throw SmartContractToolError.missingRequiredField("data")
                    }
                    return try await createAbi(context: context, data: data)
                case "update":
                    guard let id = input.id else {
                        throw SmartContractToolError.missingRequiredField("id")
                    }
                    guard let data = input.data else {
                        throw SmartContractToolError.missingRequiredField("data")
                    }
                    return try await updateAbi(context: context, id: id, data: data)
                case "delete":
                    guard let id = input.id else {
                        throw SmartContractToolError.missingRequiredField("id")
                    }
                    return try await deleteAbi(context: context, id: id)
                case "parse":
                    guard let id = input.id else {
                        throw SmartContractToolError.missingRequiredField("id")
                    }
                    return try await parseAbi(context: context, id: id)
                default:
                    throw SmartContractToolError.invalidAction(input.action)
                }
            }
        )
    }

    // MARK: - Private Methods

    private static func listAbis(context: ModelContext) async throws -> ABIManagerOutput {
        let descriptor = FetchDescriptor<EvmAbi>(
            sortBy: [SortDescriptor(\EvmAbi.createdAt, order: .reverse)]
        )
        let abis = try context.fetch(descriptor)

        let abiInfos = abis.map { abi in
            let functionCount = countFunctions(in: abi.abiContent)
            return ABIInfo(
                id: abi.id.uuidString,
                name: abi.name,
                sourceUrl: abi.sourceUrl,
                sourceFileName: abi.sourceFileName,
                functionCount: functionCount
            )
        }

        return ABIManagerOutput(
            success: true,
            message: "Found \(abis.count) ABI(s)",
            abi: nil,
            abis: abiInfos,
            functions: nil
        )
    }

    private static func getAbi(context: ModelContext, id: String) async throws -> ABIManagerOutput {
        guard let uuid = UUID(uuidString: id) else {
            throw SmartContractToolError.invalidId(id)
        }

        let descriptor = FetchDescriptor<EvmAbi>(
            predicate: #Predicate { $0.id == uuid }
        )
        let abis = try context.fetch(descriptor)

        guard let abi = abis.first else {
            throw SmartContractToolError.notFound(entity: "ABI", id: id)
        }

        let functionCount = countFunctions(in: abi.abiContent)
        let abiInfo = ABIInfo(
            id: abi.id.uuidString,
            name: abi.name,
            sourceUrl: abi.sourceUrl,
            sourceFileName: abi.sourceFileName,
            functionCount: functionCount
        )

        return ABIManagerOutput(
            success: true,
            message: "ABI found",
            abi: abiInfo,
            abis: nil,
            functions: nil
        )
    }

    private static func createAbi(context: ModelContext, data: ABIData) async throws -> ABIManagerOutput {
        guard let name = data.name, !name.isEmpty else {
            throw SmartContractToolError.missingRequiredField("name")
        }
        guard let content = data.content, !content.isEmpty else {
            throw SmartContractToolError.missingRequiredField("content")
        }

        // Validate ABI JSON
        guard let jsonData = content.data(using: .utf8) else {
            throw SmartContractToolError.invalidAbiJson("Invalid encoding")
        }

        do {
            let jsonObject = try JSONSerialization.jsonObject(with: jsonData)
            guard jsonObject is [Any] else {
                throw SmartContractToolError.invalidAbiJson("ABI must be a JSON array")
            }
        } catch {
            throw SmartContractToolError.invalidAbiJson(error.localizedDescription)
        }

        // Try to parse with AbiParser
        do {
            _ = try AbiParser(fromJsonString: content)
        } catch {
            throw SmartContractToolError.abiParsingFailed(error.localizedDescription)
        }

        let abi = EvmAbi(
            name: name,
            abiContent: content,
            sourceUrl: data.sourceUrl,
            sourceFileName: data.sourceFileName
        )

        context.insert(abi)
        try context.save()

        let functionCount = countFunctions(in: abi.abiContent)
        let abiInfo = ABIInfo(
            id: abi.id.uuidString,
            name: abi.name,
            sourceUrl: abi.sourceUrl,
            sourceFileName: abi.sourceFileName,
            functionCount: functionCount
        )

        return ABIManagerOutput(
            success: true,
            message: "ABI '\(name)' created successfully with \(functionCount) function(s)",
            abi: abiInfo,
            abis: nil,
            functions: nil
        )
    }

    private static func updateAbi(context: ModelContext, id: String, data: ABIData) async throws -> ABIManagerOutput {
        guard let uuid = UUID(uuidString: id) else {
            throw SmartContractToolError.invalidId(id)
        }

        let descriptor = FetchDescriptor<EvmAbi>(
            predicate: #Predicate { $0.id == uuid }
        )
        let abis = try context.fetch(descriptor)

        guard let abi = abis.first else {
            throw SmartContractToolError.notFound(entity: "ABI", id: id)
        }

        // Update fields if provided
        if let name = data.name {
            abi.name = name
        }
        if let content = data.content {
            // Validate new content
            guard let jsonData = content.data(using: .utf8) else {
                throw SmartContractToolError.invalidAbiJson("Invalid encoding")
            }

            do {
                let jsonObject = try JSONSerialization.jsonObject(with: jsonData)
                guard jsonObject is [Any] else {
                    throw SmartContractToolError.invalidAbiJson("ABI must be a JSON array")
                }
                _ = try AbiParser(fromJsonString: content)
            } catch let error as SmartContractToolError {
                throw error
            } catch {
                throw SmartContractToolError.abiParsingFailed(error.localizedDescription)
            }

            abi.abiContent = content
        }
        if let sourceUrl = data.sourceUrl {
            abi.sourceUrl = sourceUrl
        }
        if let sourceFileName = data.sourceFileName {
            abi.sourceFileName = sourceFileName
        }

        abi.updatedAt = Date()
        try context.save()

        let functionCount = countFunctions(in: abi.abiContent)
        let abiInfo = ABIInfo(
            id: abi.id.uuidString,
            name: abi.name,
            sourceUrl: abi.sourceUrl,
            sourceFileName: abi.sourceFileName,
            functionCount: functionCount
        )

        return ABIManagerOutput(
            success: true,
            message: "ABI updated successfully",
            abi: abiInfo,
            abis: nil,
            functions: nil
        )
    }

    private static func deleteAbi(context: ModelContext, id: String) async throws -> ABIManagerOutput {
        guard let uuid = UUID(uuidString: id) else {
            throw SmartContractToolError.invalidId(id)
        }

        let descriptor = FetchDescriptor<EvmAbi>(
            predicate: #Predicate { $0.id == uuid }
        )
        let abis = try context.fetch(descriptor)

        guard let abi = abis.first else {
            throw SmartContractToolError.notFound(entity: "ABI", id: id)
        }

        let name = abi.name
        context.delete(abi)
        try context.save()

        return ABIManagerOutput(
            success: true,
            message: "ABI '\(name)' deleted successfully",
            abi: nil,
            abis: nil,
            functions: nil
        )
    }

    private static func parseAbi(context: ModelContext, id: String) async throws -> ABIManagerOutput {
        guard let uuid = UUID(uuidString: id) else {
            throw SmartContractToolError.invalidId(id)
        }

        let descriptor = FetchDescriptor<EvmAbi>(
            predicate: #Predicate { $0.id == uuid }
        )
        let abis = try context.fetch(descriptor)

        guard let abi = abis.first else {
            throw SmartContractToolError.notFound(entity: "ABI", id: id)
        }

        let parser = try AbiParser(fromJsonString: abi.abiContent)
        var functions: [ABIFunctionInfo] = []

        for item in parser.items {
            let inputs = item.inputs?.map { input in
                ABIParameterInfo(name: input.name ?? "", type: input.type)
            } ?? []

            let outputs = item.outputs?.map { output in
                ABIParameterInfo(name: output.name ?? "", type: output.type)
            } ?? []

            let functionInfo = ABIFunctionInfo(
                name: item.name ?? "",
                type: item.type.rawValue,
                stateMutability: item.stateMutability?.rawValue,
                inputs: inputs,
                outputs: outputs
            )
            functions.append(functionInfo)
        }

        return ABIManagerOutput(
            success: true,
            message: "Parsed \(functions.count) item(s) from ABI",
            abi: nil,
            abis: nil,
            functions: functions
        )
    }

    // MARK: - Helper Methods

    private static func countFunctions(in abiContent: String) -> Int {
        guard let parser = try? AbiParser(fromJsonString: abiContent) else {
            return 0
        }
        return parser.items.filter { $0.type == .function }.count
    }
}
