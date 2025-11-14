import Foundation
import BigInt

/// Helper utilities for sending transactions and waiting for receipts
public struct TransactionHelper {
    private let transport: Transport

    public init(transport: Transport) {
        self.transport = transport
    }

    /// Send a transaction using eth_sendTransaction
    /// - Parameters:
    ///   - from: The sender address
    ///   - to: The recipient address (nil for contract deployment)
    ///   - data: The transaction data (contract bytecode or function call data)
    ///   - value: The value to send
    ///   - gas: Optional gas limit
    ///   - gasPrice: Optional gas price (in gwei)
    /// - Returns: The transaction hash
    public func sendTransaction(
        from: Address,
        to: Address?,
        data: String,
        value: Wei = Wei(bigInt: 0),
        gas: GasLimit? = nil,
        gasPrice: Gwei? = nil
    ) async throws -> String {
        var params: [String: Any] = [
            "from": from.value,
            "data": data
        ]

        if let to = to {
            params["to"] = to.value
        }

        if value.value > 0 {
            params["value"] = "0x" + String(value.value, radix: 16)
        }

        if let gas = gas {
            params["gas"] = gas.toHex()
        }

        if let gasPrice = gasPrice {
            params["gasPrice"] = "0x" + String(gasPrice.toWei().value, radix: 16)
        }

        let request = RpcRequest(
            method: "eth_sendTransaction",
            params: [AnyCodable(params)]
        )

        let response = try await transport.send(request: request)

        guard let txHash = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected transaction hash string")
        }

        return txHash
    }

    /// Wait for a transaction receipt with polling
    /// - Parameters:
    ///   - txHash: The transaction hash
    ///   - pollingInterval: Time between polling attempts in seconds (default: 1.0)
    ///   - timeout: Maximum time to wait in seconds (default: 60.0)
    /// - Returns: The transaction receipt
    public func waitForReceipt(
        txHash: String,
        pollingInterval: TimeInterval = 1.0,
        timeout: TimeInterval = 60.0
    ) async throws -> TransactionReceipt {
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeout {
            let request = RpcRequest(
                method: "eth_getTransactionReceipt",
                params: [AnyCodable(txHash)]
            )

            let response = try await transport.send(request: request)

            // If result is not null, we have a receipt
            if !(response.result.value is NSNull) {
                guard let receiptDict = response.result.value as? [String: Any] else {
                    throw TransactionError.invalidResponse("Expected receipt dictionary")
                }

                return try TransactionReceipt(from: receiptDict)
            }

            // Wait before next poll
            try await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
        }

        throw TransactionError.timeout("Transaction receipt not found after \(timeout) seconds")
    }

    /// Get the transaction count (nonce) for an address
    /// - Parameters:
    ///   - address: The address to get the nonce for
    ///   - block: The block parameter (default: "latest")
    /// - Returns: The transaction count
    public func getTransactionCount(
        address: Address,
        block: String = "latest"
    ) async throws -> BigInt {
        let request = RpcRequest(
            method: "eth_getTransactionCount",
            params: [AnyCodable(address.value), AnyCodable(block)]
        )

        let response = try await transport.send(request: request)

        guard let countHex = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected transaction count hex string")
        }

        guard let count = BigInt(countHex.stripHexPrefix(), radix: 16) else {
            throw TransactionError.invalidResponse("Invalid transaction count format")
        }

        return count
    }

    /// Get the current gas price from the network
    /// - Returns: The gas price in wei
    public func getGasPrice() async throws -> BigInt {
        let request = RpcRequest(
            method: "eth_gasPrice",
            params: []
        )

        let response = try await transport.send(request: request)

        guard let priceHex = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected gas price hex string")
        }

        guard let price = BigInt(priceHex.stripHexPrefix(), radix: 16) else {
            throw TransactionError.invalidResponse("Invalid gas price format")
        }

        return price
    }

    /// Estimate gas for a transaction
    /// - Parameters:
    ///   - from: The sender address
    ///   - to: The recipient address (nil for contract deployment)
    ///   - data: The transaction data
    ///   - value: The value to send
    /// - Returns: Estimated gas limit
    public func estimateGas(
        from: Address,
        to: Address?,
        data: String,
        value: Wei = Wei(bigInt: 0)
    ) async throws -> GasLimit {
        var params: [String: Any] = [
            "from": from.value,
            "data": data
        ]

        if let to = to {
            params["to"] = to.value
        }

        if value.value > 0 {
            params["value"] = "0x" + String(value.value, radix: 16)
        }

        let request = RpcRequest(
            method: "eth_estimateGas",
            params: [AnyCodable(params)]
        )

        let response = try await transport.send(request: request)

        guard let gasHex = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected gas estimate hex string")
        }

        guard let gas = BigInt(gasHex.stripHexPrefix(), radix: 16) else {
            throw TransactionError.invalidResponse("Invalid gas estimate format")
        }

        return GasLimit(bigInt: gas)
    }
}

/// Represents a transaction receipt
public struct TransactionReceipt {
    public let transactionHash: String
    public let transactionIndex: String
    public let blockHash: String
    public let blockNumber: String
    public let from: String
    public let to: String?
    public let contractAddress: String?
    public let cumulativeGasUsed: String
    public let gasUsed: String
    public let status: String
    public let logs: [[String: Any]]

    public init(from dict: [String: Any]) throws {
        guard let transactionHash = dict["transactionHash"] as? String else {
            throw TransactionError.invalidResponse("Missing transactionHash")
        }
        guard let transactionIndex = dict["transactionIndex"] as? String else {
            throw TransactionError.invalidResponse("Missing transactionIndex")
        }
        guard let blockHash = dict["blockHash"] as? String else {
            throw TransactionError.invalidResponse("Missing blockHash")
        }
        guard let blockNumber = dict["blockNumber"] as? String else {
            throw TransactionError.invalidResponse("Missing blockNumber")
        }
        guard let from = dict["from"] as? String else {
            throw TransactionError.invalidResponse("Missing from")
        }
        guard let cumulativeGasUsed = dict["cumulativeGasUsed"] as? String else {
            throw TransactionError.invalidResponse("Missing cumulativeGasUsed")
        }
        guard let gasUsed = dict["gasUsed"] as? String else {
            throw TransactionError.invalidResponse("Missing gasUsed")
        }
        guard let status = dict["status"] as? String else {
            throw TransactionError.invalidResponse("Missing status")
        }

        self.transactionHash = transactionHash
        self.transactionIndex = transactionIndex
        self.blockHash = blockHash
        self.blockNumber = blockNumber
        self.from = from
        self.to = dict["to"] as? String
        self.contractAddress = dict["contractAddress"] as? String
        self.cumulativeGasUsed = cumulativeGasUsed
        self.gasUsed = gasUsed
        self.status = status
        self.logs = (dict["logs"] as? [[String: Any]]) ?? []
    }

    /// Check if the transaction was successful
    public var isSuccessful: Bool {
        return status == "0x1"
    }
}

/// Errors that can occur during transaction operations
public enum TransactionError: Error, LocalizedError {
    case invalidResponse(String)
    case timeout(String)
    case transactionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        case .timeout(let message):
            return "Timeout: \(message)"
        case .transactionFailed(let message):
            return "Transaction failed: \(message)"
        }
    }
}
