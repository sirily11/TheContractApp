//
//  CompileTools.swift
//  SmartContractApp
//
//  Created by Claude on 11/22/25.
//

@preconcurrency import Agent
import Foundation
import JSONSchema
import Solidity

// MARK: - Compile Tools

enum CompileTools {
    static let name = "compile_solidity"
    /// Creates the compile_solidity tool for compiling Solidity source code
    static func compileSolidityTool() -> AgentTool<CompileInput, CompileOutput> {
        AgentTool(
            name: CompileTools.name,
            description: """
            Compile Solidity source code to bytecode and ABI. \
            Returns the compiled bytecode and ABI JSON that can be used for deployment.
            """,
            parameters: .object(
                properties: [
                    "sourceCode": .string(description: "The Solidity source code to compile"),
                    "contractName": .string(description: "Name of the contract to extract (optional, uses first contract if not specified)"),
                    "version": .string(description: "Solidity compiler version (default: 0.8.21)")
                ],
                required: ["sourceCode"]
            ),
            execute: { input in
                try await compileSolidity(input: input)
            }
        )
    }

    // MARK: - Private Methods

    private static func compileSolidity(input: CompileInput) async throws -> CompileOutput {
        let sourceCode = input.sourceCode.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !sourceCode.isEmpty else {
            return CompileOutput(
                success: false,
                errors: ["Source code cannot be empty"],
                warnings: nil
            )
        }

        let version = input.version ?? "0.8.21"

        do {
            // Create compiler instance
            let compiler = try await Solc.create(version: version)
            defer {
                Task {
                    try? await compiler.close()
                }
            }

            // Prepare compilation input
            let compilerInput = Input(
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

            // Compile
            let output = try await compiler.compile(compilerInput, options: nil)

            // Extract errors and warnings
            var errors: [String] = []
            var warnings: [String] = []

            if let outputErrors = output.errors {
                for error in outputErrors {
                    let message = error.formattedMessage ?? error.message ?? "Unknown error"
                    if error.severity == "error" {
                        errors.append(message)
                    } else if error.severity == "warning" {
                        warnings.append(message)
                    }
                }
            }

            // If there are compilation errors, return them
            if !errors.isEmpty {
                return CompileOutput(
                    success: false,
                    errors: errors,
                    warnings: warnings.isEmpty ? nil : warnings
                )
            }

            // Extract bytecode and ABI
            guard let contracts = output.contracts,
                  let firstFile = contracts.first?.value
            else {
                return CompileOutput(
                    success: false,
                    errors: ["No contracts found in compilation output"],
                    warnings: warnings.isEmpty ? nil : warnings
                )
            }

            // Find the target contract
            let targetContract: Solidity.Contract
            if let contractName = input.contractName {
                guard let foundContract = firstFile[contractName] else {
                    let availableContracts = firstFile.keys.joined(separator: ", ")
                    return CompileOutput(
                        success: false,
                        errors: ["Contract '\(contractName)' not found. Available: \(availableContracts)"],
                        warnings: warnings.isEmpty ? nil : warnings
                    )
                }
                targetContract = foundContract
            } else {
                guard let firstContract = firstFile.first?.value else {
                    return CompileOutput(
                        success: false,
                        errors: ["No contracts found in compilation output"],
                        warnings: warnings.isEmpty ? nil : warnings
                    )
                }
                targetContract = firstContract
            }

            // Extract bytecode
            guard let bytecodeObj = targetContract.evm?.bytecode?.object,
                  !bytecodeObj.isEmpty
            else {
                return CompileOutput(
                    success: false,
                    errors: ["No bytecode generated"],
                    warnings: warnings.isEmpty ? nil : warnings
                )
            }

            let bytecode = bytecodeObj.hasPrefix("0x") ? bytecodeObj : "0x\(bytecodeObj)"

            // Extract ABI
            guard let abiArray = targetContract.abi else {
                return CompileOutput(
                    success: false,
                    errors: ["No ABI generated"],
                    warnings: warnings.isEmpty ? nil : warnings
                )
            }

            let abiData = try JSONEncoder().encode(abiArray)
            guard let abiString = String(data: abiData, encoding: .utf8) else {
                return CompileOutput(
                    success: false,
                    errors: ["Failed to encode ABI as JSON"],
                    warnings: warnings.isEmpty ? nil : warnings
                )
            }

            return CompileOutput(
                success: true,
                errors: nil,
                warnings: warnings.isEmpty ? nil : warnings
            )

        } catch {
            return CompileOutput(
                success: false,
                errors: [error.localizedDescription],
                warnings: nil
            )
        }
    }
}
