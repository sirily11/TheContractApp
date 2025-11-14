//
//  ContractDeploymentViewModel.swift
//  SmartContractApp
//
//  Created by Kiro on 11/12/25.
//

import EvmCore
import Foundation
import Observation
import Solidity
import SwiftData

// MARK: - Deployment Progress

enum DeploymentProgress: Equatable {
    case idle
    case compiling
    case preparingTransaction
    case signing
    case sending
    case confirming
    case completed(address: String)
    case failed(error: String)
}

// MARK: - Deployment Errors

enum DeploymentError: LocalizedError {
    case compilationFailed(String)
    case invalidBytecode(String)
    case invalidABI(String)
    case transactionFailed(String)
    case networkError(String)
    case gasEstimationFailed(String)
    case userRejected
    case noContractAddress
    case emptySourceCode
    case emptyBytecode
    case insufficientFunds
    case nonceTooLow
    
    var errorDescription: String? {
        switch self {
        case .compilationFailed(let message):
            return "Compilation failed: \(message)"
        case .invalidBytecode(let message):
            return "Invalid bytecode: \(message)"
        case .invalidABI(let message):
            return "Invalid ABI: \(message)"
        case .transactionFailed(let message):
            return "Transaction failed: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .gasEstimationFailed(let message):
            return "Gas estimation failed: \(message)"
        case .userRejected:
            return "Transaction was rejected by user"
        case .noContractAddress:
            return "Failed to extract contract address from transaction receipt"
        case .emptySourceCode:
            return "Source code cannot be empty"
        case .emptyBytecode:
            return "Bytecode cannot be empty"
        case .insufficientFunds:
            return "Insufficient funds to complete the transaction"
        case .nonceTooLow:
            return "Transaction nonce is too low. Please try again."
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .networkError, .gasEstimationFailed, .nonceTooLow:
            return true
        case .userRejected, .insufficientFunds:
            return false
        case .compilationFailed, .invalidBytecode, .invalidABI:
            return false
        case .transactionFailed, .noContractAddress:
            return true
        case .emptySourceCode, .emptyBytecode:
            return false
        }
    }
}

// MARK: - Contract Deployment View Model

@Observable
final class ContractDeploymentViewModel {
    // MARK: - State Properties
    
    var isCompiling: Bool = false
    var isDeploying: Bool = false
    var compilationError: String?
    var deploymentError: String?
    var deploymentProgress: DeploymentProgress = .idle
    
    // MARK: - Dependencies
    
    private let modelContext: ModelContext
    private let walletSigner: WalletSignerViewModel
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext, walletSigner: WalletSignerViewModel) {
        self.modelContext = modelContext
        self.walletSigner = walletSigner
    }
    
    // MARK: - Solidity Deployment
    
    /// Deploy a contract from Solidity source code
    /// - Parameters:
    ///   - sourceCode: The Solidity source code to compile
    ///   - name: The contract alias name
    ///   - endpoint: The RPC endpoint to deploy to
    /// - Returns: The created EVMContract with deployment details
    func deploySolidityContract(
        sourceCode: String,
        name: String,
        endpoint: Endpoint
    ) async throws {
        // Reset state
        compilationError = nil
        deploymentError = nil
        deploymentProgress = .idle
        
        // Validate source code
        guard !sourceCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DeploymentError.emptySourceCode
        }
        
        // Compile the source code
        isCompiling = true
        deploymentProgress = .compiling
        
        let compilationResult: (bytecode: String, abi: String)
        do {
            compilationResult = try await compileSolidity(sourceCode)
            isCompiling = false
        } catch {
            isCompiling = false
            compilationError = error.localizedDescription
            deploymentProgress = .failed(error: error.localizedDescription)
            throw error
        }
        
        // NOTE: Do NOT save contract to database here - it will be saved in the
        // event handler when deployment succeeds. This prevents duplicate contracts.

        // Deploy the bytecode
        isDeploying = true
        deploymentProgress = .preparingTransaction

        // Parse the ABI for constructor parameters
        let parser = try AbiParser(fromJsonString: compilationResult.abi)
        let abiItems = parser.items

        try await deployBytecodeToNetwork(
            compilationResult.bytecode,
            abi: abiItems,
            endpoint: endpoint,
            value: .ether(.init(bigInt: .zero))
        )
    }
    
    // MARK: - Bytecode Deployment
    
    /// Deploy a contract from pre-compiled bytecode
    /// - Parameters:
    ///   - bytecode: The compiled bytecode (hex string)
    ///   - name: The contract alias name
    ///   - endpoint: The RPC endpoint to deploy to
    ///   - abi: Optional ABI to associate with the contract
    /// - Returns: The created EVMContract with deployment details
    func deployBytecodeContract(
        bytecode: String,
        name: String,
        endpoint: Endpoint,
        abi: EvmAbi?
    ) async throws {
        // Reset state
        compilationError = nil
        deploymentError = nil
        deploymentProgress = .idle
        
        // Validate bytecode
        guard !bytecode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DeploymentError.emptyBytecode
        }
        
        try validateBytecode(bytecode)

        // NOTE: Do NOT save contract to database here - it will be saved in the
        // event handler when deployment succeeds. This prevents duplicate contracts.

        // Deploy the bytecode
        isDeploying = true
        deploymentProgress = .preparingTransaction

        // Parse the ABI if provided
        let abiItems: [AbiItem]
        if let abi = abi {
            let parser = try AbiParser(fromJsonString: abi.abiContent)
            abiItems = parser.items
        } else {
            abiItems = []
        }

        try await deployBytecodeToNetwork(
            bytecode,
            abi: abiItems,
            endpoint: endpoint,
            value: .ether(.init(bigInt: .zero))
        )
    }
    
    // MARK: - Public Validation Helpers
    
    /// Validate bytecode format
    /// - Parameter bytecode: The bytecode to validate
    /// - Throws: DeploymentError if bytecode is invalid
    static func validateBytecode(_ bytecode: String) throws {
        let trimmed = bytecode.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if empty
        guard !trimmed.isEmpty else {
            throw DeploymentError.emptyBytecode
        }
        
        // Check if it starts with 0x
        guard trimmed.hasPrefix("0x") else {
            throw DeploymentError.invalidBytecode("Bytecode must start with '0x'")
        }
        
        // Check if it contains only valid hex characters
        let hexString = String(trimmed.dropFirst(2))
        guard !hexString.isEmpty else {
            throw DeploymentError.invalidBytecode("Bytecode cannot be empty after '0x'")
        }
        
        let hexCharacterSet = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        guard hexString.unicodeScalars.allSatisfy({ hexCharacterSet.contains($0) }) else {
            throw DeploymentError.invalidBytecode("Bytecode contains invalid hex characters")
        }
    }
    
    /// Validate ABI JSON format
    /// - Parameter abiJson: The ABI JSON string to validate
    /// - Throws: DeploymentError if ABI is invalid
    static func validateAbi(_ abiJson: String) throws {
        let trimmed = abiJson.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if empty
        guard !trimmed.isEmpty else {
            throw DeploymentError.invalidABI("ABI cannot be empty")
        }
        
        // Try to parse as JSON
        guard let data = trimmed.data(using: .utf8) else {
            throw DeploymentError.invalidABI("Invalid JSON encoding")
        }
        
        // Validate it's a valid JSON array
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            guard jsonObject is [Any] else {
                throw DeploymentError.invalidABI("ABI must be a JSON array")
            }
        } catch {
            throw DeploymentError.invalidABI("Invalid JSON format: \(error.localizedDescription)")
        }
        
        // Try to parse with AbiParser to ensure it's a valid ABI
        do {
            _ = try AbiParser(fromJsonString: trimmed)
        } catch {
            throw DeploymentError.invalidABI("Failed to parse ABI: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Helpers
    
    /// Validate bytecode format (instance method)
    /// - Parameter bytecode: The bytecode to validate
    private func validateBytecode(_ bytecode: String) throws {
        try Self.validateBytecode(bytecode)
    }
    
    /// Compile Solidity source code
    /// - Parameters:
    ///   - source: The Solidity source code
    ///   - contractName: The name of the contract to extract from compilation output (optional, uses first contract if not specified)
    ///   - version: The Solidity compiler version to use (defaults to "0.8.21")
    /// - Returns: Tuple containing bytecode and ABI JSON
    func compileSolidity(_ source: String, contractName: String? = nil, version: String = "0.8.21") async throws -> (bytecode: String, abi: String) {
        // Create compiler instance with specified version
        let compiler = try await Solc.create(version: version)
        defer {
            Task {
                try? await compiler.close()
            }
        }
        
        // Prepare compilation input
        let input = Input(
            sources: [
                "Contract.sol": SourceIn(content: source)
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
        let output = try await compiler.compile(input, options: nil)
        
        // Check for compilation errors
        if let errors = output.errors {
            let errorMessages = errors
                .filter { $0.severity == "error" }
                .compactMap { $0.formattedMessage ?? $0.message }
            
            if !errorMessages.isEmpty {
                throw DeploymentError.compilationFailed(errorMessages.joined(separator: "\n"))
            }
        }
        
        // Extract bytecode and ABI from specified contract or first contract
        guard let contracts = output.contracts,
              let firstFile = contracts.first?.value
        else {
            throw DeploymentError.compilationFailed("No contracts found in compilation output")
        }

        // Find the target contract
        let targetContract: Solidity.Contract
        if let contractName = contractName {
            // Look for the specified contract by name
            guard let foundContract = firstFile[contractName] else {
                let availableContracts = firstFile.keys.joined(separator: ", ")
                throw DeploymentError.compilationFailed("Contract '\(contractName)' not found. Available contracts: \(availableContracts)")
            }
            targetContract = foundContract
        } else {
            // Use the first contract if no name specified
            guard let firstContract = firstFile.first?.value else {
                throw DeploymentError.compilationFailed("No contracts found in compilation output")
            }
            targetContract = firstContract
        }

        guard let bytecodeObj = targetContract.evm?.bytecode?.object,
              !bytecodeObj.isEmpty
        else {
            throw DeploymentError.compilationFailed("No bytecode generated")
        }

        // Ensure bytecode has 0x prefix
        let bytecode = bytecodeObj.hasPrefix("0x") ? bytecodeObj : "0x\(bytecodeObj)"

        // Convert ABI to JSON string
        guard let abiArray = targetContract.abi else {
            throw DeploymentError.compilationFailed("No ABI generated")
        }
        
        let abiData = try JSONEncoder().encode(abiArray)
        guard let abiString = String(data: abiData, encoding: .utf8) else {
            throw DeploymentError.compilationFailed("Failed to encode ABI as JSON")
        }
        
        return (bytecode: bytecode, abi: abiString)
    }
    
    /// Deploy bytecode to the network and extract contract address. Note this will only enqueue the transaction.
    /// - Parameters:
    ///   - bytecode: The bytecode to deploy
    ///   - endpoint: The RPC endpoint to deploy to
    /// - Returns: The deployed contract address
    func deployBytecodeToNetwork(
        _ bytecode: String,
        abi: [AbiItem],
        endpoint: Endpoint,
        value: TransactionValue,
        constructorParameters: [TransactionParameter] = [],
    ) async throws -> QueuedTransaction {
        // Update progress - Task 8.3: Display transaction progress
        deploymentProgress = .preparingTransaction
            
        // Task 8.1: Queue deployment transaction
        // Create transaction with bytecode as data
        // For contract deployment, 'to' is empty and value is 0
        let queuedTx = QueuedTransaction(
            to: "", // Empty for contract creation
            value: value,
            data: nil,
            gasEstimate: nil, // Will be estimated by wallet
            contractFunctionName: .constructor,
            contractParameters: constructorParameters,
            status: .pending,
            bytecode: bytecode,
            abi: abi
        )
        
        walletSigner.queueTransaction(tx: queuedTx)
        return queuedTx
    }
}
