//
//  QueuedTransaction.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import Foundation
import SwiftData

enum QueuedTransactionStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
}

@Model
final class QueuedTransaction {
    var id: UUID
    var queuedAt: Date
    var to: String
    var value: String  // in Wei as String
    var data: String?  // hex string
    var gasEstimate: String?

    // Contract call details (optional)
    var contractFunctionName: String?
    var contractParameters: Data?  // JSON encoded [TransactionParameter]

    var status: QueuedTransactionStatus

    // Relationships
    @Relationship var wallet: EVMWallet?

    init(
        id: UUID = UUID(),
        queuedAt: Date = Date(),
        to: String,
        value: String,
        data: String? = nil,
        gasEstimate: String? = nil,
        contractFunctionName: String? = nil,
        contractParameters: Data? = nil,
        status: QueuedTransactionStatus = .pending,
        wallet: EVMWallet? = nil
    ) {
        self.id = id
        self.queuedAt = queuedAt
        self.to = to
        self.value = value
        self.data = data
        self.gasEstimate = gasEstimate
        self.contractFunctionName = contractFunctionName
        self.contractParameters = contractParameters
        self.status = status
        self.wallet = wallet
    }

    // MARK: - Helper Methods

    /// Returns decoded contract parameters
    func getContractParameters() -> [TransactionParameter]? {
        guard let contractParameters = contractParameters else { return nil }
        return try? JSONDecoder().decode([TransactionParameter].self, from: contractParameters)
    }

    /// Sets contract parameters by encoding them to JSON
    func setContractParameters(_ parameters: [TransactionParameter]) throws {
        self.contractParameters = try JSONEncoder().encode(parameters)
    }

    /// Returns true if this is a contract interaction
    var isContractCall: Bool {
        return contractFunctionName != nil
    }

    /// Approve this transaction (mock implementation)
    func approve() {
        self.status = .approved
    }

    /// Reject this transaction (mock implementation)
    func reject() {
        self.status = .rejected
    }
}

// MARK: - Sample Data for Previews

extension QueuedTransaction {
    /// Sample ETH transfer
    static var sampleETHTransfer: QueuedTransaction {
        QueuedTransaction(
            queuedAt: Date().addingTimeInterval(-120),  // 2 minutes ago
            to: "0x1234567890abcdef1234567890abcdef12345678",
            value: "1500000000000000000",  // 1.5 ETH
            gasEstimate: "21000",
            status: .pending
        )
    }

    /// Sample ERC20 transfer
    static var sampleERC20Transfer: QueuedTransaction {
        let params = TransactionParameter.sampleTransfer
        let paramsData = try? JSONEncoder().encode(params)

        return QueuedTransaction(
            queuedAt: Date().addingTimeInterval(-300),  // 5 minutes ago
            to: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",  // USDC contract
            value: "0",
            data: "0xa9059cbb000000000000000000000000742d35cc6634c0532925a3b844bc9e7595f0beb0000000000000000000000000000000000000000000000000de0b6b3a7640000",
            gasEstimate: "65000",
            contractFunctionName: "transfer",
            contractParameters: paramsData,
            status: .pending
        )
    }

    /// Sample approve transaction
    static var sampleApprove: QueuedTransaction {
        let params = TransactionParameter.sampleApprove
        let paramsData = try? JSONEncoder().encode(params)

        return QueuedTransaction(
            queuedAt: Date().addingTimeInterval(-60),  // 1 minute ago
            to: "0x6B175474E89094C44Da98b954EedeAC495271d0F",  // DAI contract
            value: "0",
            data: "0x095ea7b30000000000000000000000001234567890abcdef1234567890abcdef123456780000000000000000000000000000000000000000000000004563918244f40000",
            gasEstimate: "46000",
            contractFunctionName: "approve",
            contractParameters: paramsData,
            status: .pending
        )
    }

    /// Sample complex contract interaction (Uniswap swap)
    static var sampleSwap: QueuedTransaction {
        let params = TransactionParameter.sampleSwap
        let paramsData = try? JSONEncoder().encode(params)

        return QueuedTransaction(
            queuedAt: Date().addingTimeInterval(-30),  // 30 seconds ago
            to: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",  // Uniswap V2 Router
            value: "2000000000000000000",  // 2 ETH
            data: "0x7ff36ab5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800000000000000000000000742d35cc6634c0532925a3b844bc9e7595f0beb0000000000000000000000000000000000000000000000000000000063ffffff",
            gasEstimate: "180000",
            contractFunctionName: "swapExactETHForTokens",
            contractParameters: paramsData,
            status: .pending
        )
    }

    /// Sample high value transaction
    static var sampleHighValue: QueuedTransaction {
        QueuedTransaction(
            queuedAt: Date().addingTimeInterval(-600),  // 10 minutes ago
            to: "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
            value: "10000000000000000000",  // 10 ETH
            gasEstimate: "21000",
            status: .pending
        )
    }

    /// Sample approved transaction
    static var sampleApproved: QueuedTransaction {
        QueuedTransaction(
            queuedAt: Date().addingTimeInterval(-900),  // 15 minutes ago
            to: "0x1111111111111111111111111111111111111111",
            value: "500000000000000000",  // 0.5 ETH
            gasEstimate: "21000",
            status: .approved
        )
    }

    /// Sample rejected transaction
    static var sampleRejected: QueuedTransaction {
        QueuedTransaction(
            queuedAt: Date().addingTimeInterval(-1200),  // 20 minutes ago
            to: "0x2222222222222222222222222222222222222222",
            value: "100000000000000000",  // 0.1 ETH
            gasEstimate: "21000",
            status: .rejected
        )
    }

    /// Array of all pending sample transactions
    static var allPending: [QueuedTransaction] {
        [sampleETHTransfer, sampleERC20Transfer, sampleApprove, sampleSwap, sampleHighValue]
    }

    /// Array of all sample transactions (including approved/rejected)
    static var allSamples: [QueuedTransaction] {
        [sampleETHTransfer, sampleERC20Transfer, sampleApprove, sampleSwap, sampleHighValue, sampleApproved, sampleRejected]
    }
}
