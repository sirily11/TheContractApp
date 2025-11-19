//
//  FunctionListViewModel.swift
//  SmartContractApp
//
//  Created by Claude on 11/19/25.
//

import EvmCore
import Foundation
import Observation

/// View model for managing function list and auto-execution logic
@Observable
final class FunctionListViewModel {
    // MARK: - State Properties

    /// Set of function names currently being executed
    var executingFunctions: Set<String> = []

    /// Last error message
    var errorMessage: String?

    /// Whether to show error alert
    var showingErrorAlert = false

    // MARK: - Dependencies

    var interactionViewModel: ContractInteractionViewModel!

    // MARK: - Initialization

    init() {}

    // MARK: - Function Call Logic

    /// Determine whether to auto-execute or show sheet for a function
    /// - Parameter function: The AbiFunction to evaluate
    /// - Returns: True if function should auto-execute, false if sheet should be shown
    func shouldAutoExecute(_ function: AbiFunction) -> Bool {
        let isReadOnly = function.stateMutability == .view || function.stateMutability == .pure
        let hasNoParameters = function.inputs.isEmpty
        return isReadOnly && hasNoParameters
    }

    /// Execute a read function directly without showing the sheet
    /// - Parameters:
    ///   - contract: The contract to call
    ///   - function: The function to execute
    func executeReadFunction(contract: EVMContract, function: AbiFunction) async {
        // Mark function as executing
        executingFunctions.insert(function.name)

        do {
            // Call the function with empty parameters
            _ = try await interactionViewModel.executeReadFunction(
                contract: contract,
                functionName: function.name,
                parameters: []
            )

            // Mark function as no longer executing
            executingFunctions.remove(function.name)
        } catch {
            // Mark function as no longer executing and show error
            executingFunctions.remove(function.name)
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }

    /// Check if a function is currently executing
    /// - Parameter functionName: The function name
    /// - Returns: True if the function is executing
    func isExecuting(_ functionName: String) -> Bool {
        executingFunctions.contains(functionName)
    }

    /// Clear error state
    func clearError() {
        errorMessage = nil
        showingErrorAlert = false
    }
}
