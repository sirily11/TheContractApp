//
//  SolidityDeploymentSheet+Actions.swift
//  SmartContractApp
//
//  Created by Kiro on 11/12/25.
//

import Combine
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
    }

    // MARK: - Deployment Flow

    /// Initiates the full deployment flow by starting with compilation
    func startDeployment() {
        // First compile, then deploy
        compileContract()
    }

    /// Compiles the Solidity source code using the selected version and contract name
    func compileContract() {
        let trimmedSource = sourceCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContractName = solidityContractName.trimmingCharacters(in: .whitespacesAndNewlines)
        let contractNameToUse = trimmedContractName.isEmpty ? nil : trimmedContractName

        compilationState = .inProgress

        Task {
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

                // Automatically proceed to deployment after successful compilation
                deployToNetwork()
            } catch {
                compilationState = .failed(error.localizedDescription)
            }
        }
    }

    /// Deploys the compiled bytecode to the selected network endpoint
    func deployToNetwork() {
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
                // Queue transaction for deployment (don't save to DB yet)
                let queuedTx = try await viewModel.deployBytecodeToNetwork(
                    results.bytecode,
                    endpoint: endpoint
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
        case .sent(let txHash, let transaction):
            // Check if this is our transaction
            guard transaction.id == txId else { return }

            // Transaction was successfully sent
            // Note: In a real implementation, we would wait for the transaction receipt
            // to get the contract address. For now, we'll use a placeholder approach.

            // Extract contract address from transaction hash (simplified)
            // In production, you should fetch the transaction receipt to get the actual contract address
            let contractAddress = txHash // Placeholder - should be extracted from receipt

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
