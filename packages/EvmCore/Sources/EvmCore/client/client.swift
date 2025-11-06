import BigInt
import Foundation

// MARK: - Response Types

/// Block parameter type for RPC calls
public enum BlockParameter: Codable, ExpressibleByStringLiteral {
    case latest
    case earliest
    case pending
    case number(BigInt)

    public init(stringLiteral value: String) {
        switch value.lowercased() {
        case "latest":
            self = .latest
        case "earliest":
            self = .earliest
        case "pending":
            self = .pending
        default:
            // Try to parse as hex number
            if let number = BigInt(value, radix: 16) {
                self = .number(number)
            } else {
                self = .latest
            }
        }
    }

    public var stringValue: String {
        switch self {
        case .latest:
            return "latest"
        case .earliest:
            return "earliest"
        case .pending:
            return "pending"
        case .number(let num):
            return "0x" + String(num, radix: 16)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self.init(stringLiteral: value)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(stringValue)
    }
}

/// Transaction object returned from RPC calls
public struct Transaction: Codable {
    public let hash: String?
    public let nonce: String?
    public let blockHash: String?
    public let blockNumber: String?
    public let transactionIndex: String?
    public let from: String?
    public let to: String?
    public let value: String?
    public let gas: String?
    public let gasPrice: String?
    public let input: String?
    public let v: String?
    public let r: String?
    public let s: String?
}

/// Log entry from transaction receipt or filter
public struct Log: Codable {
    public let address: String
    public let topics: [String]
    public let data: String
    public let blockNumber: String?
    public let blockHash: String?
    public let transactionHash: String?
    public let transactionIndex: String?
    public let logIndex: String?
    public let removed: Bool?
}

/// Block object returned from RPC calls
public struct Block: Codable {
    public let number: String?
    public let hash: String?
    public let parentHash: String
    public let nonce: String?
    public let sha3Uncles: String
    public let logsBloom: String?
    public let transactionsRoot: String
    public let stateRoot: String
    public let receiptsRoot: String
    public let miner: String?
    public let difficulty: String?
    public let totalDifficulty: String?
    public let extraData: String
    public let size: String
    public let gasLimit: String
    public let gasUsed: String
    public let timestamp: String
    public let transactions: [AnyCodable]  // Can be transaction hashes or Transaction objects
    public let uncles: [String]
}

/// Call parameters for eth_call
public struct CallParams: Codable {
    public let from: String?
    public let to: String
    public let gas: String?
    public let gasPrice: String?
    public let value: String?
    public let data: String?

    public init(
        from: String? = nil, to: String, gas: String? = nil, gasPrice: String? = nil,
        value: String? = nil, data: String? = nil
    ) {
        self.from = from
        self.to = to
        self.gas = gas
        self.gasPrice = gasPrice
        self.value = value
        self.data = data
    }
}

/// Transaction parameters for eth_sendTransaction
public struct TransactionParams: Codable {
    public let from: String
    public let to: String?
    public let gas: String?
    public let gasPrice: String?
    public let value: String?
    public let data: String?
    public let nonce: String?

    public init(
        from: String, to: String? = nil, gas: String? = nil, gasPrice: String? = nil,
        value: String? = nil, data: String? = nil, nonce: String? = nil
    ) {
        self.from = from
        self.to = to
        self.gas = gas
        self.gasPrice = gasPrice
        self.value = value
        self.data = data
        self.nonce = nonce
    }
}

/// Filter parameters for creating event filters
public struct FilterParams: Codable {
    public let fromBlock: String?
    public let toBlock: String?
    public let address: String?
    public let topics: [String?]?

    public init(
        fromBlock: String? = nil, toBlock: String? = nil, address: String? = nil,
        topics: [String?]? = nil
    ) {
        self.fromBlock = fromBlock
        self.toBlock = toBlock
        self.address = address
        self.topics = topics
    }
}

/// Protocol defining EVM RPC methods mapped to Swift functions
public protocol EvmRpcClientProtocol {
    // MARK: - Blockchain Information

    /// Returns the number of the most recent block
    /// - Returns: The current block number
    func blockNumber() async throws -> BigInt

    /// Returns the chain ID of the current network
    /// - Returns: The chain ID
    func chainId() async throws -> BigInt

    /// Returns the current gas price in wei
    /// - Returns: The current gas price
    func gasPrice() async throws -> BigInt

    /// Returns the current max priority fee per gas
    /// - Returns: The max priority fee per gas
    func maxPriorityFeePerGas() async throws -> BigInt

    // MARK: - Account Methods

    /// Returns the balance of the account at the given address
    /// - Parameters:
    ///   - address: The address to check the balance of
    ///   - block: The block number, or "latest", "earliest", "pending"
    /// - Returns: The balance in wei
    func getBalance(address: Address, block: BlockParameter) async throws -> BigInt

    /// Returns the number of transactions sent from an address
    /// - Parameters:
    ///   - address: The address to check
    ///   - block: The block number, or "latest", "earliest", "pending"
    /// - Returns: The number of transactions sent
    func getTransactionCount(address: Address, block: BlockParameter) async throws -> BigInt

    /// Returns the code at a given address
    /// - Parameters:
    ///   - address: The address to get the code from
    ///   - block: The block number, or "latest", "earliest", "pending"
    /// - Returns: The code at the address as a hex string
    func getCode(address: Address, block: BlockParameter) async throws -> String

    /// Returns the value from a storage position at a given address
    /// - Parameters:
    ///   - address: The address of the storage
    ///   - position: The position in the storage
    ///   - block: The block number, or "latest", "earliest", "pending"
    /// - Returns: The value at the storage position
    func getStorageAt(address: Address, position: BigInt, block: BlockParameter) async throws
        -> String

    // MARK: - Block Methods

    /// Returns information about a block by block number
    /// - Parameters:
    ///   - block: The block number, or "latest", "earliest", "pending"
    ///   - fullTransactions: If true, returns full transaction objects; if false, returns transaction hashes
    /// - Returns: The block object
    func getBlockByNumber(_ block: BlockParameter, fullTransactions: Bool) async throws -> Block?

    /// Returns information about a block by block hash
    /// - Parameters:
    ///   - hash: The block hash
    ///   - fullTransactions: If true, returns full transaction objects; if false, returns transaction hashes
    /// - Returns: The block object
    func getBlockByHash(_ hash: String, fullTransactions: Bool) async throws -> Block?

    /// Returns the number of transactions in a block
    /// - Parameters:
    ///   - block: The block number, or "latest", "earliest", "pending"
    /// - Returns: The number of transactions
    func getBlockTransactionCountByNumber(_ block: BlockParameter) async throws -> BigInt

    /// Returns the number of transactions in a block by block hash
    /// - Parameters:
    ///   - hash: The block hash
    /// - Returns: The number of transactions
    func getBlockTransactionCountByHash(_ hash: String) async throws -> BigInt

    // MARK: - Transaction Methods

    /// Sends a transaction to the network
    /// - Parameter params: The transaction parameters
    /// - Returns: The transaction hash
    func sendTransaction(params: TransactionParams) async throws -> String

    /// Returns the information about a transaction requested by transaction hash
    /// - Parameter hash: The transaction hash
    /// - Returns: The transaction object, or nil if not found
    func getTransactionByHash(_ hash: String) async throws -> Transaction?

    /// Returns information about a transaction by block number and transaction index
    /// - Parameters:
    ///   - block: The block number, or "latest", "earliest", "pending"
    ///   - index: The transaction index position
    /// - Returns: The transaction object, or nil if not found
    func getTransactionByBlockNumberAndIndex(_ block: BlockParameter, index: BigInt) async throws
        -> Transaction?

    /// Returns the receipt of a transaction by transaction hash
    /// - Parameter hash: The transaction hash
    /// - Returns: The transaction receipt, or nil if not found
    func getTransactionReceipt(_ hash: String) async throws -> TransactionReceipt?

    // MARK: - Call Methods

    /// Executes a new message call immediately without creating a transaction on the block chain
    /// - Parameters:
    ///   - params: The call parameters
    ///   - block: The block number, or "latest", "earliest", "pending"
    /// - Returns: The return value of the executed contract
    func call(params: CallParams, block: BlockParameter) async throws -> String

    /// Generates and returns an estimate of how much gas is necessary to allow the transaction to complete
    /// - Parameter params: The transaction parameters
    /// - Returns: The amount of gas used
    func estimateGas(params: TransactionParams) async throws -> BigInt

    // MARK: - Filter Methods

    /// Creates a filter object, based on filter options, to notify when the state changes
    /// - Parameter params: The filter parameters
    /// - Returns: The filter ID
    func newFilter(params: FilterParams) async throws -> String

    /// Creates a filter in the node, to notify when a new block arrives
    /// - Returns: The filter ID
    func newBlockFilter() async throws -> String

    /// Creates a filter in the node, to notify when new pending transactions arrive
    /// - Returns: The filter ID
    func newPendingTransactionFilter() async throws -> String

    /// Polling method for a filter, which returns an array of logs which occurred since last poll
    /// - Parameter filterId: The filter ID
    /// - Returns: Array of log objects
    func getFilterChanges(_ filterId: String) async throws -> [Log]

    /// Returns an array of all logs matching filter with given id
    /// - Parameter filterId: The filter ID
    /// - Returns: Array of log objects
    func getFilterLogs(_ filterId: String) async throws -> [Log]

    /// Returns an array of all logs matching a given filter object
    /// - Parameter params: The filter parameters
    /// - Returns: Array of log objects
    func getLogs(params: FilterParams) async throws -> [Log]

    /// Uninstalls a filter with given id
    /// - Parameter filterId: The filter ID
    /// - Returns: True if the filter was successfully uninstalled, false otherwise
    func uninstallFilter(_ filterId: String) async throws -> Bool

    // MARK: - Network Methods

    /// Returns the current network ID
    /// - Returns: The network ID
    func netVersion() async throws -> String

    /// Returns true if client is actively listening for network connections
    /// - Returns: True if listening, false otherwise
    func netListening() async throws -> Bool

    /// Returns the number of peers currently connected to the client
    /// - Returns: The number of connected peers
    func netPeerCount() async throws -> BigInt

    // MARK: - Web3 Methods

    /// Returns the current client version
    /// - Returns: The client version string
    func web3ClientVersion() async throws -> String

    /// Returns Keccak-256 (not the standardized SHA3-256) of the given data
    /// - Parameter data: The data to hash
    /// - Returns: The Keccak-256 hash
    func web3Sha3(_ data: String) async throws -> String
}

/// A signer that can be used to sign transactions and messages
public protocol EvmSignerProtocol: Signer, Contract {}
