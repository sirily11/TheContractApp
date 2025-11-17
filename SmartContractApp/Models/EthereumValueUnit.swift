//
//  EthereumValueUnit.swift
//  SmartContractApp
//
//  Created by Claude Code
//

import Foundation
import EvmCore
import BigInt

// MARK: - String Extension

private extension String {
    func padLeft(toLength: Int, withPad: String) -> String {
        let length = self.count
        if length >= toLength {
            return self
        }
        return String(repeating: withPad, count: toLength - length) + self
    }
}

/// Represents the unit of Ethereum value for user input
enum EthereumValueUnit: String, CaseIterable, Identifiable {
    case ether = "Ether"
    case gwei = "Gwei"
    case wei = "Wei"

    var id: String { rawValue }

    /// Converts a string input to TransactionValue based on the selected unit
    /// - Parameter input: String representation of the amount
    /// - Returns: TransactionValue enum case with the converted value
    /// - Throws: ConversionError if the input cannot be parsed
    func toTransactionValue(from input: String) throws -> TransactionValue {
        let trimmed = input.trimmingCharacters(in: .whitespaces)

        // Handle empty or zero input
        if trimmed.isEmpty || trimmed == "0" {
            return .ether(.init(bigInt: .zero))
        }

        switch self {
        case .ether:
            // Parse as decimal number
            if let floatValue = Double(trimmed) {
                return .ether(.init(float: floatValue))
            } else {
                throw ConversionError.invalidNumber
            }

        case .gwei:
            // Parse as decimal number for Gwei
            if let floatValue = Double(trimmed) {
                let gwei = Gwei(float: floatValue)
                return .ether(.init(gwei: gwei))
            } else {
                throw ConversionError.invalidNumber
            }

        case .wei:
            // Parse as integer for Wei (no decimals)
            if let bigIntValue = BigInt(trimmed) {
                let wei = Wei(bigInt: bigIntValue)
                return .ether(.init(wei: wei))
            } else {
                throw ConversionError.invalidNumber
            }
        }
    }

    /// Format a TransactionValue for display in this unit
    /// - Parameter value: The transaction value to format
    /// - Returns: Formatted string representation
    func format(_ value: TransactionValue) -> String {
        switch self {
        case .ether:
            let ethers = value.toEthers()
            // Convert wei to ether by dividing by 10^18, then format as decimal
            let weiPerEther = BigInt(10).power(18)
            let etherValue = ethers.toWei().value
            let wholePart = etherValue / weiPerEther
            let fractionalPart = etherValue % weiPerEther

            if fractionalPart == 0 {
                return "\(wholePart) \(rawValue)"
            } else {
                // Format with up to 18 decimal places, removing trailing zeros
                let fractionalStr = String(fractionalPart).padLeft(toLength: 18, withPad: "0")
                let trimmed = fractionalStr.trimmingCharacters(in: CharacterSet(charactersIn: "0"))
                return "\(wholePart).\(trimmed) \(rawValue)"
            }
        case .gwei:
            let gwei = value.toEthers().toGwei()
            return "\(gwei.value) \(rawValue)"
        case .wei:
            let wei = value.toWei()
            return "\(wei.value) \(rawValue)"
        }
    }

    enum ConversionError: LocalizedError {
        case invalidNumber

        var errorDescription: String? {
            switch self {
            case .invalidNumber:
                return "Invalid number format"
            }
        }
    }
}
