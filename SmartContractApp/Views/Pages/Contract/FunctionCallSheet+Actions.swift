//
//  FunctionCallSheet+Actions.swift
//  SmartContractApp
//
//  Created by Claude on 11/17/25.
//

import Combine
import EvmCore
import SwiftUI

// MARK: - Action Handlers

extension FunctionCallSheet {
    // MARK: - Main Actions

    /// Handle function call from parameters page
    func handleCallFunction() {
        if isReadFunction {
            // Read functions: Execute immediately
            executeReadFunction()
        } else {
            // Write functions: Go to confirmation page
            navigationPath.append(FunctionCallDestination.confirmation)
        }
    }

    /// Handle transaction confirmation (write functions only)
    func handleConfirmTransaction() {
        executeWriteFunction()
    }

    /// Handle retry after failed execution
    func handleRetry() {
        // Reset execution state
        executionState = .idle
        errorMessage = nil
        result = nil
        transactionHash = nil

        // Clear navigation path to return to parameters page
        navigationPath.removeLast(navigationPath.count)
        currentDestination = nil
    }

    // MARK: - Read Function Execution

    /// Execute a read function (view/pure)
    private func executeReadFunction() {
        executionState = .executing

        // Navigate to processing page
        navigationPath.append(FunctionCallDestination.processing)

        Task {
            do {
                let resultValue = try await interactionViewModel.executeReadFunction(
                    contract: contract,
                    functionName: function.name,
                    parameters: parameters
                )

                // Update state
                await MainActor.run {
                    result = resultValue
                    executionState = .completed
                    errorMessage = nil

                    // Navigate to result page
                    navigationPath.append(FunctionCallDestination.result)
                }
            } catch {
                // Handle error
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    executionState = .failed
                    result = nil

                    // Navigate to result page
                    navigationPath.append(FunctionCallDestination.result)
                }
            }
        }
    }

    // MARK: - Write Function Execution

    /// Execute a write function (nonpayable/payable)
    private func executeWriteFunction() {
        executionState = .waitingForSignature

        // Navigate to processing page
        navigationPath.append(FunctionCallDestination.processing)

        Task {
            do {
                // Queue the transaction
                let queuedTx = try await interactionViewModel.executeWriteFunction(
                    contract: contract,
                    functionName: function.name,
                    parameters: parameters,
                    value: transactionValue) {
                        openWindow(id: "signing-wallet")
                    }

                // Store queued transaction
                await MainActor.run {
                    queuedTransaction = queuedTx
                }

                // Subscribe to transaction events
                subscribeToTransactionEvents(queuedTx: queuedTx)
            } catch {
                // Handle error
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    executionState = .failed
                    result = nil

                    // Navigate to result page
                    navigationPath.append(FunctionCallDestination.result)
                }
            }
        }
    }

    // MARK: - Event Subscription

    /// Subscribe to wallet signer transaction events
    private func subscribeToTransactionEvents(queuedTx: QueuedTransaction) {
        interactionViewModel.subscribeToTransactionEvents(
            contract: contract,
            functionName: function.name,
            parameters: parameters,
            queuedTx: queuedTx
        )
        .receive(on: DispatchQueue.main)
        .sink { progress in
            handleProgressUpdate(progress)
        }
        .store(in: &cancellables)
    }

    /// Handle progress updates from transaction events
    private func handleProgressUpdate(_ progress: FunctionExecutionProgress) {
        switch progress {
        case .idle:
            break

        case .preparing:
            executionState = .executing

        case .executing:
            executionState = .executing

        case .waitingForSignature:
            executionState = .waitingForSignature

        case .sent(let txHash):
            // Transaction sent successfully
            transactionHash = txHash
            result = "Transaction sent successfully"
            executionState = .completed

            // Navigate to result page
            if currentDestination != .result {
                navigationPath.append(FunctionCallDestination.result)
            }

        case .completed(let resultValue):
            // Function executed successfully
            result = resultValue
            executionState = .completed

            // Navigate to result page
            if currentDestination != .result {
                navigationPath.append(FunctionCallDestination.result)
            }

        case .failed(let error):
            // Execution failed
            errorMessage = error
            executionState = .failed
            result = nil

            // Navigate to result page
            if currentDestination != .result {
                navigationPath.append(FunctionCallDestination.result)
            }
        }
    }
}
