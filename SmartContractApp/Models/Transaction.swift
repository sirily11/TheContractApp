//
//  Transaction.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import Foundation
import SwiftData

enum TransactionType: String, CaseIterable, Codable {
    case send = "send"
    case receive = "receive"
    case contractCall = "contractCall"
}

enum TransactionStatus: String, CaseIterable, Codable {
    case success = "success"
    case pending = "pending"
    case failed = "failed"
}

@Model
final class Transaction {
    var id: UUID
    var hash: String
    var type: TransactionType
    var from: String
    var to: String
    var value: String  // in Wei as String to handle large numbers
    var timestamp: Date
    var status: TransactionStatus
    var blockNumber: Int?
    var gasUsed: String?
    var gasPrice: String?

    // Contract call details (optional)
    var contractFunctionName: String?
    var contractParameters: Data?  // JSON encoded [TransactionParameter]
    var contractAbiData: String?

    // Relationships
    @Relationship var wallet: EVMWallet?

    init(
        id: UUID = UUID(),
        hash: String,
        type: TransactionType,
        from: String,
        to: String,
        value: String,
        timestamp: Date = Date(),
        status: TransactionStatus = .pending,
        blockNumber: Int? = nil,
        gasUsed: String? = nil,
        gasPrice: String? = nil,
        contractFunctionName: String? = nil,
        contractParameters: Data? = nil,
        contractAbiData: String? = nil,
        wallet: EVMWallet? = nil
    ) {
        self.id = id
        self.hash = hash
        self.type = type
        self.from = from
        self.to = to
        self.value = value
        self.timestamp = timestamp
        self.status = status
        self.blockNumber = blockNumber
        self.gasUsed = gasUsed
        self.gasPrice = gasPrice
        self.contractFunctionName = contractFunctionName
        self.contractParameters = contractParameters
        self.contractAbiData = contractAbiData
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
        return type == .contractCall && contractFunctionName != nil
    }
}

// MARK: - Sample Data for Previews

extension Transaction {
    /// Sample ETH transfer (sent)
    static var sampleSent: Transaction {
        Transaction(
            hash: "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
            type: .send,
            from: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            to: "0x1234567890abcdef1234567890abcdef12345678",
            value: "1000000000000000000",  // 1 ETH
            timestamp: Date().addingTimeInterval(-3600),  // 1 hour ago
            status: .success,
            blockNumber: 18500000,
            gasUsed: "21000",
            gasPrice: "30000000000"
        )
    }

    /// Sample ETH transfer (received)
    static var sampleReceived: Transaction {
        Transaction(
            hash: "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
            type: .receive,
            from: "0x9876543210fedcba9876543210fedcba98765432",
            to: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            value: "2500000000000000000",  // 2.5 ETH
            timestamp: Date().addingTimeInterval(-7200),  // 2 hours ago
            status: .success,
            blockNumber: 18499500,
            gasUsed: "21000",
            gasPrice: "25000000000"
        )
    }

    /// Sample contract call (ERC20 transfer)
    static var sampleContractCall: Transaction {
        let params = TransactionParameter.sampleTransfer
        let paramsData = try? JSONEncoder().encode(params)

        return Transaction(
            hash: "0xfedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321",
            type: .contractCall,
            from: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            to: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",  // USDC contract
            value: "0",
            timestamp: Date().addingTimeInterval(-300),  // 5 minutes ago
            status: .success,
            blockNumber: 18501000,
            gasUsed: "65000",
            gasPrice: "35000000000",
            contractFunctionName: "transfer",
            contractParameters: paramsData,
            contractAbiData: "0xa9059cbb000000000000000000000000742d35cc6634c0532925a3b844bc9e7595f0beb0000000000000000000000000000000000000000000000000de0b6b3a7640000"
        )
    }

    /// Sample pending transaction
    static var samplePending: Transaction {
        Transaction(
            hash: "0x9999999999999999999999999999999999999999999999999999999999999999",
            type: .send,
            from: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            to: "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
            value: "500000000000000000",  // 0.5 ETH
            timestamp: Date().addingTimeInterval(-60),  // 1 minute ago
            status: .pending,
            gasPrice: "40000000000"
        )
    }

    /// Sample failed transaction
    static var sampleFailed: Transaction {
        Transaction(
            hash: "0x0000000000000000000000000000000000000000000000000000000000000000",
            type: .send,
            from: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            to: "0x1111111111111111111111111111111111111111",
            value: "100000000000000000",  // 0.1 ETH
            timestamp: Date().addingTimeInterval(-86400),  // 1 day ago
            status: .failed,
            blockNumber: 18495000,
            gasUsed: "21000",
            gasPrice: "20000000000"
        )
    }

    /// Sample complex contract interaction (Uniswap swap)
    static var sampleComplexContract: Transaction {
        let params = TransactionParameter.sampleSwap
        let paramsData = try? JSONEncoder().encode(params)

        return Transaction(
            hash: "0xaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd",
            type: .contractCall,
            from: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            to: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",  // Uniswap V2 Router
            value: "2000000000000000000",  // 2 ETH
            timestamp: Date().addingTimeInterval(-1800),  // 30 minutes ago
            status: .success,
            blockNumber: 18500500,
            gasUsed: "150000",
            gasPrice: "45000000000",
            contractFunctionName: "swapExactETHForTokens",
            contractParameters: paramsData,
            contractAbiData: "0x7ff36ab5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800000000000000000000000742d35cc6634c0532925a3b844bc9e7595f0beb0000000000000000000000000000000000000000000000000000000063ffffff"
        )
    }

    /// Array of all sample transactions
    static var allSamples: [Transaction] {
        [sampleSent, sampleReceived, sampleContractCall, samplePending, sampleFailed, sampleComplexContract]
    }
}
