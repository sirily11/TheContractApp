//
//  DeployTools.swift
//  SmartContractApp
//
//  Created by Claude on 11/22/25.
//

@preconcurrency import Agent
import BigInt
import Combine
import EvmCore
import Foundation
import JSONSchema
import Solidity
import SwiftData

// MARK: - Deploy Tools

enum DeployTools {
    static let name = "deploy_contract"
    /// Creates the deploy_contract tool for deploying smart contracts
    /// This tool returns immediately with pending confirmation, and the UI will handle user interaction
    static func deployContractTool(
        context: ModelContext,
        walletSigner: WalletSignerViewModel,
        registry: ToolRegistry
    ) -> AgentTool<DeployInput, DeployOutput> {
        AgentTool(
            name: DeployTools.name,
            description: """
            Deploy a smart contract to the blockchain. Provide either sourceCode (Solidity) or bytecode. \
            Returns pending confirmation - user must approve the transaction in the UI.
            """,
            parameters: .object(
                description: "Deploy contract parameters",
                properties: [
                    "sourceCode": .string(description: "Solidity source code to compile and deploy"),
                    "bytecode": .string(description: "Pre-compiled bytecode to deploy"),
                    "abi": .string(description: "Contract ABI JSON (required if using bytecode)"),
                    "constructorArgs": .object(
                        description: "Constructor arguments as key-value pairs",
                        properties: [:],
                        required: []
                    ),
                    "endpointId": .string(description: "Endpoint ID to deploy to"),
                    "name": .string(description: "Name for the deployed contract"),
                    "value": .string(description: "ETH value to send with deployment")
                ],
                required: []
            ),
            toolType: .ui,
            execute: { input in
                try await deployContract(
                    input: input,
                    context: context,
                    walletSigner: walletSigner,
                    registry: registry
                )
            }
        )
    }

    // MARK: - Private Methods

    private static func deployContract(
        input: DeployInput,
        context: ModelContext,
        walletSigner: WalletSignerViewModel,
        registry: ToolRegistry
    ) async throws -> DeployOutput {
        // Validate input
        guard let sourceCode = input.sourceCode else {
            throw SmartContractToolError.missingRequiredField("sourceCode")
        }

        // Get endpoint
        if let endpointIdStr = input.endpointId {
            guard let endpointId = UUID(uuidString: endpointIdStr) else {
                throw SmartContractToolError.invalidId(endpointIdStr)
            }
            let descriptor = FetchDescriptor<Endpoint>(
                predicate: #Predicate { $0.id == endpointId }
            )
            let endpoints = try context.fetch(descriptor)
            guard let _ = endpoints.first else {
                throw SmartContractToolError.notFound(entity: "Endpoint", id: endpointIdStr)
            }
        }

        // Compile source code
        let compileResult = try await compileSolidity(sourceCode: sourceCode)
        return DeployOutput(success: false, contractAddress: nil, txHash: nil, message: "", pendingConfirmation: false)
    }

    private static func compileSolidity(sourceCode: String) async throws -> CompileOutput {
        let compiler = try await Solc.create(version: "0.8.21")
        defer {
            Task {
                try? await compiler.close()
            }
        }

        let input = Input(
            sources: [
                "Contract.sol": SourceIn(content: sourceCode)
            ],
            settings: Settings(
                optimizer: Optimizer(enabled: true, runs: 200),
                outputSelection: [
                    "*": [
                        "*": ["abi", "evm.bytecode"]
                    ]
                ]
            )
        )

        let output = try await compiler.compile(input, options: nil)

        // Check for errors
        var errors: [String] = []
        if let outputErrors = output.errors {
            errors = outputErrors
                .filter { $0.severity == "error" }
                .compactMap { $0.formattedMessage ?? $0.message }
        }

        if !errors.isEmpty {
            return CompileOutput(
                success: false,
                errors: errors,
                warnings: nil
            )
        }

        // Extract bytecode and ABI
        guard let contracts = output.contracts,
              let firstFile = contracts.first?.value,
              let firstContract = firstFile.first?.value
        else {
            return CompileOutput(
                success: false,
                errors: ["No contracts found"],
                warnings: nil
            )
        }

        guard let bytecodeObj = firstContract.evm?.bytecode?.object else {
            return CompileOutput(
                success: false,
                errors: ["No bytecode generated"],
                warnings: nil
            )
        }

        let bytecode = bytecodeObj.hasPrefix("0x") ? bytecodeObj : "0x\(bytecodeObj)"

        guard let abiArray = firstContract.abi else {
            return CompileOutput(
                success: false,
                errors: ["No ABI generated"],
                warnings: nil
            )
        }

        let abiData = try JSONEncoder().encode(abiArray)
        let abiString = String(data: abiData, encoding: .utf8)

        return CompileOutput(
            success: true,
            errors: nil,
            warnings: nil
        )
    }
}

// MARK: - Pending Deployment

struct PendingDeployment: Sendable {
    let id: UUID
    let input: DeployInput
    let bytecode: String
    let abi: String
    let endpoint: Endpoint
    let queuedTransaction: QueuedTransaction
    let contractName: String
}
