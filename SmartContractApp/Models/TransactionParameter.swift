//
//  TransactionParameter.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import Foundation

/// Represents a parameter for a smart contract function call
struct TransactionParameter: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var type: String
    var value: String

    init(name: String, type: String, value: String) {
        self.name = name
        self.type = type
        self.value = value
    }
}

// MARK: - Sample Data for Previews

extension TransactionParameter {
    static let sampleTransfer: [TransactionParameter] = [
        TransactionParameter(name: "to", type: "address", value: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"),
        TransactionParameter(name: "amount", type: "uint256", value: "1000000000000000000")
    ]

    static let sampleApprove: [TransactionParameter] = [
        TransactionParameter(name: "spender", type: "address", value: "0x1234567890abcdef1234567890abcdef12345678"),
        TransactionParameter(name: "amount", type: "uint256", value: "5000000000000000000")
    ]

    static let sampleSwap: [TransactionParameter] = [
        TransactionParameter(name: "tokenIn", type: "address", value: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"),
        TransactionParameter(name: "tokenOut", type: "address", value: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"),
        TransactionParameter(name: "amountIn", type: "uint256", value: "2000000000000000000"),
        TransactionParameter(name: "amountOutMin", type: "uint256", value: "3000000000"),
        TransactionParameter(name: "deadline", type: "uint256", value: "1699999999")
    ]
}
