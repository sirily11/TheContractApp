//
//  DeployTools.swift
//  SmartContractApp
//
//  Created by Claude on 11/22/25.
//

@preconcurrency import Agent
import Foundation
import JSONSchema
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
        // Basic validation - actual deployment is handled by ToolRegistry.handleDeploy
        // when user clicks "Sign & Deploy" in the UI

        // Validate source code is provided
        guard input.sourceCode != nil else {
            throw SmartContractToolError.missingRequiredField("sourceCode")
        }

        // Validate endpoint exists if provided
        if let endpointIdStr = input.endpointId {
            guard let endpointId = UUID(uuidString: endpointIdStr) else {
                throw SmartContractToolError.invalidId(endpointIdStr)
            }
            let descriptor = FetchDescriptor<Endpoint>(
                predicate: #Predicate { $0.id == endpointId }
            )
            let endpoints = try context.fetch(descriptor)
            guard endpoints.first != nil else {
                throw SmartContractToolError.notFound(entity: "Endpoint", id: endpointIdStr)
            }
        }

        // Return immediately with pending confirmation
        // The actual compilation and deployment is handled by ToolRegistry.handleDeploy
        // when user clicks "Sign & Deploy" button in DeployInputView
        return DeployOutput(
            success: true,
            contractAddress: nil,
            txHash: nil,
            message: "Transaction queued. Please approve in the UI.",
            pendingConfirmation: true,
            contractId: nil,
            abiId: nil
        )
    }
}
