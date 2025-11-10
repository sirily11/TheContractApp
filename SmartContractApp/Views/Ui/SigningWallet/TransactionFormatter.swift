//
//  TransactionFormatter.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import Foundation

/// Utility class for formatting transaction-related data
struct TransactionFormatter {

    // MARK: - Wei to ETH Conversion

    /// Converts Wei (as String) to ETH (as Decimal)
    /// - Parameter wei: Wei amount as string
    /// - Returns: ETH amount as Decimal, or nil if conversion fails
    static func weiToETH(_ wei: String) -> Decimal? {
        guard let weiDecimal = Decimal(string: wei) else { return nil }
        let divisor = Decimal(string: "1000000000000000000")!  // 10^18
        return weiDecimal / divisor
    }

    /// Formats Wei to ETH string with specified decimal places
    /// - Parameters:
    ///   - wei: Wei amount as string
    ///   - decimals: Number of decimal places (default: 4)
    /// - Returns: Formatted ETH string (e.g., "1.2345 ETH")
    static func formatWeiToETH(_ wei: String, decimals: Int = 4) -> String {
        guard let eth = weiToETH(wei) else { return "0 ETH" }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = decimals
        formatter.usesGroupingSeparator = true

        let ethValue = formatter.string(from: eth as NSDecimalNumber) ?? "0"
        return "\(ethValue) ETH"
    }

    // MARK: - Address Formatting

    /// Truncates an Ethereum address for display
    /// - Parameters:
    ///   - address: Full Ethereum address
    ///   - startChars: Number of characters to show at start (default: 6)
    ///   - endChars: Number of characters to show at end (default: 4)
    /// - Returns: Truncated address (e.g., "0x742d...0bEb")
    static func truncateAddress(_ address: String, startChars: Int = 6, endChars: Int = 4) -> String {
        guard address.count > startChars + endChars else { return address }

        let start = String(address.prefix(startChars))
        let end = String(address.suffix(endChars))
        return "\(start)...\(end)"
    }

    // MARK: - Hash Formatting

    /// Truncates a transaction hash for display
    /// - Parameter hash: Full transaction hash
    /// - Returns: Truncated hash (e.g., "0xabcd...7890")
    static func truncateHash(_ hash: String) -> String {
        return truncateAddress(hash, startChars: 6, endChars: 4)
    }

    // MARK: - Time Formatting

    /// Formats a date as relative time (e.g., "2 hours ago")
    /// - Parameter date: The date to format
    /// - Returns: Relative time string
    static func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Formats a date as short relative time (e.g., "2h ago")
    /// - Parameter date: The date to format
    /// - Returns: Short relative time string
    static func shortRelativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Function Signature Formatting

    /// Formats a function name with parameters into a signature
    /// - Parameters:
    ///   - functionName: The function name
    ///   - parameters: Array of transaction parameters
    /// - Returns: Formatted function signature (e.g., "transfer(address,uint256)")
    static func formatFunctionSignature(functionName: String, parameters: [TransactionParameter]) -> String {
        let paramTypes = parameters.map { $0.type }.joined(separator: ",")
        return "\(functionName)(\(paramTypes))"
    }

    /// Formats parameters for display
    /// - Parameter parameters: Array of transaction parameters
    /// - Returns: Array of formatted parameter strings
    static func formatParameters(_ parameters: [TransactionParameter]) -> [String] {
        return parameters.map { param in
            let value = param.type.lowercased().contains("address") ? truncateAddress(param.value) : param.value
            return "\(param.name): \(param.type) = \(value)"
        }
    }

    // MARK: - Gas Formatting

    /// Formats gas used with gas price to show total gas cost
    /// - Parameters:
    ///   - gasUsed: Amount of gas used
    ///   - gasPrice: Gas price in Wei
    /// - Returns: Formatted gas cost string
    static func formatGasCost(gasUsed: String, gasPrice: String) -> String {
        guard let used = Decimal(string: gasUsed),
              let price = Decimal(string: gasPrice) else {
            return "Unknown"
        }

        let totalWei = used * price
        let totalWeiString = String(describing: totalWei)
        return formatWeiToETH(totalWeiString, decimals: 6)
    }

    /// Formats gas price from Wei to Gwei
    /// - Parameter weiPrice: Gas price in Wei
    /// - Returns: Formatted Gwei string (e.g., "30 Gwei")
    static func formatGasPrice(_ weiPrice: String) -> String {
        guard let wei = Decimal(string: weiPrice) else { return "0 Gwei" }
        let gwei = wei / Decimal(string: "1000000000")!  // 10^9

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2

        let gweiValue = formatter.string(from: gwei as NSDecimalNumber) ?? "0"
        return "\(gweiValue) Gwei"
    }

    // MARK: - Data Formatting

    /// Truncates hex data for display
    /// - Parameters:
    ///   - data: Hex data string
    ///   - maxLength: Maximum length before truncating (default: 20)
    /// - Returns: Truncated data string
    static func truncateData(_ data: String, maxLength: Int = 20) -> String {
        if data.count <= maxLength {
            return data
        }
        let start = String(data.prefix(maxLength / 2))
        let end = String(data.suffix(maxLength / 2))
        return "\(start)...\(end)"
    }
}
