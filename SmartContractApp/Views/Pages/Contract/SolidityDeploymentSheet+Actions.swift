//
//  SolidityDeploymentSheet+Actions.swift
//  SmartContractApp
//
//  Created by Kiro on 11/12/25.
//

import Combine
import EvmCore
import Solidity
import SwiftData
import SwiftUI

// MARK: - Actions

extension SolidityDeploymentSheet {
    // MARK: - Navigation Actions

    /// Validates the form and navigates to the compilation page
    func startCompilationFlow() {
        guard isReviewFormValid else {
            validationMessage = "Please fill in all required fields"
            showingValidationAlert = true
            return
        }

        navigationPath.append(DeploymentDestination.compilation)
    }

    /// Resets compilation and deployment states to idle
    func resetStates() {
        compilationState = .idle
        deploymentState = .idle
        compiledBytecode = nil
        compiledAbi = nil
        constructorParameters = []
    }

    /// Resets only compilation state
    func resetCompilationState() {
        compilationState = .idle
        compiledBytecode = nil
        compiledAbi = nil
        constructorParameters = []
    }

    /// Resets only deployment state
    func resetDeploymentState() {
        deploymentState = .idle
    }

    // MARK: - Deployment Flow

    /// Compiles the Solidity source code using the selected version and contract name
    func compileContract() async {
        // Check if we already have compilation output from the code editor
        if let editorOutput = editorCompilationOutput,
           let bytecode = extractBytecode(from: editorOutput),
           let abi = extractAbi(from: editorOutput) {
            // Reuse editor's compilation results
            compilationState = .success
            compiledBytecode = bytecode
            compiledAbi = abi
            compilationResults = (bytecode: bytecode, abi: abi)

            // Extract constructor parameters from ABI
            extractConstructorParameters(from: abi)

            // Automatically navigate to constructor params page
            navigationPath.append(DeploymentDestination.constructorParams)
            return
        }

        // If no editor results available, compile from scratch
        let trimmedSource = sourceCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContractName = solidityContractName.trimmingCharacters(in: .whitespacesAndNewlines)
        let contractNameToUse = trimmedContractName.isEmpty ? nil : trimmedContractName

        compilationState = .inProgress

        do {
            // Compile using the view model's internal compilation method with selected version and contract name
            let result = try await viewModel.compileSolidity(
                trimmedSource,
                contractName: contractNameToUse,
                version: selectedVersion
            )

            // Store compilation results temporarily (don't save to DB yet)
            compiledBytecode = result.bytecode
            compiledAbi = result.abi
            compilationResults = (bytecode: result.bytecode, abi: result.abi)
            compilationState = .success

            // Extract constructor parameters from ABI
            extractConstructorParameters(from: result.abi)

            // Automatically navigate to constructor params page
            navigationPath.append(DeploymentDestination.constructorParams)
        } catch {
            compilationState = .failed(error.localizedDescription)
        }
    }

    /// Extracts bytecode from the Solidity compilation output
    /// - Parameter output: The compilation output from the Solidity compiler
    /// - Returns: The bytecode as a hex string, or nil if not found
    private func extractBytecode(from output: Output) -> String? {
        guard let contracts = output.contracts?["Contract.sol"],
              let firstContract = contracts.values.first,
              let evm = firstContract.evm,
              let bytecode = evm.bytecode?.object else {
            return nil
        }

        // Ensure bytecode has 0x prefix
        return bytecode.hasPrefix("0x") ? bytecode : "0x\(bytecode)"
    }

    /// Extracts ABI from the Solidity compilation output
    /// - Parameter output: The compilation output from the Solidity compiler
    /// - Returns: The ABI as a JSON string, or nil if not found
    private func extractAbi(from output: Output) -> String? {
        guard let contracts = output.contracts?["Contract.sol"],
              let firstContract = contracts.values.first,
              let abi = firstContract.abi else {
            return nil
        }

        // Convert ABI array to JSON string
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(abi)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            print("Failed to encode ABI to JSON: \(error)")
            return nil
        }
    }

    /// Extracts constructor parameters from the compiled ABI
    /// - Parameter abiJson: The JSON string representation of the ABI
    func extractConstructorParameters(from abiJson: String) {
        do {
            let parser = try AbiParser(fromJsonString: abiJson)

            // Find the constructor in the ABI
            guard let constructor = parser.constructor,
                  let inputs = constructor.inputs, !inputs.isEmpty
            else {
                // No constructor or no parameters - leave array empty
                constructorParameters = []
                return
            }

            // Convert ABI parameters to TransactionParameter
            constructorParameters = inputs.map { input in
                TransactionParameter(
                    name: input.name.isEmpty ? "(unnamed)" : input.name,
                    type: (try? SolidityType(parsing: input.type)) ?? .string,
                    value: .init("")  // Empty default value
                )
            }
        } catch {
            // If we can't parse the ABI, just leave parameters empty
            print("Failed to extract constructor parameters: \(error)")
            constructorParameters = []
        }
    }

    /// Initiates deployment of the compiled contract with constructor parameters
    func startDeployment() {
        guard let endpoint = selectedEndpoint,
              let results = compilationResults
        else {
            validationMessage = "Missing compilation results"
            showingValidationAlert = true
            return
        }

        deploymentState = .inProgress

        Task {
            do {
                // Parse the ABI for constructor parameters
                let parser = try AbiParser(fromJsonString: results.abi)
                let abiItems = parser.items

                // Queue transaction for deployment with constructor parameters
                let queuedTx = try await viewModel.deployBytecodeToNetwork(
                    results.bytecode,
                    abi: abiItems,
                    endpoint: endpoint,
                    value: .ether(.init(bigInt: .zero)),
                    constructorParameters: constructorParameters  // Pass constructor params!
                )

                // Store the transaction ID to track it
                queuedTransactionId = queuedTx.id

                // Open signing wallet window for user to review and sign
                #if os(macOS)
                if !windowStateManager.isSigningWalletWindowOpen {
                    openWindow(id: "signing-wallet")
                }
                #endif

                // Update state to indicate waiting for signature
                deploymentState = .inProgress
            } catch {
                deploymentState = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - Transaction Event Handling

    /// Subscribe to transaction events from the wallet signer
    func subscribeToTransactionEvents() async {
        for await event in signerViewModel.transactionEventPublisher.values {
            await handleTransactionEvent(event)
        }
    }

    /// Handle transaction events from the wallet signer
    /// - Parameter event: The transaction event to handle
    @MainActor
    func handleTransactionEvent(_ event: TransactionEvent) async {
        // Only handle events for our queued transaction
        guard let txId = queuedTransactionId else { return }

        switch event {
        case .contractCreated(_, let contractAddress, let transaction):
            // Check if this is our transaction
            guard transaction.id == txId else { return }

            // Transaction was successfully sent
            // Note: In a real implementation, we would wait for the transaction receipt
            // to get the contract address. For now, we'll use a placeholder approach.

            // Now save to database with finalized state
            if let results = compilationResults,
               let endpoint = selectedEndpoint
            {
                let trimmedName = contractName.trimmingCharacters(in: .whitespacesAndNewlines)

                // Create ABI record
                let abiRecord = EvmAbi(name: "\(trimmedName) ABI", abiContent: results.abi)
                modelContext.insert(abiRecord)

                // Create contract record with deployed address
                let contract = EVMContract(
                    name: trimmedName,
                    address: contractAddress,
                    abiId: abiRecord.id,
                    status: .deployed,
                    type: .solidity,
                    endpointId: endpoint.id
                )
                contract.sourceCode = sourceCode
                contract.bytecode = results.bytecode
                contract.abi = abiRecord
                contract.endpoint = endpoint
                modelContext.insert(contract)

                // Save to database
                try? modelContext.save()

                // Update UI state
                deployedAddress = contractAddress
                deploymentState = .success
                queuedTransactionId = nil

                // Navigate to success page
                navigationPath.append(DeploymentDestination.success)

                // Notify callback if provided
                onDeploy?(contract)
            }

        case .rejected(let transaction):
            // Check if this is our transaction
            guard transaction.id == txId else { return }

            // User rejected the transaction
            deploymentState = .failed("Transaction rejected by user")
            queuedTransactionId = nil

        case .error(let error, let transaction):
            // Check if this is our transaction (if transaction is provided)
            if let transaction = transaction, transaction.id != txId {
                return
            }

            // Transaction failed
            deploymentState = .failed(error.localizedDescription)
            queuedTransactionId = nil

        default:
            // Ignore other events (queued, approved, cancelled)
            break
        }
    }
}
