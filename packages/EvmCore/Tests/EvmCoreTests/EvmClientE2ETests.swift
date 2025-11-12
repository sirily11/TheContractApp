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

    @Test("Get fee data (EIP-1559)")
    func testGetFeeData() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)
        let client = EvmClient(transport: transport)

        let feeData = try await client.getFeeData()
        print("Fee data:")
        print("  lastBaseFeePerGas: \(feeData.lastBaseFeePerGas?.description ?? "nil")")
        print("  maxFeePerGas: \(feeData.maxFeePerGas?.description ?? "nil")")
        print("  maxPriorityFeePerGas: \(feeData.maxPriorityFeePerGas?.description ?? "nil")")
        print("  gasPrice: \(feeData.gasPrice?.description ?? "nil")")

        // Anvil supports EIP-1559, so we should have base fee data
        #expect(feeData.lastBaseFeePerGas != nil)
        #expect(feeData.maxFeePerGas != nil)
        #expect(feeData.maxPriorityFeePerGas != nil)

        // Verify the ethers.js formula: maxFeePerGas = (baseFee * 2) + maxPriorityFeePerGas
        if let baseFee = feeData.lastBaseFeePerGas,
            let maxFee = feeData.maxFeePerGas,
            let priorityFee = feeData.maxPriorityFeePerGas
        {
            let expectedMaxFee = (baseFee * 2) + priorityFee
            #expect(maxFee == expectedMaxFee)

            // Priority fee should be 1.5 gwei (same as ethers.js default)
            #expect(priorityFee == BigInt(1_500_000_000))
        }

        // gasPrice should also be available
        #expect(feeData.gasPrice != nil)
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
            value: TransactionValue(wei: Wei(bigInt: BigInt(1)))  // 1 wei
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
            value: TransactionValue(wei: Wei(bigInt: BigInt(256)))  // 256 wei
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
            value: TransactionValue(wei: Wei(bigInt: BigInt(512)))  // 512 wei
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
            value: TransactionValue(wei: Wei(bigInt: BigInt(768)))  // 768 wei
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
            value: TransactionValue(wei: Wei(bigInt: BigInt(256)))
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
            value: TransactionValue(wei: Wei(bigInt: BigInt(1)))
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
            value: TransactionValue(wei: Wei(bigInt: BigInt(4096)))  // 4096 wei
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

    // MARK: - Transaction Signing Tests

    @Test("Sign transaction and send signed transaction")
    func testSignAndSendTransaction() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)

        // Create a PrivateKeySigner with Anvil account 1 private key (to avoid nonce conflicts with other tests)
        let privateKey = AnvilAccounts.privateKey0
        let signer = try PrivateKeySigner(hexPrivateKey: privateKey)
        #expect(signer.address.value == AnvilAccounts.account0, "Signer address is not account0")
        print("Using signer address: \(signer.address.value)")

        let client = EvmClient(transport: transport).withSigner(signer: signer)

        // Check balance of the signer account
        let signerBalance = try await client.getBalance(address: signer.address, block: .latest)
        print("Signer account balance: \(signerBalance)")

        // Get current nonce
        let currentNonce = try await client.getTransactionCount(
            address: signer.address, block: .pending)
        print("Current nonce: \(currentNonce)")

        // Get initial balance of recipient
        let recipientAddress = try Address(AnvilAccounts.account2)
        let initialBalance = try await client.getBalance(address: recipientAddress, block: .latest)
        print("Initial recipient balance: \(initialBalance)")

        // Get gas price parameters
        let maxPriorityFee = try await client.maxPriorityFeePerGas()
        let gasPrice = try await client.gasPrice()
        let maxFee = max(gasPrice + maxPriorityFee, maxPriorityFee * 3)
        print("Using maxPriorityFeePerGas: \(maxPriorityFee), maxFeePerGas: \(maxFee)")
        print("Estimated cost: \(21000 * maxFee + 10000) wei")

        // Prepare transaction parameters - let nonce auto-calculate
        let txParams = TransactionParams(
            from: signer.address.value,
            to: AnvilAccounts.account2,
            value: TransactionValue(wei: Wei(bigInt: BigInt(10000)))  // 10000 wei
        )

        print("About to call signAndSendTransaction...")
        // Sign and send the transaction
        let pendingTx = try await client.signAndSendTransaction(params: txParams)
        print("Transaction hash: \(pendingTx.txHash)")

        #expect(pendingTx.txHash.hasPrefix("0x"))
        #expect(pendingTx.txHash.count == 66)  // 0x + 64 hex chars

        // Wait for transaction to be mined
        try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second

        // Verify the transaction was successful
        let receipt = try await client.getTransactionReceipt(pendingTx.txHash)
        #expect(receipt != nil)
        #expect(receipt?.isSuccessful == true)
        #expect(receipt?.from.lowercased() == signer.address.value.lowercased())
        #expect(receipt?.to?.lowercased() == AnvilAccounts.account2.lowercased())

        // Verify balance increased
        let finalBalance = try await client.getBalance(address: recipientAddress, block: .latest)
        print("Final recipient balance: \(finalBalance)")
        #expect(finalBalance == initialBalance + 10000)

        print("signAndSendTransaction test completed successfully")
    }

    @Test("Sign transaction without sending")
    func testSignTransaction() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)

        // Create a PrivateKeySigner with Anvil account 0 private key
        let privateKey = AnvilAccounts.privateKey0
        let signer = try PrivateKeySigner(hexPrivateKey: privateKey)

        let client = EvmClient(transport: transport).withSigner(signer: signer)

        // Prepare transaction parameters - use signer's address
        let txParams = TransactionParams(
            from: signer.address.value,
            to: AnvilAccounts.account1,
            value: TransactionValue(wei: Wei(bigInt: BigInt(5000)))  // 5000 wei
        )

        // Sign the transaction (don't send it)
        let (signedTx, _) = try await client.signTransaction(params: txParams)
        print("Signed transaction: \(signedTx)")

        #expect(signedTx.hasPrefix("0x"))
        // EIP-1559 transactions start with 0x02
        #expect(signedTx.hasPrefix("0x02"))

        // The signed transaction should be RLP encoded and include signature
        // It should be longer than just a hash (66 chars)
        #expect(signedTx.count > 100)

        print("signTransaction test completed successfully")
    }

    @Test("Verify signed transaction has correct from address")
    func testSignedTransactionAddressRecovery() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)

        // Create a PrivateKeySigner with Anvil account 0 private key
        let privateKey = AnvilAccounts.privateKey0
        let signer = try PrivateKeySigner(hexPrivateKey: privateKey)

        print("Expected signer address: \(signer.address.value)")
        #expect(signer.address.value.lowercased() == AnvilAccounts.account0.lowercased())

        let client = EvmClient(transport: transport).withSigner(signer: signer)

        // Get current nonce to ensure we use the right one
        let nonce = try await client.getTransactionCount(address: signer.address, block: .pending)
        print("Current nonce: \(nonce)")

        // Prepare a simple transaction with explicit gas parameters
        let txParams = TransactionParams(
            from: signer.address.value,
            to: AnvilAccounts.account1,
            gas: "0x5208",  // 21000 in hex
            maxFeePerGas: "0x3B9ACA00",  // 1 gwei
            maxPriorityFeePerGas: "0x3B9ACA00",  // 1 gwei
            value: TransactionValue(wei: Wei(bigInt: BigInt(1000))),  // 1000 wei
            nonce: "0x" + String(nonce, radix: 16)  // Use actual nonce
        )

        // Sign the transaction (don't send it)
        let (signedTx, _) = try await client.signTransaction(params: txParams)
        print("Signed transaction: \(signedTx)")

        #expect(signedTx.hasPrefix("0x02"))  // EIP-1559 type 2 transaction

        // Broadcast the transaction and verify the from address
        let sendRequest = RpcRequest(
            method: "eth_sendRawTransaction",
            params: [AnyCodable(signedTx)]
        )
        let sendResponse = try await transport.send(request: sendRequest)

        // Get the transaction hash
        guard let txHash = sendResponse.result.value as? String else {
            throw TransactionError.invalidResponse("Expected transaction hash string")
        }

        print("Transaction broadcasted: \(txHash)")

        // Wait for transaction to be mined
        try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second

        // Get the transaction details to verify the from address
        let tx = try await client.getTransactionByHash(txHash)
        #expect(tx != nil)

        guard let from = tx?.from else {
            throw TransactionError.invalidResponse("Transaction 'from' field is missing")
        }

        print("Recovered from address: \(from)")
        print("Expected from address: \(signer.address.value)")

        // The critical test: the recovered 'from' address must match the signer's address
        #expect(
            from.lowercased() == signer.address.value.lowercased(),
            "Recovered address doesn't match signer address!")

        print("Address recovery test passed - signed transaction has correct from address!")
    }

    @Test("Sign and send transaction using PrivateKeySigner")
    func testPrivateKeySignerTransaction() async throws {
        let transport = try HttpTransport(urlString: Self.anvilUrl)

        let privateKey = AnvilAccounts.privateKey0
        let testSigner = try PrivateKeySigner(hexPrivateKey: privateKey)
        print("Using test address: \(testSigner.address.value)")

        let testClient = EvmClient(transport: transport).withSigner(signer: testSigner)

        // Verify the account has funds (Anvil accounts start with 10000 ETH)
        let balance = try await testClient.getBalance(address: testSigner.address, block: .latest)
        print("Test account balance: \(balance)")
        #expect(balance >= 1_000_000_000_000_000_000)

        let txParams = TransactionParams(
            from: testSigner.address.value,
            to: AnvilAccounts.account0,
            value: .wei(.init(hex: "0x2710"))
        )

        let pendingTx = try await testClient.signAndSendTransaction(params: txParams)
        print("Transaction from test account: \(pendingTx.txHash)")

        #expect(pendingTx.txHash.hasPrefix("0x"))

        // Wait and verify
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let receipt = try await testClient.getTransactionReceipt(pendingTx.txHash)
        #expect(receipt != nil)
        #expect(receipt?.isSuccessful == true)

        print("PrivateKeySigner transaction test completed successfully")
    }
}
