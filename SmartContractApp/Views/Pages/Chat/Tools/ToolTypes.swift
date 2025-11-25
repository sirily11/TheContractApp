//
//  ToolTypes.swift
//  SmartContractApp
//
//  Created by Claude on 11/22/25.
//

import Foundation

// MARK: - CRUD Action Enum

/// Common action enum for CRUD tools
enum CRUDAction: String, Codable, Sendable {
    case list
    case get
    case create
    case update
    case delete
}

// MARK: - Tool Result

/// Generic result wrapper for tool outputs
struct ToolResult<T: Codable & Sendable>: Codable, Sendable {
    let success: Bool
    let message: String
    let data: T?

    init(success: Bool, message: String, data: T? = nil) {
        self.success = success
        self.message = message
        self.data = data
    }

    static func success(_ message: String, data: T? = nil) -> ToolResult {
        ToolResult(success: true, message: message, data: data)
    }

    static func failure(_ message: String) -> ToolResult {
        ToolResult(success: false, message: message, data: nil)
    }
}

// MARK: - Endpoint Tool Types

struct EndpointManagerInput: Codable, Sendable {
    let action: CRUDAction
    let id: String?
    let data: EndpointData?

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        action = try container.decode(CRUDAction.self, forKey: .action)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        data = try container.decodeIfPresent(EndpointData.self, forKey: .data)
    }

    private enum CodingKeys: String, CodingKey {
        case action, id, data
    }
}

struct EndpointData: Codable, Sendable {
    let name: String?
    let url: String?
    let chainId: String?
    let autoDetect: Bool?
    let nativeTokenSymbol: String?
    let nativeTokenName: String?
    let nativeTokenDecimals: Int?

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        chainId = try container.decodeIfPresent(String.self, forKey: .chainId)
        autoDetect = try container.decodeIfPresent(Bool.self, forKey: .autoDetect)
        nativeTokenSymbol = try container.decodeIfPresent(String.self, forKey: .nativeTokenSymbol)
        nativeTokenName = try container.decodeIfPresent(String.self, forKey: .nativeTokenName)
        nativeTokenDecimals = try container.decodeIfPresent(Int.self, forKey: .nativeTokenDecimals)
    }

    private enum CodingKeys: String, CodingKey {
        case name, url, chainId, autoDetect, nativeTokenSymbol, nativeTokenName, nativeTokenDecimals
    }
}

struct EndpointInfo: Codable, Sendable {
    let id: String
    let name: String
    let url: String
    let chainId: String
    let autoDetect: Bool
    let nativeTokenSymbol: String
    let nativeTokenName: String
    let nativeTokenDecimals: Int
}

struct EndpointListOutput: Codable, Sendable {
    let endpoints: [EndpointInfo]
}

// MARK: - ABI Tool Types

struct ABIManagerInput: Codable, Sendable {
    let action: String // list, get, create, update, delete, parse
    let id: String?
    let data: ABIData?

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        action = try container.decode(String.self, forKey: .action)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        data = try container.decodeIfPresent(ABIData.self, forKey: .data)
    }

    private enum CodingKeys: String, CodingKey {
        case action, id, data
    }
}

struct ABIData: Codable, Sendable {
    let name: String?
    let content: String?
    let sourceUrl: String?
    let sourceFileName: String?

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        sourceUrl = try container.decodeIfPresent(String.self, forKey: .sourceUrl)
        sourceFileName = try container.decodeIfPresent(String.self, forKey: .sourceFileName)
    }

    private enum CodingKeys: String, CodingKey {
        case name, content, sourceUrl, sourceFileName
    }
}

struct ABIInfo: Codable, Sendable {
    let id: String
    let name: String
    let sourceUrl: String?
    let sourceFileName: String?
    let functionCount: Int
}

struct ABIListOutput: Codable, Sendable {
    let abis: [ABIInfo]
}

struct ABIFunctionInfo: Codable, Sendable {
    let name: String
    let type: String // function, event, constructor
    let stateMutability: String?
    let inputs: [ABIParameterInfo]
    let outputs: [ABIParameterInfo]
}

struct ABIParameterInfo: Codable, Sendable {
    let name: String
    let type: String
}

struct ABIParseOutput: Codable, Sendable {
    let functions: [ABIFunctionInfo]
}

// MARK: - Contract Tool Types

struct ContractManagerInput: Codable, Sendable {
    let action: CRUDAction
    let id: String?
    let data: ContractData?

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        action = try container.decode(CRUDAction.self, forKey: .action)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        data = try container.decodeIfPresent(ContractData.self, forKey: .data)
    }

    private enum CodingKeys: String, CodingKey {
        case action, id, data
    }
}

struct ContractData: Codable, Sendable {
    let name: String?
    let address: String?
    let abiId: String?
    let endpointId: String?
    let sourceCode: String?
    let bytecode: String?
    let type: String? // import, solidity, bytecode

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        abiId = try container.decodeIfPresent(String.self, forKey: .abiId)
        endpointId = try container.decodeIfPresent(String.self, forKey: .endpointId)
        sourceCode = try container.decodeIfPresent(String.self, forKey: .sourceCode)
        bytecode = try container.decodeIfPresent(String.self, forKey: .bytecode)
        type = try container.decodeIfPresent(String.self, forKey: .type)
    }

    private enum CodingKeys: String, CodingKey {
        case name, address, abiId, endpointId, sourceCode, bytecode, type
    }
}

struct ContractInfo: Codable, Sendable {
    let id: String
    let name: String
    let address: String
    let status: String
    let type: String
    let abiId: String?
    let endpointId: String
    let endpointName: String?
}

struct ContractListOutput: Codable, Sendable {
    let contracts: [ContractInfo]
}

// MARK: - Compile Tool Types

struct CompileInput: Codable, Sendable {
    let sourceCode: String
    let contractName: String?
    let version: String?

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sourceCode = try container.decode(String.self, forKey: .sourceCode)
        contractName = try container.decodeIfPresent(String.self, forKey: .contractName)
        version = try container.decodeIfPresent(String.self, forKey: .version)
    }

    private enum CodingKeys: String, CodingKey {
        case sourceCode, contractName, version
    }
}

struct CompileOutput: Codable, Sendable {
    let success: Bool
    let errors: [String]?
    let warnings: [String]?

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(success, forKey: .success)
        try container.encodeIfPresent(errors, forKey: .errors)
        try container.encodeIfPresent(warnings, forKey: .warnings)
    }

    private enum CodingKeys: String, CodingKey {
        case success, errors, warnings
    }
}

// MARK: - Deploy Tool Types

struct DeployInput: Codable, Sendable {
    let sourceCode: String?
    let constructorArgs: [String: String]?
    let endpointId: String?
    let name: String?
    let value: String?

    init(
        sourceCode: String? = nil,
        constructorArgs: [String: String]? = nil,
        endpointId: String? = nil,
        name: String? = nil,
        value: String? = nil
    ) {
        self.sourceCode = sourceCode
        self.constructorArgs = constructorArgs
        self.endpointId = endpointId
        self.name = name
        self.value = value
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sourceCode = try container.decodeIfPresent(String.self, forKey: .sourceCode)
        constructorArgs = try container.decodeIfPresent([String: String].self, forKey: .constructorArgs)
        endpointId = try container.decodeIfPresent(String.self, forKey: .endpointId)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        value = try container.decodeIfPresent(String.self, forKey: .value)
    }

    private enum CodingKeys: String, CodingKey {
        case sourceCode, constructorArgs, endpointId, name, value
    }
}

struct DeployOutput: Codable, Sendable {
    let success: Bool
    let contractAddress: String?
    let txHash: String?
    let message: String
    let pendingConfirmation: Bool

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(success, forKey: .success)
        try container.encodeIfPresent(contractAddress, forKey: .contractAddress)
        try container.encodeIfPresent(txHash, forKey: .txHash)
        try container.encode(message, forKey: .message)
        try container.encode(pendingConfirmation, forKey: .pendingConfirmation)
    }

    private enum CodingKeys: String, CodingKey {
        case success, contractAddress, txHash, message, pendingConfirmation
    }
}

// MARK: - Call Tool Types

struct CallReadInput: Codable, Sendable {
    let contractId: String
    let functionName: String
    let args: [String: String]?

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        contractId = try container.decode(String.self, forKey: .contractId)
        functionName = try container.decode(String.self, forKey: .functionName)
        args = try container.decodeIfPresent([String: String].self, forKey: .args)
    }

    private enum CodingKeys: String, CodingKey {
        case contractId, functionName, args
    }
}

struct CallReadOutput: Codable, Sendable {
    let success: Bool
    let result: String?
    let message: String

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(success, forKey: .success)
        try container.encodeIfPresent(result, forKey: .result)
        try container.encode(message, forKey: .message)
    }

    private enum CodingKeys: String, CodingKey {
        case success, result, message
    }
}

struct CallWriteInput: Codable, Sendable {
    let contractId: String
    let functionName: String
    let args: [String: String]?
    let value: String?

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        contractId = try container.decode(String.self, forKey: .contractId)
        functionName = try container.decode(String.self, forKey: .functionName)
        args = try container.decodeIfPresent([String: String].self, forKey: .args)
        value = try container.decodeIfPresent(String.self, forKey: .value)
    }

    private enum CodingKeys: String, CodingKey {
        case contractId, functionName, args, value
    }
}

struct CallWriteOutput: Codable, Sendable {
    let success: Bool
    let txHash: String?
    let message: String
    let pendingConfirmation: Bool

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(success, forKey: .success)
        try container.encodeIfPresent(txHash, forKey: .txHash)
        try container.encode(message, forKey: .message)
        try container.encode(pendingConfirmation, forKey: .pendingConfirmation)
    }

    private enum CodingKeys: String, CodingKey {
        case success, txHash, message, pendingConfirmation
    }
}

// MARK: - Pending Action Types

/// Represents an action that requires user confirmation
struct PendingAction: Codable, Sendable {
    let actionId: UUID
    let actionType: PendingActionType
    let message: String
}

enum PendingActionType: String, Codable, Sendable {
    case deploy
    case writeCall
    case createEndpoint
    case createAbi
    case createContract
    case deleteConfirmation
}

// MARK: - Contract Function Types

struct ContractFunctionListInput: Codable, Sendable {
    let contractId: String
}

struct ContractFunctionListOutput: Codable, Sendable {
    let functions: [ContractFunctionDetail]
}

struct ContractFunctionDetail: Codable, Sendable {
    let name: String
    let type: String
    let stateMutability: String
    let inputs: [FunctionParameterDetail]
    let outputs: [FunctionParameterDetail]
}

struct FunctionParameterDetail: Codable, Sendable {
    let name: String
    let type: String
}

// MARK: - Unified Manager Outputs

/// Unified output for endpoint manager operations
struct EndpointManagerOutput: Codable, Sendable {
    let success: Bool
    let message: String
    let endpoint: EndpointInfo?
    let endpoints: [EndpointInfo]?

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(success, forKey: .success)
        try container.encode(message, forKey: .message)
        try container.encodeIfPresent(endpoint, forKey: .endpoint)
        try container.encodeIfPresent(endpoints, forKey: .endpoints)
    }

    private enum CodingKeys: String, CodingKey {
        case success, message, endpoint, endpoints
    }
}

/// Unified output for ABI manager operations
struct ABIManagerOutput: Codable, Sendable {
    let success: Bool
    let message: String
    let abi: ABIInfo?
    let abis: [ABIInfo]?
    let functions: [ABIFunctionInfo]?

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(success, forKey: .success)
        try container.encode(message, forKey: .message)
        try container.encodeIfPresent(abi, forKey: .abi)
        try container.encodeIfPresent(abis, forKey: .abis)
        try container.encodeIfPresent(functions, forKey: .functions)
    }

    private enum CodingKeys: String, CodingKey {
        case success, message, abi, abis, functions
    }
}

/// Unified output for contract manager operations
struct ContractManagerOutput: Codable, Sendable {
    let success: Bool
    let message: String
    let contract: ContractInfo?
    let contracts: [ContractInfo]?

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(success, forKey: .success)
        try container.encode(message, forKey: .message)
        try container.encodeIfPresent(contract, forKey: .contract)
        try container.encodeIfPresent(contracts, forKey: .contracts)
    }

    private enum CodingKeys: String, CodingKey {
        case success, message, contract, contracts
    }
}
