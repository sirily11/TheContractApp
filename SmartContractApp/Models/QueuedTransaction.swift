//
//  QueuedTransaction.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import BigInt
import EvmCore
import Foundation

enum QueuedTransactionStatus: String, CaseIterable, Codable {
    case pending
    case approved
    case rejected
}

enum ContractFunctionName: Codable, Hashable {
    case function(name: String)
    case constructor

    func toString() -> String {
        switch self {
        case .function(name: let name):
            return name
        case .constructor:
            return "<constructor>"
        }
    }
}

struct QueuedTransaction: Identifiable, Codable, Hashable {
    let id: UUID
    let queuedAt: Date
    let to: String
    let value: TransactionValue
    let data: String? // hex string
    let gasEstimate: String?

    // Contract call details (optional)
    let contractFunctionName: ContractFunctionName?
    let contractParameters: [TransactionParameter]
    let bytecode: String?
    let abi: [AbiItem]?

    var status: QueuedTransactionStatus

    // Optional wallet ID reference (instead of SwiftData relationship)
    let walletId: UUID?

    init(
        id: UUID = UUID(),
        queuedAt: Date = Date(),
        to: String,
        value: TransactionValue,
        data: String? = nil,
        gasEstimate: String? = nil,
        contractFunctionName: ContractFunctionName? = nil,
        contractParameters: [TransactionParameter] = [],
        status: QueuedTransactionStatus = .pending,
        walletId: UUID? = nil,
        bytecode: String? = nil,
        abi: [AbiItem]? = nil
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
        self.walletId = walletId
        self.bytecode = bytecode
        self.abi = abi
    }

    // MARK: - Hashable Implementation

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(queuedAt)
        hasher.combine(to)
        hasher.combine(value.toWei().value.description) // Convert TransactionValue to String for hashing
        hasher.combine(data)
        hasher.combine(gasEstimate)
        hasher.combine(contractFunctionName)
        hasher.combine(contractParameters)
        hasher.combine(status)
        hasher.combine(walletId)
    }

    static func == (lhs: QueuedTransaction, rhs: QueuedTransaction) -> Bool {
        return lhs.id == rhs.id &&
            lhs.queuedAt == rhs.queuedAt &&
            lhs.to == rhs.to &&
            lhs.value.toWei().value == rhs.value.toWei().value &&
            lhs.data == rhs.data &&
            lhs.gasEstimate == rhs.gasEstimate &&
            lhs.contractFunctionName == rhs.contractFunctionName &&
            lhs.contractParameters == rhs.contractParameters &&
            lhs.status == rhs.status &&
            lhs.walletId == rhs.walletId
    }

    // MARK: - Helper Methods

    /// Returns true if this is a contract interaction
    var isContractCall: Bool {
        return contractFunctionName != nil
    }

    /// Returns a new transaction with approved status
    func approved() -> QueuedTransaction {
        var copy = self
        copy.status = .approved
        return copy
    }

    /// Returns a new transaction with rejected status
    func rejected() -> QueuedTransaction {
        var copy = self
        copy.status = .rejected
        return copy
    }
}

// MARK: - Sample Data for Previews

extension QueuedTransaction {
    /// Sample ETH transfer
    static var sampleETHTransfer: QueuedTransaction {
        QueuedTransaction(
            queuedAt: Date().addingTimeInterval(-120), // 2 minutes ago
            to: "0x1234567890abcdef1234567890abcdef12345678",
            value: .ether(.init(bigInt: .init(integerLiteral: 1))),
            gasEstimate: "21000",
            status: .pending
        )
    }

    /// Sample ERC20 transfer
    static var sampleERC20Transfer: QueuedTransaction {
        let params = TransactionParameter.sampleTransfer
        return QueuedTransaction(
            queuedAt: Date().addingTimeInterval(-300), // 5 minutes ago
            to: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", // USDC contract
            value: .ether(.init(bigInt: .zero)),
            data: "0xa9059cbb000000000000000000000000742d35cc6634c0532925a3b844bc9e7595f0beb0000000000000000000000000000000000000000000000000de0b6b3a7640000",
            gasEstimate: "65000",
            contractFunctionName: .function(name: "transfer"),
            contractParameters: params,
            status: .pending
        )
    }

    /// Sample approve transaction
    static var sampleApprove: QueuedTransaction {
        let params = TransactionParameter.sampleApprove

        return QueuedTransaction(
            queuedAt: Date().addingTimeInterval(-60), // 1 minute ago
            to: "0x6B175474E89094C44Da98b954EedeAC495271d0F", // DAI contract
            value: .ether(.init(bigInt: .zero)),
            data: "0x095ea7b30000000000000000000000001234567890abcdef1234567890abcdef123456780000000000000000000000000000000000000000000000004563918244f40000",
            gasEstimate: "46000",
            contractFunctionName: .function(name: "approve"),
            contractParameters: params,
            status: .pending
        )
    }

    /// Sample complex contract interaction (Uniswap swap)
    static var sampleSwap: QueuedTransaction {
        let params = TransactionParameter.sampleSwap

        return QueuedTransaction(
            queuedAt: Date().addingTimeInterval(-30), // 30 seconds ago
            to: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D", // Uniswap V2 Router
            value: .ether(.init(bigInt: .init(integerLiteral: 2))),
            data: "0x7ff36ab5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800000000000000000000000742d35cc6634c0532925a3b844bc9e7595f0beb0000000000000000000000000000000000000000000000000000000063ffffff",
            gasEstimate: "180000",
            contractFunctionName: .function(name: "swapExactETHForTokens"),
            contractParameters: params,
            status: .pending
        )
    }

    /// Sample high value transaction
    static var sampleHighValue: QueuedTransaction {
        QueuedTransaction(
            queuedAt: Date().addingTimeInterval(-600), // 10 minutes ago
            to: "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
            value: .ether(.init(bigInt: .init(integerLiteral: 10))),
            gasEstimate: "21000",
            status: .pending
        )
    }

    /// Sample approved transaction
    static var sampleApproved: QueuedTransaction {
        QueuedTransaction(
            queuedAt: Date().addingTimeInterval(-900), // 15 minutes ago
            to: "0x1111111111111111111111111111111111111111",
            value: .ether(.init(bigInt: .init(integerLiteral: 5))),
            gasEstimate: "21000",
            status: .approved
        )
    }

    /// Sample rejected transaction
    static var sampleRejected: QueuedTransaction {
        QueuedTransaction(
            queuedAt: Date().addingTimeInterval(-1200), // 20 minutes ago
            to: "0x2222222222222222222222222222222222222222",
            value: .ether(.init(bigInt: .init(integerLiteral: 3))),
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
