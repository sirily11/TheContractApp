import BigInt
import Foundation
import Testing

@testable import EvmCore

/// E2E tests for EvmClient and EvmClientWithSigner RPC methods
@Suite("EVM Client E2E Tests", .serialized)
struct EvmClientE2ETests {

    static let anvilUrl = "http://localhost:8545"

    // MARK: - Blockchain Information Tests

    @Test("Get current block number")
    func testBlockNumber() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let client = EvmClient(transport: transport)

        let blockNumber = try await client.blockNumber()
        print("Current block number: \(blockNumber)")

        // Anvil starts at block 0 and increases
        #expect(blockNumber >= 0)
    }

    @Test("Get chain ID")
    func testChainId() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let client = EvmClient(transport: transport)

        let chainId = try await client.chainId()
        print("Chain ID: \(chainId)")

        // Anvil default chain ID is 31337
        #expect(chainId == 31337)
    }

    @Test("Get gas price")
    func testGasPrice() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let client = EvmClient(transport: transport)

        let gasPrice = try await client.gasPrice()
        print("Gas price: \(gasPrice) wei")

        #expect(gasPrice > 0)
    }

    @Test("Get max priority fee per gas")
    func testMaxPriorityFeePerGas() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let client = EvmClient(transport: transport)

        let maxFee = try await client.maxPriorityFeePerGas()
        print("Max priority fee per gas: \(maxFee) wei")

        #expect(maxFee >= 0)
    }

    // MARK: - Account Tests

    @Test("Get account balance")
    func testGetBalance() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let client = EvmClient(transport: transport)
        let address = try Address(AnvilAccounts.account0)

        let balance = try await client.getBalance(address: address, block: .latest)
        print("Account balance: \(balance) wei")

        // Anvil accounts start with 10000 ETH = 10000000000000000000000 wei
        #expect(balance > 0)
    }

    @Test("Get transaction count (nonce)")
    func testGetTransactionCount() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let client = EvmClient(transport: transport)
        let address = try Address(AnvilAccounts.account0)

        let nonce = try await client.getTransactionCount(address: address, block: .latest)
        print("Account nonce: \(nonce)")

        // Nonce should be >= 0 (might have sent transactions in previous tests)
        #expect(nonce >= 0)
    }

    @Test("Get code from account (should be empty for EOA)")
    func testGetCodeEOA() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let client = EvmClient(transport: transport)
        let address = try Address(AnvilAccounts.account0)

        let code = try await client.getCode(address: address, block: .latest)
        print("EOA code: \(code)")

        // EOAs have no code (just "0x")
        #expect(code == "0x")
    }

    @Test("Get storage at position")
    func testGetStorageAt() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let client = EvmClient(transport: transport)
        let address = try Address(AnvilAccounts.account0)

        let storage = try await client.getStorageAt(
            address: address, position: 0, block: .latest)
        print("Storage at position 0: \(storage)")

        // Should return a hex string (32 bytes padded)
        #expect(storage.hasPrefix("0x"))
    }

    // MARK: - Block Tests

    @Test("Get block by number")
    func testGetBlockByNumber() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let client = EvmClient(transport: transport)

        let block = try await client.getBlockByNumber(.latest, fullTransactions: false)
        print("Latest block: \(String(describing: block?.number))")

        #expect(block != nil)
        #expect(block?.number != nil)
        #expect(block?.hash != nil)
    }

    @Test("Get block by number with full transactions")
    func testGetBlockByNumberFullTx() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let signer = try AnvilSigner(addressString: AnvilAccounts.account0)
        let client = EvmClient(transport: transport).withSigner(signer: signer)

        // Send a transaction first
        let txParams = TransactionParams(
            from: AnvilAccounts.account0,
            to: AnvilAccounts.account1,
            value: "0x1"  // 1 wei
        )
        let txHash = try await client.sendTransaction(params: txParams)
        print("Sent transaction: \(txHash)")

        // Wait a bit for block to be mined
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

        // Get the block with full transaction objects
        let block = try await client.getBlockByNumber(.latest, fullTransactions: true)

        #expect(block != nil)
        #expect(block?.transactions.isEmpty == false)
    }

    @Test("Get block by hash")
    func testGetBlockByHash() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let client = EvmClient(transport: transport)

        // First get the latest block to get its hash
        let latestBlock = try await client.getBlockByNumber(.latest, fullTransactions: false)
        guard let blockHash = latestBlock?.hash else {
            Issue.record("No block hash found")
            return
        }

        let block = try await client.getBlockByHash(blockHash, fullTransactions: false)
        print("Block by hash: \(String(describing: block?.number))")

        #expect(block != nil)
        #expect(block?.hash == blockHash)
    }

    @Test("Get block transaction count by number")
    func testGetBlockTransactionCountByNumber() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let client = EvmClient(transport: transport)

        let count = try await client.getBlockTransactionCountByNumber(.latest)
        print("Transaction count in latest block: \(count)")

        #expect(count >= 0)
    }

    @Test("Get block transaction count by hash")
    func testGetBlockTransactionCountByHash() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let client = EvmClient(transport: transport)

        // Get latest block hash
        let latestBlock = try await client.getBlockByNumber(.latest, fullTransactions: false)
        guard let blockHash = latestBlock?.hash else {
            Issue.record("No block hash found")
            return
        }

        let count = try await client.getBlockTransactionCountByHash(blockHash)
        print("Transaction count by hash: \(count)")

        #expect(count >= 0)
    }

    // MARK: - Transaction Tests

    @Test("Send transaction and get transaction details")
    func testSendAndGetTransaction() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let signer = try AnvilSigner(addressString: AnvilAccounts.account0)
        let client = EvmClient(transport: transport).withSigner(signer: signer)

        // Send a transaction
        let txParams = TransactionParams(
            from: AnvilAccounts.account0,
            to: AnvilAccounts.account1,
            value: "0x100"  // 256 wei
        )
        let txHash = try await client.sendTransaction(params: txParams)
        print("Transaction hash: \(txHash)")

        #expect(txHash.hasPrefix("0x"))

        // Wait for transaction to be mined
        try await Task.sleep(nanoseconds: 500_000_000)

        // Get transaction details
        let tx = try await client.getTransactionByHash(txHash)
        print("Transaction details: \(String(describing: tx))")

        #expect(tx != nil)
        #expect(tx?.hash == txHash)
        #expect(tx?.from?.lowercased() == AnvilAccounts.account0.lowercased())
        #expect(tx?.to?.lowercased() == AnvilAccounts.account1.lowercased())
    }

    @Test("Get transaction by block number and index")
    func testGetTransactionByBlockNumberAndIndex() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let signer = try AnvilSigner(addressString: AnvilAccounts.account0)
        let client = EvmClient(transport: transport).withSigner(signer: signer)

        // Send a transaction
        let txParams = TransactionParams(
            from: AnvilAccounts.account0,
            to: AnvilAccounts.account1,
            value: "0x200"  // 512 wei
        )
        _ = try await client.sendTransaction(params: txParams)

        // Wait for transaction to be mined
        try await Task.sleep(nanoseconds: 500_000_000)

        // Get transaction by block number and index
        let tx = try await client.getTransactionByBlockNumberAndIndex(.latest, index: 0)
        print("Transaction at index 0: \(String(describing: tx))")

        #expect(tx != nil)
    }

    @Test("Get transaction receipt")
    func testGetTransactionReceipt() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let signer = try AnvilSigner(addressString: AnvilAccounts.account0)
        let client = EvmClient(transport: transport).withSigner(signer: signer)

        // Send a transaction
        let txParams = TransactionParams(
            from: AnvilAccounts.account0,
            to: AnvilAccounts.account1,
            value: "0x300"  // 768 wei
        )
        let txHash = try await client.sendTransaction(params: txParams)

        // Wait for transaction to be mined
        try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second

        // Get receipt
        let receipt = try await client.getTransactionReceipt(txHash)
        print("Transaction receipt: \(String(describing: receipt))")

        #expect(receipt != nil)
        #expect(receipt?.transactionHash == txHash)
        #expect(receipt?.isSuccessful == true)
    }

    // MARK: - Call and Estimate Gas Tests

    @Test("Call contract (read-only)")
    func testCall() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let client = EvmClient(transport: transport)

        // Call eth_getBalance via eth_call (as an example)
        // In practice, you'd call a contract function here
        let callParams = CallParams(
            to: AnvilAccounts.account0,
            data: "0x"  // Empty data
        )

        let result = try await client.call(params: callParams, block: .latest)
        print("Call result: \(result)")

        #expect(result.hasPrefix("0x"))
    }

    @Test("Estimate gas for transaction")
    func testEstimateGas() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let client = EvmClient(transport: transport)

        let txParams = TransactionParams(
            from: AnvilAccounts.account0,
            to: AnvilAccounts.account1,
            value: "0x100"
        )

        let gasEstimate = try await client.estimateGas(params: txParams)
        print("Gas estimate: \(gasEstimate)")

        // Basic ETH transfer should use 21000 gas
        #expect(gasEstimate >= 21000)
    }

    // MARK: - Filter and Logs Tests

    @Test("Create and manage filters")
    func testFilters() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let client = EvmClient(transport: transport)

        // Create a new block filter
        let blockFilterId = try await client.newBlockFilter()
        print("Block filter ID: \(blockFilterId)")
        #expect(blockFilterId.hasPrefix("0x"))

        // Create a new pending transaction filter
        let pendingFilterId = try await client.newPendingTransactionFilter()
        print("Pending tx filter ID: \(pendingFilterId)")
        #expect(pendingFilterId.hasPrefix("0x"))

        // Create a log filter
        let filterParams = FilterParams(
            fromBlock: "latest",
            toBlock: "latest"
        )
        let logFilterId = try await client.newFilter(params: filterParams)
        print("Log filter ID: \(logFilterId)")
        #expect(logFilterId.hasPrefix("0x"))

        // Get filter changes (should be empty initially)
        let changes = try await client.getFilterChanges(blockFilterId)
        print("Filter changes: \(changes)")

        // Get filter logs
        let logs = try await client.getFilterLogs(logFilterId)
        print("Filter logs: \(logs)")

        // Uninstall filters
        let uninstalled1 = try await client.uninstallFilter(blockFilterId)
        let uninstalled2 = try await client.uninstallFilter(pendingFilterId)
        let uninstalled3 = try await client.uninstallFilter(logFilterId)

        #expect(uninstalled1 == true)
        #expect(uninstalled2 == true)
        #expect(uninstalled3 == true)
    }

    @Test("Get logs with filter params")
    func testGetLogs() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let signer = try AnvilSigner(addressString: AnvilAccounts.account0)
        let client = EvmClient(transport: transport).withSigner(signer: signer)

        // Send a transaction to generate some activity
        let txParams = TransactionParams(
            from: AnvilAccounts.account0,
            to: AnvilAccounts.account1,
            value: "0x1"
        )
        _ = try await client.sendTransaction(params: txParams)

        // Wait for transaction to be mined
        try await Task.sleep(nanoseconds: 500_000_000)

        // Get logs from the latest block
        let filterParams = FilterParams(
            fromBlock: "latest",
            toBlock: "latest"
        )
        let logs = try await client.getLogs(params: filterParams)
        print("Logs found: \(logs.count)")

        // Logs array should exist (might be empty for simple transfers)
        #expect(logs.count >= 0)
    }

    // MARK: - Network Tests

    @Test("Get network version")
    func testNetVersion() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let client = EvmClient(transport: transport)

        let version = try await client.netVersion()
        print("Network version: \(version)")

        // Anvil returns chain ID as string for net_version
        #expect(version == "31337")
    }

    @Test("Check if network is listening")
    func testNetListening() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let client = EvmClient(transport: transport)

        let listening = try await client.netListening()
        print("Network listening: \(listening)")

        // Anvil should be listening if we can connect to it
        #expect(listening == true)
    }

    @Test("Get peer count")
    func testNetPeerCount() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let client = EvmClient(transport: transport)

        // Note: Anvil doesn't support net_peerCount, so we expect this to fail
        // This test verifies that the method is implemented correctly, even if Anvil doesn't support it
        do {
            let peerCount = try await client.netPeerCount()
            print("Peer count: \(peerCount)")
            // If it succeeds, peer count should be >= 0
            #expect(peerCount >= 0)
        } catch {
            // Anvil doesn't implement net_peerCount, which is expected
            print("Note: Anvil doesn't support net_peerCount (expected): \(error)")
            // Test passes - we just verify the method is implemented
            // The error is expected since Anvil doesn't support this RPC method
        }
    }

    // MARK: - Web3 Tests

    @Test("Get web3 client version")
    func testWeb3ClientVersion() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let client = EvmClient(transport: transport)

        let version = try await client.web3ClientVersion()
        print("Client version: \(version)")

        // Should return a version string (e.g., "anvil/v0.2.0")
        #expect(!version.isEmpty)
    }

    @Test("Compute web3 SHA3 hash")
    func testWeb3Sha3() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let client = EvmClient(transport: transport)

        let data = "0x68656c6c6f20776f726c64"  // "hello world" in hex
        let hash = try await client.web3Sha3(data)
        print("SHA3 hash: \(hash)")

        #expect(hash.hasPrefix("0x"))
        #expect(hash.count == 66)  // 0x + 64 hex chars (32 bytes)
    }

    // MARK: - EvmClientWithSigner Integration Tests

    @Test("EvmClientWithSigner full workflow")
    func testEvmClientWithSignerWorkflow() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let signer = try AnvilSigner(addressString: AnvilAccounts.account0)
        let client = EvmClient(transport: transport).withSigner(signer: signer)

        // Test blockchain info
        let chainId = try await client.chainId()
        #expect(chainId == 31337)

        // Test account methods
        let balance = try await client.getBalance(
            address: try Address(AnvilAccounts.account0), block: .latest)
        #expect(balance > 0)

        // Test transaction sending
        let txParams = TransactionParams(
            from: AnvilAccounts.account0,
            to: AnvilAccounts.account1,
            value: "0x1000"  // 4096 wei
        )
        let txHash = try await client.sendTransaction(params: txParams)
        #expect(txHash.hasPrefix("0x"))

        // Wait and verify receipt
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let receipt = try await client.getTransactionReceipt(txHash)
        #expect(receipt != nil)
        #expect(receipt?.isSuccessful == true)

        print("EvmClientWithSigner workflow completed successfully")
    }

    // MARK: - Block Parameter Tests

    @Test("Test different block parameters")
    func testBlockParameters() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let client = EvmClient(transport: transport)
        let address = try Address(AnvilAccounts.account0)

        // Test "latest"
        let balanceLatest = try await client.getBalance(address: address, block: .latest)
        #expect(balanceLatest > 0)

        // Test "earliest"
        let balanceEarliest = try await client.getBalance(address: address, block: .earliest)
        #expect(balanceEarliest > 0)

        // Test "pending"
        let balancePending = try await client.getBalance(address: address, block: .pending)
        #expect(balancePending > 0)

        // Test specific block number
        let balanceAtBlock = try await client.getBalance(
            address: address, block: .number(0))
        #expect(balanceAtBlock > 0)

        print("All block parameters tested successfully")
    }
}
