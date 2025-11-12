import Foundation

public struct PendingTransaction {
    public var txHash: String
    public let from: String
    public let to: String
    public let value: String
    public let gas: String
    public let gasPrice: String
    public let nonce: String
    public let data: String
    public let client: any EvmRpcClientProtocol

    public init(
        txHash: String, from: String, to: String, value: String, gas: String, gasPrice: String,
        nonce: String, data: String, client: any EvmRpcClientProtocol
    ) {
        self.txHash = txHash
        self.from = from
        self.to = to
        self.value = value
        self.gas = gas
        self.gasPrice = gasPrice
        self.nonce = nonce
        self.data = data
        self.client = client
    }

    /// Waits for the transaction to be mined and returns the receipt
    /// - Parameter timeout: Maximum time to wait in seconds (default: 60.0). Set to nil to wait indefinitely.
    /// - Returns: The transaction receipt
    /// - Throws: TransactionError.timeout if the timeout is reached before the transaction is mined
    public func wait(timeout: TimeInterval? = 60.0) async throws -> TransactionReceipt {
        let startTime = Date()
        let pollingInterval: TimeInterval = 1.0  // Poll every second

        while true {
            // Check if we've exceeded the timeout
            if let timeout = timeout, Date().timeIntervalSince(startTime) >= timeout {
                throw TransactionError.timeout(
                    "Transaction receipt not found after \(timeout) seconds")
            }

            // Try to get the receipt
            if let receipt = try await client.getTransactionReceipt(txHash) {
                return receipt
            }

            // Wait before polling again
            try await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
        }
    }
}
