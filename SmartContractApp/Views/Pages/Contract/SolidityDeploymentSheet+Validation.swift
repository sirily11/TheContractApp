//
//  SolidityDeploymentSheet+Validation.swift
//  SmartContractApp
//
//  Created by Kiro on 11/12/25.
//

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
