//
//  ContractFunctionCall.swift
//  SmartContractApp
//
//  Created by Claude on 11/17/25.
//

import EvmCore
import Foundation
import SwiftData

enum CallStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case success = "success"
    case failed = "failed"
    case reverted = "reverted"
}

@Model
final class ContractFunctionCall {
    var id: UUID
    var functionName: String
    var parameters: Data // JSON encoded [TransactionParameter]
    var result: String? // ABI-decoded result (human-readable)
    var rawResult: String? // Raw hex result from contract
    var transactionHash: String? // Only for write functions
    var timestamp: Date
    var status: CallStatus
    var errorMessage: String? // Error message if failed
    var gasUsed: String? // Gas used for write functions
    var contractId: UUID

    // Relationships
    @Relationship var contract: EVMContract?

    init(
        id: UUID = UUID(),
        functionName: String,
        parameters: Data,
        result: String? = nil,
        rawResult: String? = nil,
        transactionHash: String? = nil,
        timestamp: Date = Date(),
        status: CallStatus = .pending,
        errorMessage: String? = nil,
        gasUsed: String? = nil,
        contractId: UUID,
        contract: EVMContract? = nil
    ) {
        self.id = id
        self.functionName = functionName
        self.parameters = parameters
        self.result = result
        self.rawResult = rawResult
        self.transactionHash = transactionHash
        self.timestamp = timestamp
        self.status = status
        self.errorMessage = errorMessage
        self.gasUsed = gasUsed
        self.contractId = contractId
        self.contract = contract
    }

    // MARK: - Helper Methods

    /// Returns decoded parameters
    func getParameters() -> [TransactionParameter]? {
        return try? JSONDecoder().decode([TransactionParameter].self, from: parameters)
    }

    /// Sets parameters by encoding them to JSON
    func setParameters(_ params: [TransactionParameter]) throws {
        parameters = try JSONEncoder().encode(params)
    }

    /// Returns true if this is a write function (has transaction hash)
    var isWriteFunction: Bool {
        return transactionHash != nil
    }

    /// Returns true if the call was successful
    var isSuccessful: Bool {
        return status == .success
    }

    /// Returns formatted parameters for display
    var formattedParameters: String {
        guard let params = getParameters() else { return "" }
        return params.map { "\($0.name): \(String(describing: $0.value.value))" }.joined(separator: ", ")
    }
}

// MARK: - Sample Data for Previews

extension ContractFunctionCall {
    /// Sample read function call (balanceOf)
    static var sampleReadCall: ContractFunctionCall {
        let params = [
            TransactionParameter(
                name: "account",
                type: .address,
                value: .init("0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")
            )
        ]
        let paramsData = try! JSONEncoder().encode(params)

        return ContractFunctionCall(
            functionName: "balanceOf",
            parameters: paramsData,
            result: "1000000000000000000", // 1 token
            rawResult: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000",
            timestamp: Date().addingTimeInterval(-3600), // 1 hour ago
            status: .success,
            contractId: UUID()
        )
    }

    /// Sample write function call (transfer)
    static var sampleWriteCall: ContractFunctionCall {
        let params = TransactionParameter.sampleTransfer
        let paramsData = try! JSONEncoder().encode(params)

        return ContractFunctionCall(
            functionName: "transfer",
            parameters: paramsData,
            result: "true",
            rawResult: "0x0000000000000000000000000000000000000000000000000000000000000001",
            transactionHash: "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
            timestamp: Date().addingTimeInterval(-600), // 10 minutes ago
            status: .success,
            gasUsed: "65000",
            contractId: UUID()
        )
    }

    /// Sample failed function call
    static var sampleFailedCall: ContractFunctionCall {
        let params = [
            TransactionParameter(
                name: "amount",
                type: .uint(256),
                value: .init("999999999999999999999")
            )
        ]
        let paramsData = try! JSONEncoder().encode(params)

        return ContractFunctionCall(
            functionName: "withdraw",
            parameters: paramsData,
            timestamp: Date().addingTimeInterval(-300), // 5 minutes ago
            status: .failed,
            errorMessage: "Insufficient balance",
            contractId: UUID()
        )
    }

    /// Sample reverted function call
    static var sampleRevertedCall: ContractFunctionCall {
        let params = [
            TransactionParameter(
                name: "spender",
                type: .address,
                value: .init("0x0000000000000000000000000000000000000000")
            ),
            TransactionParameter(
                name: "amount",
                type: .uint(256),
                value: .init("1000000000000000000")
            )
        ]
        let paramsData = try! JSONEncoder().encode(params)

        return ContractFunctionCall(
            functionName: "approve",
            parameters: paramsData,
            transactionHash: "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
            timestamp: Date().addingTimeInterval(-1800), // 30 minutes ago
            status: .reverted,
            errorMessage: "ERC20: approve to the zero address",
            contractId: UUID()
        )
    }

    /// Sample pending function call
    static var samplePendingCall: ContractFunctionCall {
        let params = [
            TransactionParameter(
                name: "newValue",
                type: .uint(256),
                value: .init("42")
            )
        ]
        let paramsData = try! JSONEncoder().encode(params)

        return ContractFunctionCall(
            functionName: "setValue",
            parameters: paramsData,
            transactionHash: "0x9999999999999999999999999999999999999999999999999999999999999999",
            timestamp: Date().addingTimeInterval(-60), // 1 minute ago
            status: .pending,
            contractId: UUID()
        )
    }

    /// Array of all sample function calls
    static var allSamples: [ContractFunctionCall] {
        [sampleReadCall, sampleWriteCall, sampleFailedCall, sampleRevertedCall, samplePendingCall]
    }
}
