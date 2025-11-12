//
//  EVMContract.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/6/25.
//

import Foundation
import SwiftData

enum DeploymentStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case deployed = "deployed"
    case failed = "failed"
}

enum ContractType: String, CaseIterable, Codable {
    case `import` = "import"
    case solidity = "solidity"
    case bytecode = "bytecode"
}

@Model
final class EVMContract {
    var id: Int
    var name: String
    var address: String
    var abiId: Int?
    var status: DeploymentStatus
    var type: ContractType
    var contractCode: String?
    var sourceCode: String?
    var bytecode: String?
    var createdAt: Date
    var updatedAt: Date
    var endpointId: Int
    
    // Relationships
    @Relationship var abi: EvmAbi?
    @Relationship var endpoint: Endpoint?
    
    init(id: Int = 0, name: String, address: String, abiId: Int? = nil, 
         status: DeploymentStatus = .pending, type: ContractType = .import,
         contractCode: String? = nil, sourceCode: String? = nil,
         bytecode: String? = nil, createdAt: Date = Date(), updatedAt: Date = Date(),
         endpointId: Int) {
        self.id = id
        self.name = name
        self.address = address
        self.abiId = abiId
        self.status = status
        self.type = type
        self.contractCode = contractCode
        self.sourceCode = sourceCode
        self.bytecode = bytecode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.endpointId = endpointId
    }
    
    /// Returns true if the contract is deployable
    func isDeployable() -> Bool {
        return status == .pending && bytecode != nil
    }
    
    /// Validates that contract code is available for compilation
    func compile() throws {
        guard contractCode != nil else {
            throw ContractError.contractCodeRequired
        }
        // Additional compilation logic would go here
    }
}

// Custom error types for contract operations
enum ContractError: Error, LocalizedError {
    case contractCodeRequired
    
    var errorDescription: String? {
        switch self {
        case .contractCodeRequired:
            return "Contract code is required"
        }
    }
}
