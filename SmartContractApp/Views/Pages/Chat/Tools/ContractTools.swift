//
//  ContractTools.swift
//  SmartContractApp
//
//  Created by Claude on 11/22/25.
//

@preconcurrency import Agent
import EvmCore
import Foundation
import JSONSchema
import SwiftData

// MARK: - Contract Manager Tool

enum ContractTools {
    static let name = "contract_manager"
    /// Creates the contract_manager tool for CRUD operations on contracts
    static func contractManagerTool(context: ModelContext) -> AgentTool<ContractManagerInput, ContractManagerOutput> {
        AgentTool(
            name: name,
            description: """
            Manage smart contracts. Actions: list (get all contracts), get (get contract by id), \
            create (create new contract), update (update contract), delete (delete contract).
            """,
            parameters: .object(
                description: "Contract manager parameters",
                properties: [
                    "action": .enum(
                        description: "The action to perform",
                        values: [.string("list"), .string("get"), .string("create"), .string("update"), .string("delete")]
                    ),
                    "id": .string(description: "Contract ID (required for get/update/delete)"),
                    "data": .object(
                        description: "Contract data (for create/update)",
                        properties: [
                            "name": .string(description: "Contract name"),
                            "address": .string(description: "Contract address"),
                            "abiId": .string(description: "ABI ID to attach"),
                            "endpointId": .string(description: "Endpoint ID"),
                            "sourceCode": .string(description: "Solidity source code"),
                            "solidityCompilerVersion": .string(description: "Solidity compiler version"),
                            "type": .enum(
                                description: "Contract type",
                                values: [.string("import"), .string("solidity")]
                            )
                        ],
                        required: []
                    )
                ],
                required: ["action"]
            ),
            execute: { input in
                switch input.action {
                case .list:
                    return try await listContracts(context: context)
                case .get:
                    guard let id = input.id else {
                        throw SmartContractToolError.missingRequiredField("id")
                    }
                    return try await getContract(context: context, id: id)
                case .create:
                    guard let data = input.data else {
                        throw SmartContractToolError.missingRequiredField("data")
                    }
                    return try await createContract(context: context, data: data)
                case .update:
                    guard let id = input.id else {
                        throw SmartContractToolError.missingRequiredField("id")
                    }
                    guard let data = input.data else {
                        throw SmartContractToolError.missingRequiredField("data")
                    }
                    return try await updateContract(context: context, id: id, data: data)
                case .delete:
                    guard let id = input.id else {
                        throw SmartContractToolError.missingRequiredField("id")
                    }
                    return try await deleteContract(context: context, id: id)
                }
            }
        )
    }

    // MARK: - Private Methods

    private static func listContracts(context: ModelContext) async throws -> ContractManagerOutput {
        let descriptor = FetchDescriptor<EVMContract>(
            sortBy: [SortDescriptor(\EVMContract.createdAt, order: .reverse)]
        )
        let contracts = try context.fetch(descriptor)

        let contractInfos = contracts.map { contract in
            ContractInfo(
                id: contract.id.uuidString,
                name: contract.name,
                address: contract.address,
                status: contract.status.rawValue,
                type: contract.type.rawValue,
                abiId: contract.abiId?.uuidString,
                endpointId: contract.endpointId.uuidString,
                endpointName: contract.endpoint?.name
            )
        }

        return ContractManagerOutput(
            success: true,
            message: "Found \(contracts.count) contract(s)",
            contract: nil,
            contracts: contractInfos
        )
    }

    private static func getContract(context: ModelContext, id: String) async throws -> ContractManagerOutput {
        guard let uuid = UUID(uuidString: id) else {
            throw SmartContractToolError.invalidId(id)
        }

        let descriptor = FetchDescriptor<EVMContract>(
            predicate: #Predicate { $0.id == uuid }
        )
        let contracts = try context.fetch(descriptor)

        guard let contract = contracts.first else {
            throw SmartContractToolError.notFound(entity: "Contract", id: id)
        }

        let contractInfo = ContractInfo(
            id: contract.id.uuidString,
            name: contract.name,
            address: contract.address,
            status: contract.status.rawValue,
            type: contract.type.rawValue,
            abiId: contract.abiId?.uuidString,
            endpointId: contract.endpointId.uuidString,
            endpointName: contract.endpoint?.name
        )

        return ContractManagerOutput(
            success: true,
            message: "Contract found",
            contract: contractInfo,
            contracts: nil
        )
    }

    private static func createContract(context: ModelContext, data: ContractData) async throws -> ContractManagerOutput {
        guard let name = data.name, !name.isEmpty else {
            throw SmartContractToolError.missingRequiredField("name")
        }
        guard let address = data.address, !address.isEmpty else {
            throw SmartContractToolError.missingRequiredField("address")
        }
        guard let endpointIdStr = data.endpointId else {
            throw SmartContractToolError.missingRequiredField("endpointId")
        }
        guard let endpointId = UUID(uuidString: endpointIdStr) else {
            throw SmartContractToolError.invalidId(endpointIdStr)
        }

        // Validate address format
        guard address.hasPrefix("0x") && address.count == 42 else {
            throw SmartContractToolError.invalidContractAddress(address)
        }

        // Verify endpoint exists
        let endpointDescriptor = FetchDescriptor<Endpoint>(
            predicate: #Predicate { $0.id == endpointId }
        )
        let endpoints = try context.fetch(endpointDescriptor)
        guard let endpoint = endpoints.first else {
            throw SmartContractToolError.notFound(entity: "Endpoint", id: endpointIdStr)
        }

        // Resolve ABI if provided
        var abi: EvmAbi?
        var abiId: UUID?
        if let abiIdStr = data.abiId {
            guard let uuid = UUID(uuidString: abiIdStr) else {
                throw SmartContractToolError.invalidId(abiIdStr)
            }
            let abiDescriptor = FetchDescriptor<EvmAbi>(
                predicate: #Predicate { $0.id == uuid }
            )
            let abis = try context.fetch(abiDescriptor)
            guard let foundAbi = abis.first else {
                throw SmartContractToolError.notFound(entity: "ABI", id: abiIdStr)
            }
            abi = foundAbi
            abiId = foundAbi.id
        }

        // Determine contract type
        let contractType: ContractType
        if let typeStr = data.type {
            guard let type = ContractType(rawValue: typeStr) else {
                throw SmartContractToolError.invalidAction("Invalid contract type: \(typeStr)")
            }
            contractType = type
        } else if data.sourceCode != nil {
            contractType = .solidity
        } else {
            contractType = .import
        }

        let contract = EVMContract(
            name: name,
            address: address,
            abiId: abiId,
            status: .deployed,
            type: contractType,
            contractCode: nil,
            sourceCode: data.sourceCode,
            endpointId: endpointId
        )

        contract.abi = abi
        contract.endpoint = endpoint

        context.insert(contract)
        try context.save()

        let contractInfo = ContractInfo(
            id: contract.id.uuidString,
            name: contract.name,
            address: contract.address,
            status: contract.status.rawValue,
            type: contract.type.rawValue,
            abiId: contract.abiId?.uuidString,
            endpointId: contract.endpointId.uuidString,
            endpointName: endpoint.name,
        )

        return ContractManagerOutput(
            success: true,
            message: "Contract '\(name)' created successfully",
            contract: contractInfo,
            contracts: nil
        )
    }

    private static func updateContract(context: ModelContext, id: String, data: ContractData) async throws -> ContractManagerOutput {
        guard let uuid = UUID(uuidString: id) else {
            throw SmartContractToolError.invalidId(id)
        }

        let descriptor = FetchDescriptor<EVMContract>(
            predicate: #Predicate { $0.id == uuid }
        )
        let contracts = try context.fetch(descriptor)

        guard let contract = contracts.first else {
            throw SmartContractToolError.notFound(entity: "Contract", id: id)
        }

        // Update fields if provided
        if let name = data.name {
            contract.name = name
        }
        if let address = data.address {
            guard address.hasPrefix("0x") && address.count == 42 else {
                throw SmartContractToolError.invalidContractAddress(address)
            }
            contract.address = address
        }
        if let abiIdStr = data.abiId {
            guard let abiUuid = UUID(uuidString: abiIdStr) else {
                throw SmartContractToolError.invalidId(abiIdStr)
            }
            let abiDescriptor = FetchDescriptor<EvmAbi>(
                predicate: #Predicate { $0.id == abiUuid }
            )
            let abis = try context.fetch(abiDescriptor)
            guard let foundAbi = abis.first else {
                throw SmartContractToolError.notFound(entity: "ABI", id: abiIdStr)
            }
            contract.abi = foundAbi
            contract.abiId = foundAbi.id
        }
        if let endpointIdStr = data.endpointId {
            guard let endpointUuid = UUID(uuidString: endpointIdStr) else {
                throw SmartContractToolError.invalidId(endpointIdStr)
            }
            let endpointDescriptor = FetchDescriptor<Endpoint>(
                predicate: #Predicate { $0.id == endpointUuid }
            )
            let endpoints = try context.fetch(endpointDescriptor)
            guard let endpoint = endpoints.first else {
                throw SmartContractToolError.notFound(entity: "Endpoint", id: endpointIdStr)
            }
            contract.endpoint = endpoint
            contract.endpointId = endpoint.id
        }
        if let sourceCode = data.sourceCode {
            contract.sourceCode = sourceCode
        }

        contract.updatedAt = Date()
        try context.save()

        let contractInfo = ContractInfo(
            id: contract.id.uuidString,
            name: contract.name,
            address: contract.address,
            status: contract.status.rawValue,
            type: contract.type.rawValue,
            abiId: contract.abiId?.uuidString,
            endpointId: contract.endpointId.uuidString,
            endpointName: contract.endpoint?.name
        )

        return ContractManagerOutput(
            success: true,
            message: "Contract updated successfully",
            contract: contractInfo,
            contracts: nil
        )
    }

    private static func deleteContract(context: ModelContext, id: String) async throws -> ContractManagerOutput {
        guard let uuid = UUID(uuidString: id) else {
            throw SmartContractToolError.invalidId(id)
        }

        let descriptor = FetchDescriptor<EVMContract>(
            predicate: #Predicate { $0.id == uuid }
        )
        let contracts = try context.fetch(descriptor)

        guard let contract = contracts.first else {
            throw SmartContractToolError.notFound(entity: "Contract", id: id)
        }

        let name = contract.name
        context.delete(contract)
        try context.save()

        return ContractManagerOutput(
            success: true,
            message: "Contract '\(name)' deleted successfully",
            contract: nil,
            contracts: nil
        )
    }
}
