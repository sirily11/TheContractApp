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
