//
//  ToolErrors.swift
//  SmartContractApp
//
//  Created by Claude on 11/22/25.
//

import Foundation

// MARK: - Tool Errors

enum SmartContractToolError: LocalizedError {
    // CRUD Errors
    case notFound(entity: String, id: String)
    case invalidId(String)
    case missingRequiredField(String)
    case invalidAction(String)
    case duplicateName(String)

    // Endpoint Errors
    case invalidEndpointUrl(String)
    case endpointConnectionFailed(String)

    // ABI Errors
    case invalidAbiJson(String)
    case abiParsingFailed(String)

    // Contract Errors
    case invalidContractAddress(String)
    case contractNotDeployed(String)
    case noAbiAttached(String)

    // Compilation Errors
    case compilationFailed(String)
    case noContractInSource(String)

    // Deployment Errors
    case deploymentFailed(String)
    case invalidBytecode(String)
    case noWalletSelected
    case insufficientFunds

    // Call Errors
    case functionNotFound(String)
    case invalidParameters(String)
    case callFailed(String)
    case transactionFailed(String)

    // User Interaction Errors
    case userCancelled
    case timeout

    var errorDescription: String? {
        switch self {
        case .notFound(let entity, let id):
            return "\(entity) not found with ID: \(id)"
        case .invalidId(let id):
            return "Invalid ID format: \(id)"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .invalidAction(let action):
            return "Invalid action: \(action)"
        case .duplicateName(let name):
            return "An item with name '\(name)' already exists"

        case .invalidEndpointUrl(let url):
            return "Invalid endpoint URL: \(url)"
        case .endpointConnectionFailed(let message):
            return "Failed to connect to endpoint: \(message)"

        case .invalidAbiJson(let message):
            return "Invalid ABI JSON: \(message)"
        case .abiParsingFailed(let message):
            return "Failed to parse ABI: \(message)"

        case .invalidContractAddress(let address):
            return "Invalid contract address: \(address)"
        case .contractNotDeployed(let name):
            return "Contract '\(name)' is not deployed"
        case .noAbiAttached(let name):
            return "Contract '\(name)' has no ABI attached"

        case .compilationFailed(let message):
            return "Compilation failed: \(message)"
        case .noContractInSource(let message):
            return "No contract found in source: \(message)"

        case .deploymentFailed(let message):
            return "Deployment failed: \(message)"
        case .invalidBytecode(let message):
            return "Invalid bytecode: \(message)"
        case .noWalletSelected:
            return "No wallet selected for signing"
        case .insufficientFunds:
            return "Insufficient funds for transaction"

        case .functionNotFound(let name):
            return "Function '\(name)' not found in contract ABI"
        case .invalidParameters(let message):
            return "Invalid parameters: \(message)"
        case .callFailed(let message):
            return "Call failed: \(message)"
        case .transactionFailed(let message):
            return "Transaction failed: \(message)"

        case .userCancelled:
            return "Operation cancelled by user"
        case .timeout:
            return "Operation timed out"
        }
    }
}
