//
//  SolidityDeploymentSheet+Validation.swift
//  SmartContractApp
//
//  Created by Kiro on 11/12/25.
//

import EvmCore
import Foundation

// MARK: - Validation

extension SolidityDeploymentSheet {

    // MARK: - Computed Properties

    /// Returns true if any compilation or deployment process is currently running
    var isProcessing: Bool {
        if case .inProgress = compilationState {
            return true
        }
        if case .inProgress = deploymentState {
            return true
        }
        return false
    }

    /// Validates that all required form fields are filled before proceeding to compilation
    var isReviewFormValid: Bool {
        !contractName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !sourceCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            selectedEndpoint != nil
    }

    /// Validates that all constructor parameters have values
    ///
    /// Returns `true` if:
    /// - There are no constructor parameters (empty array), OR
    /// - All constructor parameters have non-empty values
    ///
    /// For basic validation, we check if the string representation of the value is not empty.
    /// Individual input views provide more detailed type-specific validation with visual feedback.
    var isConstructorFormValid: Bool {
        // If no parameters, form is valid
        guard !constructorParameters.isEmpty else {
            return true
        }

        // Check that all parameters have values
        // For now, we'll do a basic check - each parameter should have a non-empty string value
        return constructorParameters.allSatisfy { param in
            // Get the string representation of the value
            if let stringValue = param.value.value as? String {
                return !stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            // For non-string types (bool, arrays, etc.), consider them valid if they have any value
            return true
        }
    }

    /// Returns the appropriate progress message based on current deployment state
    var deploymentProgressMessage: String {
        switch viewModel.deploymentProgress {
        case .idle:
            return "Preparing deployment..."
        case .compiling:
            return "Compiling contract..."
        case .preparingTransaction:
            return "Preparing transaction..."
        case .signing:
            return "Signing transaction..."
        case .sending:
            return "Sending transaction..."
        case .confirming:
            return "Confirming transaction..."
        case .completed:
            return "Deployment complete!"
        case .failed:
            return "Deployment failed"
        }
    }

    // MARK: - Helper Functions

    /// Extract all contract names from Solidity source code using regex
    /// - Parameter source: The Solidity source code to analyze
    /// - Returns: An array of contract names found in the source code
    func extractContractNames(from source: String) -> [String] {
        // Pattern matches: contract ContractName { or contract ContractName is BaseContract {
        // Captures the contract name in group 1
        let pattern = "contract\\s+(\\w+)\\s*(?:is\\s+[^{]*)?\\s*\\{"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        let nsString = source as NSString
        let results = regex.matches(in: source, options: [], range: NSRange(location: 0, length: nsString.length))

        var contractNames: [String] = []
        for match in results {
            if match.numberOfRanges > 1 {
                let range = match.range(at: 1)
                let contractName = nsString.substring(with: range)
                contractNames.append(contractName)
            }
        }

        return contractNames
    }
}
