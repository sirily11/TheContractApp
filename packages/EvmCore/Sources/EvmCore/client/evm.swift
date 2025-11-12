import BigInt
import Foundation

public struct EvmClient: EvmRpcClientProtocol {

    public let transport: Transport

    public init(transport: Transport) {
        self.transport = transport
    }

    public func withSigner(signer: Signer) -> EvmClientWithSigner {
        return EvmClientWithSigner(transport: transport, signer: signer)
    }

    // MARK: - Blockchain Information

    public func blockNumber() async throws -> BigInt {
        let request = RpcRequest(method: "eth_blockNumber", params: [])
        let response = try await transport.send(request: request)

        guard let blockHex = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected block number hex string")
        }

        guard let block = BigInt(blockHex.stripHexPrefix(), radix: 16) else {
            throw TransactionError.invalidResponse("Invalid block number format")
        }

        return block
    }

    public func chainId() async throws -> BigInt {
        let request = RpcRequest(method: "eth_chainId", params: [])
        let response = try await transport.send(request: request)

        guard let chainIdHex = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected chain ID hex string")
        }

        guard let chainId = BigInt(chainIdHex.stripHexPrefix(), radix: 16) else {
            throw TransactionError.invalidResponse("Invalid chain ID format")
        }

        return chainId
    }

    public func gasPrice() async throws -> BigInt {
        let request = RpcRequest(method: "eth_gasPrice", params: [])
        let response = try await transport.send(request: request)

        guard let priceHex = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected gas price hex string")
        }

        guard let price = BigInt(priceHex.stripHexPrefix(), radix: 16) else {
            throw TransactionError.invalidResponse("Invalid gas price format")
        }

        return price
    }

    public func maxPriorityFeePerGas() async throws -> BigInt {
        let request = RpcRequest(method: "eth_maxPriorityFeePerGas", params: [])
        let response = try await transport.send(request: request)

        guard let feeHex = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected max priority fee hex string")
        }

        guard let fee = BigInt(feeHex.stripHexPrefix(), radix: 16) else {
            throw TransactionError.invalidResponse("Invalid max priority fee format")
        }

        return fee
    }

    /// Gets fee data similar to ethers.js getFeeData()
    /// Returns recommended fee values for both EIP-1559 and legacy transactions
    /// - Returns: FeeData containing recommended fee values
    public func getFeeData() async throws -> FeeData {
        // Fetch latest block to check for EIP-1559 support
        let block = try? await getBlockByNumber(.latest, fullTransactions: false)

        // Fetch gas price (may fail on some networks)
        let gasPrice = try? await self.gasPrice()

        var lastBaseFeePerGas: BigInt? = nil
        var maxFeePerGas: BigInt? = nil
        var maxPriorityFeePerGas: BigInt? = nil

        // Check if block has baseFeePerGas (EIP-1559 support)
        if let block = block, let baseFeeHex = block.baseFeePerGas {
            // Parse base fee
            if let baseFee = BigInt(baseFeeHex.stripHexPrefix(), radix: 16) {
                lastBaseFeePerGas = baseFee

                // Use 1.5 Gwei as default priority fee (same as ethers.js)
                maxPriorityFeePerGas = BigInt(1_500_000_000)

                // Calculate maxFeePerGas: (baseFee * 2) + maxPriorityFeePerGas
                // This matches ethers.js formula
                maxFeePerGas = (baseFee * 2) + maxPriorityFeePerGas!
            }
        }

        return FeeData(
            lastBaseFeePerGas: lastBaseFeePerGas,
            maxFeePerGas: maxFeePerGas,
            maxPriorityFeePerGas: maxPriorityFeePerGas,
            gasPrice: gasPrice
        )
    }

    // MARK: - Account Methods

    public func getBalance(address: Address, block: BlockParameter = .latest) async throws
        -> BigInt
    {
        let request = RpcRequest(
            method: "eth_getBalance",
            params: [AnyCodable(address.value), AnyCodable(block.stringValue)]
        )
        let response = try await transport.send(request: request)

        guard let balanceHex = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected balance hex string")
        }

        guard let balance = BigInt(balanceHex.stripHexPrefix(), radix: 16) else {
            throw TransactionError.invalidResponse("Invalid balance format")
        }

        return balance
    }

    public func getTransactionCount(address: Address, block: BlockParameter = .latest)
        async throws -> BigInt
    {
        let request = RpcRequest(
            method: "eth_getTransactionCount",
            params: [AnyCodable(address.value), AnyCodable(block.stringValue)]
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

    public func getCode(address: Address, block: BlockParameter = .latest) async throws -> String {
        let request = RpcRequest(
            method: "eth_getCode",
            params: [AnyCodable(address.value), AnyCodable(block.stringValue)]
        )
        let response = try await transport.send(request: request)

        guard let code = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected code hex string")
        }

        return code
    }

    public func getStorageAt(address: Address, position: BigInt, block: BlockParameter = .latest)
        async throws -> String
    {
        let positionHex = "0x" + String(position, radix: 16)
        let request = RpcRequest(
            method: "eth_getStorageAt",
            params: [
                AnyCodable(address.value), AnyCodable(positionHex), AnyCodable(block.stringValue),
            ]
        )
        let response = try await transport.send(request: request)

        guard let storage = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected storage hex string")
        }

        return storage
    }

    // MARK: - Block Methods

    public func getBlockByNumber(_ block: BlockParameter, fullTransactions: Bool = false)
        async throws -> Block?
    {
        let request = RpcRequest(
            method: "eth_getBlockByNumber",
            params: [AnyCodable(block.stringValue), AnyCodable(fullTransactions)]
        )
        let response = try await transport.send(request: request)

        if response.result.value is NSNull {
            return nil
        }

        guard let blockDict = response.result.value as? [String: Any] else {
            throw TransactionError.invalidResponse("Expected block dictionary")
        }

        let jsonData = try JSONSerialization.data(withJSONObject: blockDict)
        let decoder = JSONDecoder()
        return try decoder.decode(Block.self, from: jsonData)
    }

    public func getBlockByHash(_ hash: String, fullTransactions: Bool = false) async throws
        -> Block?
    {
        let request = RpcRequest(
            method: "eth_getBlockByHash",
            params: [AnyCodable(hash), AnyCodable(fullTransactions)]
        )
        let response = try await transport.send(request: request)

        if response.result.value is NSNull {
            return nil
        }

        guard let blockDict = response.result.value as? [String: Any] else {
            throw TransactionError.invalidResponse("Expected block dictionary")
        }

        let jsonData = try JSONSerialization.data(withJSONObject: blockDict)
        let decoder = JSONDecoder()
        return try decoder.decode(Block.self, from: jsonData)
    }

    public func getBlockTransactionCountByNumber(_ block: BlockParameter) async throws -> BigInt {
        let request = RpcRequest(
            method: "eth_getBlockTransactionCountByNumber",
            params: [AnyCodable(block.stringValue)]
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

    public func getBlockTransactionCountByHash(_ hash: String) async throws -> BigInt {
        let request = RpcRequest(
            method: "eth_getBlockTransactionCountByHash",
            params: [AnyCodable(hash)]
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

    // MARK: - Transaction Methods

    public func sendTransaction(params: TransactionParams) async throws -> String {
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

    public func getTransactionByHash(_ hash: String) async throws -> Transaction? {
        let request = RpcRequest(
            method: "eth_getTransactionByHash",
            params: [AnyCodable(hash)]
        )
        let response = try await transport.send(request: request)

        if response.result.value is NSNull {
            return nil
        }

        guard let txDict = response.result.value as? [String: Any] else {
            throw TransactionError.invalidResponse("Expected transaction dictionary")
        }

        let jsonData = try JSONSerialization.data(withJSONObject: txDict)
        let decoder = JSONDecoder()
        return try decoder.decode(Transaction.self, from: jsonData)
    }

    public func getTransactionByBlockNumberAndIndex(_ block: BlockParameter, index: BigInt)
        async throws -> Transaction?
    {
        let indexHex = "0x" + String(index, radix: 16)
        let request = RpcRequest(
            method: "eth_getTransactionByBlockNumberAndIndex",
            params: [AnyCodable(block.stringValue), AnyCodable(indexHex)]
        )
        let response = try await transport.send(request: request)

        if response.result.value is NSNull {
            return nil
        }

        guard let txDict = response.result.value as? [String: Any] else {
            throw TransactionError.invalidResponse("Expected transaction dictionary")
        }

        let jsonData = try JSONSerialization.data(withJSONObject: txDict)
        let decoder = JSONDecoder()
        return try decoder.decode(Transaction.self, from: jsonData)
    }

    public func getTransactionReceipt(_ hash: String) async throws -> TransactionReceipt? {
        let request = RpcRequest(
            method: "eth_getTransactionReceipt",
            params: [AnyCodable(hash)]
        )
        let response = try await transport.send(request: request)

        if response.result.value is NSNull {
            return nil
        }

        guard let receiptDict = response.result.value as? [String: Any] else {
            throw TransactionError.invalidResponse("Expected receipt dictionary")
        }

        return try TransactionReceipt(from: receiptDict)
    }

    // MARK: - Call Methods

    public func call(params: CallParams, block: BlockParameter = .latest) async throws -> String {
        let request = RpcRequest(
            method: "eth_call",
            params: [AnyCodable(params), AnyCodable(block.stringValue)]
        )
        let response = try await transport.send(request: request)

        guard let result = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected call result hex string")
        }

        return result
    }

    public func estimateGas(params: TransactionParams) async throws -> BigInt {
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

        return gas
    }

    // MARK: - Filter Methods

    public func newFilter(params: FilterParams) async throws -> String {
        let request = RpcRequest(
            method: "eth_newFilter",
            params: [AnyCodable(params)]
        )
        let response = try await transport.send(request: request)

        guard let filterId = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected filter ID string")
        }

        return filterId
    }

    public func newBlockFilter() async throws -> String {
        let request = RpcRequest(method: "eth_newBlockFilter", params: [])
        let response = try await transport.send(request: request)

        guard let filterId = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected filter ID string")
        }

        return filterId
    }

    public func newPendingTransactionFilter() async throws -> String {
        let request = RpcRequest(method: "eth_newPendingTransactionFilter", params: [])
        let response = try await transport.send(request: request)

        guard let filterId = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected filter ID string")
        }

        return filterId
    }

    public func getFilterChanges(_ filterId: String) async throws -> [Log] {
        let request = RpcRequest(
            method: "eth_getFilterChanges",
            params: [AnyCodable(filterId)]
        )
        let response = try await transport.send(request: request)

        guard let logsArray = response.result.value as? [[String: Any]] else {
            throw TransactionError.invalidResponse("Expected logs array")
        }

        let jsonData = try JSONSerialization.data(withJSONObject: logsArray)
        let decoder = JSONDecoder()
        return try decoder.decode([Log].self, from: jsonData)
    }

    public func getFilterLogs(_ filterId: String) async throws -> [Log] {
        let request = RpcRequest(
            method: "eth_getFilterLogs",
            params: [AnyCodable(filterId)]
        )
        let response = try await transport.send(request: request)

        guard let logsArray = response.result.value as? [[String: Any]] else {
            throw TransactionError.invalidResponse("Expected logs array")
        }

        let jsonData = try JSONSerialization.data(withJSONObject: logsArray)
        let decoder = JSONDecoder()
        return try decoder.decode([Log].self, from: jsonData)
    }

    public func getLogs(params: FilterParams) async throws -> [Log] {
        let request = RpcRequest(
            method: "eth_getLogs",
            params: [AnyCodable(params)]
        )
        let response = try await transport.send(request: request)

        guard let logsArray = response.result.value as? [[String: Any]] else {
            throw TransactionError.invalidResponse("Expected logs array")
        }

        let jsonData = try JSONSerialization.data(withJSONObject: logsArray)
        let decoder = JSONDecoder()
        return try decoder.decode([Log].self, from: jsonData)
    }

    public func uninstallFilter(_ filterId: String) async throws -> Bool {
        let request = RpcRequest(
            method: "eth_uninstallFilter",
            params: [AnyCodable(filterId)]
        )
        let response = try await transport.send(request: request)

        guard let success = response.result.value as? Bool else {
            throw TransactionError.invalidResponse("Expected boolean result")
        }

        return success
    }

    // MARK: - Network Methods

    public func netVersion() async throws -> String {
        let request = RpcRequest(method: "net_version", params: [])
        let response = try await transport.send(request: request)

        guard let version = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected version string")
        }

        return version
    }

    public func netListening() async throws -> Bool {
        let request = RpcRequest(method: "net_listening", params: [])
        let response = try await transport.send(request: request)

        guard let listening = response.result.value as? Bool else {
            throw TransactionError.invalidResponse("Expected boolean result")
        }

        return listening
    }

    public func netPeerCount() async throws -> BigInt {
        let request = RpcRequest(method: "net_peerCount", params: [])
        let response = try await transport.send(request: request)

        guard let countHex = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected peer count hex string")
        }

        guard let count = BigInt(countHex.stripHexPrefix(), radix: 16) else {
            throw TransactionError.invalidResponse("Invalid peer count format")
        }

        return count
    }

    // MARK: - Web3 Methods

    public func web3ClientVersion() async throws -> String {
        let request = RpcRequest(method: "web3_clientVersion", params: [])
        let response = try await transport.send(request: request)

        guard let version = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected client version string")
        }

        return version
    }

    public func web3Sha3(_ data: String) async throws -> String {
        let request = RpcRequest(
            method: "web3_sha3",
            params: [AnyCodable(data)]
        )
        let response = try await transport.send(request: request)

        guard let hash = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected hash string")
        }

        return hash
    }
}

public struct EvmClientWithSigner: EvmRpcClientProtocol {
    public let transport: Transport
    public let signer: Signer

    public init(transport: Transport, signer: Signer) {
        self.transport = transport
        self.signer = signer
    }

    /// The address from the signer
    public var address: Address {
        return signer.address
    }

    /// Sign a message using the wrapped signer
    public func sign(message: Data) async throws -> Data {
        return try await signer.sign(message: message)
    }

    /// Verify a signature using the wrapped signer
    public func verify(address: Address, message: Data, signature: Data) async throws -> Bool {
        return try await signer.verify(address: address, message: message, signature: signature)
    }

    // MARK: - Blockchain Information

    public func blockNumber() async throws -> BigInt {
        let request = RpcRequest(method: "eth_blockNumber", params: [])
        let response = try await transport.send(request: request)

        guard let blockHex = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected block number hex string")
        }

        guard let block = BigInt(blockHex.stripHexPrefix(), radix: 16) else {
            throw TransactionError.invalidResponse("Invalid block number format")
        }

        return block
    }

    public func chainId() async throws -> BigInt {
        let request = RpcRequest(method: "eth_chainId", params: [])
        let response = try await transport.send(request: request)

        guard let chainIdHex = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected chain ID hex string")
        }

        guard let chainId = BigInt(chainIdHex.stripHexPrefix(), radix: 16) else {
            throw TransactionError.invalidResponse("Invalid chain ID format")
        }

        return chainId
    }

    public func gasPrice() async throws -> BigInt {
        let request = RpcRequest(method: "eth_gasPrice", params: [])
        let response = try await transport.send(request: request)

        guard let priceHex = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected gas price hex string")
        }

        guard let price = BigInt(priceHex.stripHexPrefix(), radix: 16) else {
            throw TransactionError.invalidResponse("Invalid gas price format")
        }

        return price
    }

    public func maxPriorityFeePerGas() async throws -> BigInt {
        let request = RpcRequest(method: "eth_maxPriorityFeePerGas", params: [])
        let response = try await transport.send(request: request)

        guard let feeHex = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected max priority fee hex string")
        }

        guard let fee = BigInt(feeHex.stripHexPrefix(), radix: 16) else {
            throw TransactionError.invalidResponse("Invalid max priority fee format")
        }

        return fee
    }

    /// Gets fee data similar to ethers.js getFeeData()
    /// Returns recommended fee values for both EIP-1559 and legacy transactions
    /// - Returns: FeeData containing recommended fee values
    public func getFeeData() async throws -> FeeData {
        // Fetch latest block to check for EIP-1559 support
        let block = try? await getBlockByNumber(.latest, fullTransactions: false)

        // Fetch gas price (may fail on some networks)
        let gasPrice = try? await self.gasPrice()

        var lastBaseFeePerGas: BigInt? = nil
        var maxFeePerGas: BigInt? = nil
        var maxPriorityFeePerGas: BigInt? = nil

        // Check if block has baseFeePerGas (EIP-1559 support)
        if let block = block, let baseFeeHex = block.baseFeePerGas {
            // Parse base fee
            if let baseFee = BigInt(baseFeeHex.stripHexPrefix(), radix: 16) {
                lastBaseFeePerGas = baseFee

                // Use 1.5 Gwei as default priority fee (same as ethers.js)
                maxPriorityFeePerGas = BigInt(1_500_000_000)

                // Calculate maxFeePerGas: (baseFee * 2) + maxPriorityFeePerGas
                // This matches ethers.js formula
                maxFeePerGas = (baseFee * 2) + maxPriorityFeePerGas!
            }
        }

        return FeeData(
            lastBaseFeePerGas: lastBaseFeePerGas,
            maxFeePerGas: maxFeePerGas,
            maxPriorityFeePerGas: maxPriorityFeePerGas,
            gasPrice: gasPrice
        )
    }

    // MARK: - Account Methods

    public func getBalance(address: Address, block: BlockParameter = .latest) async throws
        -> BigInt
    {
        let request = RpcRequest(
            method: "eth_getBalance",
            params: [AnyCodable(address.value), AnyCodable(block.stringValue)]
        )
        let response = try await transport.send(request: request)

        guard let balanceHex = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected balance hex string")
        }

        guard let balance = BigInt(balanceHex.stripHexPrefix(), radix: 16) else {
            throw TransactionError.invalidResponse("Invalid balance format")
        }

        return balance
    }

    public func getTransactionCount(address: Address, block: BlockParameter = .latest)
        async throws -> BigInt
    {
        let request = RpcRequest(
            method: "eth_getTransactionCount",
            params: [AnyCodable(address.value), AnyCodable(block.stringValue)]
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

    public func getCode(address: Address, block: BlockParameter = .latest) async throws -> String {
        let request = RpcRequest(
            method: "eth_getCode",
            params: [AnyCodable(address.value), AnyCodable(block.stringValue)]
        )
        let response = try await transport.send(request: request)

        guard let code = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected code hex string")
        }

        return code
    }

    public func getStorageAt(address: Address, position: BigInt, block: BlockParameter = .latest)
        async throws -> String
    {
        let positionHex = "0x" + String(position, radix: 16)
        let request = RpcRequest(
            method: "eth_getStorageAt",
            params: [
                AnyCodable(address.value), AnyCodable(positionHex), AnyCodable(block.stringValue),
            ]
        )
        let response = try await transport.send(request: request)

        guard let storage = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected storage hex string")
        }

        return storage
    }

    // MARK: - Block Methods

    public func getBlockByNumber(_ block: BlockParameter, fullTransactions: Bool = false)
        async throws -> Block?
    {
        let request = RpcRequest(
            method: "eth_getBlockByNumber",
            params: [AnyCodable(block.stringValue), AnyCodable(fullTransactions)]
        )
        let response = try await transport.send(request: request)

        if response.result.value is NSNull {
            return nil
        }

        guard let blockDict = response.result.value as? [String: Any] else {
            throw TransactionError.invalidResponse("Expected block dictionary")
        }

        let jsonData = try JSONSerialization.data(withJSONObject: blockDict)
        let decoder = JSONDecoder()
        return try decoder.decode(Block.self, from: jsonData)
    }

    public func getBlockByHash(_ hash: String, fullTransactions: Bool = false) async throws
        -> Block?
    {
        let request = RpcRequest(
            method: "eth_getBlockByHash",
            params: [AnyCodable(hash), AnyCodable(fullTransactions)]
        )
        let response = try await transport.send(request: request)

        if response.result.value is NSNull {
            return nil
        }

        guard let blockDict = response.result.value as? [String: Any] else {
            throw TransactionError.invalidResponse("Expected block dictionary")
        }

        let jsonData = try JSONSerialization.data(withJSONObject: blockDict)
        let decoder = JSONDecoder()
        return try decoder.decode(Block.self, from: jsonData)
    }

    public func getBlockTransactionCountByNumber(_ block: BlockParameter) async throws -> BigInt {
        let request = RpcRequest(
            method: "eth_getBlockTransactionCountByNumber",
            params: [AnyCodable(block.stringValue)]
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

    public func getBlockTransactionCountByHash(_ hash: String) async throws -> BigInt {
        let request = RpcRequest(
            method: "eth_getBlockTransactionCountByHash",
            params: [AnyCodable(hash)]
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

    // MARK: - Transaction Methods

    public func sendTransaction(params: TransactionParams) async throws -> String {
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

    public func getTransactionByHash(_ hash: String) async throws -> Transaction? {
        let request = RpcRequest(
            method: "eth_getTransactionByHash",
            params: [AnyCodable(hash)]
        )
        let response = try await transport.send(request: request)

        if response.result.value is NSNull {
            return nil
        }

        guard let txDict = response.result.value as? [String: Any] else {
            throw TransactionError.invalidResponse("Expected transaction dictionary")
        }

        let jsonData = try JSONSerialization.data(withJSONObject: txDict)
        let decoder = JSONDecoder()
        return try decoder.decode(Transaction.self, from: jsonData)
    }

    public func getTransactionByBlockNumberAndIndex(_ block: BlockParameter, index: BigInt)
        async throws -> Transaction?
    {
        let indexHex = "0x" + String(index, radix: 16)
        let request = RpcRequest(
            method: "eth_getTransactionByBlockNumberAndIndex",
            params: [AnyCodable(block.stringValue), AnyCodable(indexHex)]
        )
        let response = try await transport.send(request: request)

        if response.result.value is NSNull {
            return nil
        }

        guard let txDict = response.result.value as? [String: Any] else {
            throw TransactionError.invalidResponse("Expected transaction dictionary")
        }

        let jsonData = try JSONSerialization.data(withJSONObject: txDict)
        let decoder = JSONDecoder()
        return try decoder.decode(Transaction.self, from: jsonData)
    }

    public func getTransactionReceipt(_ hash: String) async throws -> TransactionReceipt? {
        let request = RpcRequest(
            method: "eth_getTransactionReceipt",
            params: [AnyCodable(hash)]
        )
        let response = try await transport.send(request: request)

        if response.result.value is NSNull {
            return nil
        }

        guard let receiptDict = response.result.value as? [String: Any] else {
            throw TransactionError.invalidResponse("Expected receipt dictionary")
        }

        return try TransactionReceipt(from: receiptDict)
    }

    // MARK: - Call Methods

    public func call(params: CallParams, block: BlockParameter = .latest) async throws -> String {
        let request = RpcRequest(
            method: "eth_call",
            params: [AnyCodable(params), AnyCodable(block.stringValue)]
        )
        let response = try await transport.send(request: request)

        guard let result = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected call result hex string")
        }

        return result
    }

    public func estimateGas(params: TransactionParams) async throws -> BigInt {
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

        return gas
    }

    // MARK: - Filter Methods

    public func newFilter(params: FilterParams) async throws -> String {
        let request = RpcRequest(
            method: "eth_newFilter",
            params: [AnyCodable(params)]
        )
        let response = try await transport.send(request: request)

        guard let filterId = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected filter ID string")
        }

        return filterId
    }

    public func newBlockFilter() async throws -> String {
        let request = RpcRequest(method: "eth_newBlockFilter", params: [])
        let response = try await transport.send(request: request)

        guard let filterId = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected filter ID string")
        }

        return filterId
    }

    public func newPendingTransactionFilter() async throws -> String {
        let request = RpcRequest(method: "eth_newPendingTransactionFilter", params: [])
        let response = try await transport.send(request: request)

        guard let filterId = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected filter ID string")
        }

        return filterId
    }

    public func getFilterChanges(_ filterId: String) async throws -> [Log] {
        let request = RpcRequest(
            method: "eth_getFilterChanges",
            params: [AnyCodable(filterId)]
        )
        let response = try await transport.send(request: request)

        guard let logsArray = response.result.value as? [[String: Any]] else {
            throw TransactionError.invalidResponse("Expected logs array")
        }

        let jsonData = try JSONSerialization.data(withJSONObject: logsArray)
        let decoder = JSONDecoder()
        return try decoder.decode([Log].self, from: jsonData)
    }

    public func getFilterLogs(_ filterId: String) async throws -> [Log] {
        let request = RpcRequest(
            method: "eth_getFilterLogs",
            params: [AnyCodable(filterId)]
        )
        let response = try await transport.send(request: request)

        guard let logsArray = response.result.value as? [[String: Any]] else {
            throw TransactionError.invalidResponse("Expected logs array")
        }

        let jsonData = try JSONSerialization.data(withJSONObject: logsArray)
        let decoder = JSONDecoder()
        return try decoder.decode([Log].self, from: jsonData)
    }

    public func getLogs(params: FilterParams) async throws -> [Log] {
        let request = RpcRequest(
            method: "eth_getLogs",
            params: [AnyCodable(params)]
        )
        let response = try await transport.send(request: request)

        guard let logsArray = response.result.value as? [[String: Any]] else {
            throw TransactionError.invalidResponse("Expected logs array")
        }

        let jsonData = try JSONSerialization.data(withJSONObject: logsArray)
        let decoder = JSONDecoder()
        return try decoder.decode([Log].self, from: jsonData)
    }

    public func uninstallFilter(_ filterId: String) async throws -> Bool {
        let request = RpcRequest(
            method: "eth_uninstallFilter",
            params: [AnyCodable(filterId)]
        )
        let response = try await transport.send(request: request)

        guard let success = response.result.value as? Bool else {
            throw TransactionError.invalidResponse("Expected boolean result")
        }

        return success
    }

    // MARK: - Network Methods

    public func netVersion() async throws -> String {
        let request = RpcRequest(method: "net_version", params: [])
        let response = try await transport.send(request: request)

        guard let version = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected version string")
        }

        return version
    }

    public func netListening() async throws -> Bool {
        let request = RpcRequest(method: "net_listening", params: [])
        let response = try await transport.send(request: request)

        guard let listening = response.result.value as? Bool else {
            throw TransactionError.invalidResponse("Expected boolean result")
        }

        return listening
    }

    public func netPeerCount() async throws -> BigInt {
        let request = RpcRequest(method: "net_peerCount", params: [])
        let response = try await transport.send(request: request)

        guard let countHex = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected peer count hex string")
        }

        guard let count = BigInt(countHex.stripHexPrefix(), radix: 16) else {
            throw TransactionError.invalidResponse("Invalid peer count format")
        }

        return count
    }

    // MARK: - Web3 Methods

    public func web3ClientVersion() async throws -> String {
        let request = RpcRequest(method: "web3_clientVersion", params: [])
        let response = try await transport.send(request: request)

        guard let version = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected client version string")
        }

        return version
    }

    public func web3Sha3(_ data: String) async throws -> String {
        let request = RpcRequest(
            method: "web3_sha3",
            params: [AnyCodable(data)]
        )
        let response = try await transport.send(request: request)

        guard let hash = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected hash string")
        }

        return hash
    }

    // MARK: - Transaction Signing Methods

    /// Signs a raw transaction and returns the signed transaction
    /// - Parameter params: The transaction parameters
    /// - Returns: The signed transaction as a hex string
    public func signTransaction(params: TransactionParams) async throws -> (
        String, PendingTransaction
    ) {
        // Get chain ID
        let chainId = try await self.chainId()

        // Get nonce if not provided
        let nonce: BigInt
        if let nonceHex = params.nonce {
            guard let nonceValue = BigInt(nonceHex.stripHexPrefix(), radix: 16) else {
                throw TransactionError.invalidResponse("Invalid nonce format")
            }
            nonce = nonceValue
        } else {
            nonce = try await getTransactionCount(
                address: signer.address, block: .pending)
        }

        // Get gas limit, either from params or estimate it
        let gasLimit: BigInt
        if let gasHex = params.gas {
            guard let gasValue = BigInt(gasHex.stripHexPrefix(), radix: 16) else {
                throw TransactionError.invalidResponse("Invalid gas format")
            }
            gasLimit = gasValue
        } else {
            gasLimit = try await estimateGas(params: params)
        }

        // Get gas price parameters for EIP-1559 (Type 2 transactions only)
        // Note: Legacy transactions (Type 0) are not supported
        // gasPrice parameter is ignored (legacy only)
        let maxPriorityFeePerGas: BigInt
        let maxFeePerGas: BigInt

        // If both fee parameters are provided, use them directly
        if let priorityFeeHex = params.maxPriorityFeePerGas,
            let maxFeeHex = params.maxFeePerGas
        {
            guard let priorityFeeValue = BigInt(priorityFeeHex.stripHexPrefix(), radix: 16) else {
                throw TransactionError.invalidResponse("Invalid maxPriorityFeePerGas format")
            }
            guard let maxFeeValue = BigInt(maxFeeHex.stripHexPrefix(), radix: 16) else {
                throw TransactionError.invalidResponse("Invalid maxFeePerGas format")
            }
            maxPriorityFeePerGas = priorityFeeValue
            maxFeePerGas = maxFeeValue
        } else if let priorityFeeHex = params.maxPriorityFeePerGas {
            // Only priority fee provided, calculate maxFee
            guard let priorityFeeValue = BigInt(priorityFeeHex.stripHexPrefix(), radix: 16) else {
                throw TransactionError.invalidResponse("Invalid maxPriorityFeePerGas format")
            }
            maxPriorityFeePerGas = priorityFeeValue

            // Calculate maxFeePerGas: gasPrice + priority fee
            let baseGasPrice = try await self.gasPrice()
            maxFeePerGas = baseGasPrice + maxPriorityFeePerGas
        } else if let maxFeeHex = params.maxFeePerGas {
            // Only maxFee provided, get priority fee from network
            guard let maxFeeValue = BigInt(maxFeeHex.stripHexPrefix(), radix: 16) else {
                throw TransactionError.invalidResponse("Invalid maxFeePerGas format")
            }
            maxFeePerGas = maxFeeValue

            // Try to get maxPriorityFeePerGas from network, fallback to 1 gwei if not supported
            do {
                maxPriorityFeePerGas = try await self.maxPriorityFeePerGas()
            } catch {
                // Fallback to 1 gwei for chains that don't support eth_maxPriorityFeePerGas
                maxPriorityFeePerGas = BigInt(1_000_000_000)  // 1 gwei
            }
        } else {
            // Neither provided, use getFeeData() for recommended values
            let feeData = try await self.getFeeData()

            // If EIP-1559 data is available, use it
            if let maxFee = feeData.maxFeePerGas, let priorityFee = feeData.maxPriorityFeePerGas {
                maxFeePerGas = maxFee
                maxPriorityFeePerGas = priorityFee
            } else if let gasPrice = feeData.gasPrice {
                // Fallback to legacy gas price for non-EIP-1559 networks
                maxPriorityFeePerGas = BigInt(1_500_000_000)  // 1.5 gwei default
                maxFeePerGas = gasPrice + maxPriorityFeePerGas
            } else {
                // Last resort: fetch gas price directly
                let baseGasPrice = try await self.gasPrice()
                maxPriorityFeePerGas = BigInt(1_500_000_000)  // 1.5 gwei default
                maxFeePerGas = baseGasPrice + maxPriorityFeePerGas
            }
        }

        // Parse value
        let value: BigInt
        if let transactionValue = params.value {
            value = transactionValue.toWei().value
        } else {
            value = 0
        }

        // Get data
        let data = params.data ?? "0x"

        // EIP-1559 (Type 2) transaction only - legacy transactions are not supported
        // Transaction fields: [chainId, nonce, maxPriorityFeePerGas, maxFeePerGas, gasLimit, to, value, data, accessList]
        var txFields: [Any] = [
            chainId,
            nonce,
            maxPriorityFeePerGas,
            maxFeePerGas,
            gasLimit,
        ]

        // Add 'to' address (or empty for contract creation)
        // The 'to' field must be raw 20-byte address data, not a hex string
        if let toAddress = params.to {
            // Convert hex address string to 20-byte Data
            let cleanAddress =
                toAddress.hasPrefix("0x") ? String(toAddress.dropFirst(2)) : toAddress
            guard cleanAddress.count == 40 else {
                throw TransactionError.invalidResponse("Invalid address length: \(toAddress)")
            }
            let toData = Data(hex: cleanAddress)
            guard toData.count == 20 else {
                throw TransactionError.invalidResponse("Address must be 20 bytes")
            }
            txFields.append(toData)
        } else {
            txFields.append(Data())
        }

        txFields.append(value)
        txFields.append(data)
        txFields.append([])  // Empty access list

        // Encode the transaction for signing
        let encodedTx = RLP.encode(txFields)

        // Prepend transaction type byte (0x02 for EIP-1559)
        var txForSigning = Data([0x02])
        txForSigning.append(encodedTx)

        // Sign the transaction (signer will hash with keccak256 and sign)
        let signature = try await signer.sign(message: txForSigning)

        // Extract v, r, s from signature (signature is 65 bytes: r + s + v)
        guard signature.count == 65 else {
            throw TransactionError.invalidResponse("Invalid signature length")
        }

        // Use explicit byte ranges to ensure we get exactly 32 bytes for r and s
        let r = signature[0..<32]
        let s = signature[32..<64]
        let v = signature[64]

        // For EIP-1559, v is the y parity (0 or 1)
        // The signature from PrivateKeySigner uses Ethereum format (27/28)
        // Convert to y parity
        let yParity = BigInt(v >= 27 ? v - 27 : v)

        // Build signed transaction: [chainId, nonce, maxPriorityFeePerGas, maxFeePerGas, gasLimit, to, value, data, accessList, yParity, r, s]
        // Note: r and s must remain as Data (32-byte arrays) to preserve leading zeros
        // Converting to BigInt would strip leading zeros and invalidate the signature
        var signedTxFields = txFields
        signedTxFields.append(yParity)

        // Ensure r and s are proper Data objects, not slices, and exactly 32 bytes
        let rData = Data(r)
        let sData = Data(s)
        guard rData.count == 32 else {
            throw TransactionError.invalidResponse(
                "Signature r component must be 32 bytes, got \(rData.count)")
        }
        guard sData.count == 32 else {
            throw TransactionError.invalidResponse(
                "Signature s component must be 32 bytes, got \(sData.count)")
        }

        // Convert r and s to BigInt for proper RLP encoding as integers
        // EIP-1559 requires r and s to be encoded as integers, not byte strings
        // IMPORTANT: Must convert as unsigned (positive) integers
        let rHex = rData.map { String(format: "%02x", $0) }.joined()
        let sHex = sData.map { String(format: "%02x", $0) }.joined()

        guard let rBigInt = BigInt(rHex, radix: 16) else {
            throw TransactionError.invalidResponse("Failed to convert r to BigInt")
        }
        guard let sBigInt = BigInt(sHex, radix: 16) else {
            throw TransactionError.invalidResponse("Failed to convert s to BigInt")
        }

        signedTxFields.append(rBigInt)
        signedTxFields.append(sBigInt)

        // Encode the signed transaction
        let encodedSignedTx = RLP.encode(signedTxFields)

        // Prepend transaction type byte
        var finalTx = Data([0x02])
        finalTx.append(encodedSignedTx)

        // Calculate transaction hash (keccak256 of the signed transaction)
        let txHash = "0x" + finalTx.sha3(.keccak256).map { String(format: "%02x", $0) }.joined()

        // Return as hex string
        return (
            "0x" + finalTx.map { String(format: "%02x", $0) }.joined(),
            PendingTransaction(
                txHash: txHash,
                from: signer.address.value,
                to: params.to ?? "0x",
                value: "0x" + String(value, radix: 16),
                gas: "0x" + String(gasLimit, radix: 16),
                gasPrice: "0x" + String(maxFeePerGas, radix: 16),
                nonce: "0x" + String(nonce, radix: 16),
                data: data,
                client: self)
        )
    }

    /// Signs a transaction and sends it to the network
    /// - Parameter params: The transaction parameters
    /// - Returns: The transaction hash
    public func signAndSendTransaction(params: TransactionParams) async throws -> PendingTransaction
    {
        // Sign the transaction
        var (signedTx, pendingTx) = try await signTransaction(params: params)

        // Send the raw transaction
        let request = RpcRequest(
            method: "eth_sendRawTransaction",
            params: [AnyCodable(signedTx)]
        )
        let response = try await transport.send(request: request)

        guard let txHash = response.result.value as? String else {
            throw TransactionError.invalidResponse("Expected transaction hash string")
        }

        pendingTx.txHash = txHash
        return pendingTx
    }
}
