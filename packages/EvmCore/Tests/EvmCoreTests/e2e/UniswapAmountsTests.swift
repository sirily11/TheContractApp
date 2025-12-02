import BigInt
import Foundation
import Testing

@testable import EvmCore
@testable import Solidity

/// E2E Tests for Uniswap getAmountsIn and getAmountsOut functions
/// These tests require liquidity pairs to be created and funded
@Suite("Uniswap Amounts Function E2E Tests", .serialized)
struct UniswapAmountsTests {

    // MARK: - Test Token Source

    /// Minimal ERC20 token for testing liquidity operations
    static let testTokenSource = """
        // SPDX-License-Identifier: MIT
        pragma solidity ^0.8.0;

        contract TestToken {
            string public name = "Test Token";
            string public symbol = "TEST";
            uint8 public constant decimals = 18;
            uint256 public totalSupply;
            mapping(address => uint256) public balanceOf;
            mapping(address => mapping(address => uint256)) public allowance;

            function mint(address to, uint256 amount) public {
                totalSupply += amount;
                balanceOf[to] += amount;
            }

            function approve(address spender, uint256 amount) public returns (bool) {
                allowance[msg.sender][spender] = amount;
                return true;
            }

            function transfer(address to, uint256 amount) public returns (bool) {
                require(balanceOf[msg.sender] >= amount, "Insufficient balance");
                balanceOf[msg.sender] -= amount;
                balanceOf[to] += amount;
                return true;
            }

            function transferFrom(address from, address to, uint256 amount) public returns (bool) {
                require(balanceOf[from] >= amount, "Insufficient balance");
                require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
                balanceOf[from] -= amount;
                balanceOf[to] += amount;
                allowance[from][msg.sender] -= amount;
                return true;
            }
        }
        """

    // MARK: - Constants

    /// 10 ETH in wei for WETH liquidity
    static let tenEther = BigInt(10) * BigInt(10).power(18)

    /// 1000 tokens in wei (with 18 decimals) for TEST liquidity
    static let thousandTokens = BigInt(1000) * BigInt(10).power(18)

    /// Max uint256 for approvals
    static let maxUint256 = BigInt(2).power(256) - 1

    // MARK: - Main Test

    @Test("Test getAmountsIn and getAmountsOut with liquidity pair")
    func testGetAmountsInAndOut() async throws {
        // Setup - use privateKey0 to avoid nonce conflicts with other tests
        print("Setting up transport and signer...")
        let (evmSigner, signer) = try createTestSigner(privateKey: AnvilAccounts.privateKey0)

        // Deploy Uniswap contracts
        print("\n=== Deploying Uniswap Contracts ===")
        let contracts = try await deployUniswapContracts(
            evmSigner: evmSigner,
            feeToSetter: signer.address.value
        )

        // Deploy test token
        print("\n=== Deploying Test Token ===")
        let testToken = try await deployTestToken(evmSigner: evmSigner)
        print("TestToken deployed at: \(testToken.address.value)")

        // Setup liquidity
        try await setupLiquidity(
            weth9: contracts.weth9,
            testToken: testToken,
            router: contracts.router,
            factory: contracts.factory,
            signerAddress: signer.address.value
        )

        // Test getAmountOut (pure function with reserves)
        try await testGetAmountOut(router: contracts.router)

        // Test getAmountIn (pure function with reserves)
        try await testGetAmountIn(router: contracts.router)

        // Test getAmountsOut (uses path array)
        try await testGetAmountsOut(
            router: contracts.router,
            weth9Address: contracts.weth9.address.value,
            testTokenAddress: testToken.address.value
        )

        // Test getAmountsIn (uses path array)
        try await testGetAmountsIn(
            router: contracts.router,
            weth9Address: contracts.weth9.address.value,
            testTokenAddress: testToken.address.value
        )

        print("\n✅ All amount calculation tests passed!")
    }

    // MARK: - Pure Function Tests (No Liquidity Required)

    @Test("Test getAmountOut pure function with reserve values")
    func testGetAmountOutPure() async throws {
        print("Setting up transport and signer...")
        let (evmSigner, signer) = try createTestSigner(privateKey: AnvilAccounts.privateKey1)

        // Deploy only the router (need factory and WETH for constructor)
        let contracts = try await deployUniswapContracts(
            evmSigner: evmSigner,
            feeToSetter: signer.address.value
        )

        try await testGetAmountOut(router: contracts.router)
        print("\n✅ getAmountOut pure function test passed!")
    }

    @Test("Test getAmountIn pure function with reserve values")
    func testGetAmountInPure() async throws {
        print("Setting up transport and signer...")
        let (evmSigner, signer) = try createTestSigner(privateKey: AnvilAccounts.privateKey2)

        // Deploy only the router (need factory and WETH for constructor)
        let contracts = try await deployUniswapContracts(
            evmSigner: evmSigner,
            feeToSetter: signer.address.value
        )

        try await testGetAmountIn(router: contracts.router)
        print("\n✅ getAmountIn pure function test passed!")
    }

    // MARK: - Test Token Deployment

    /// Deploy the test ERC20 token using inline Solidity compilation
    private func deployTestToken(evmSigner: EvmClientWithSigner) async throws -> any EvmCore.Contract {
        print("Compiling TestToken...")
        let compiler = try await Solc.create(version: "0.8.21")

        let input = Input(
            language: "Solidity",
            sources: [
                "TestToken.sol": SourceIn(content: Self.testTokenSource)
            ],
            settings: Settings(
                optimizer: Optimizer(enabled: true, runs: 200),
                outputSelection: [
                    "*": [
                        "*": ["abi", "evm.bytecode.object"]
                    ]
                ]
            )
        )

        let output = try await compiler.compile(input, options: nil)

        // Check for compilation errors
        if let errors = output.errors {
            let errorMessages = errors.filter { $0.severity == "error" }
            if !errorMessages.isEmpty {
                throw UniswapTestError.unexpectedValue(
                    "Compilation failed: \(errorMessages.map { $0.formattedMessage ?? "Unknown error" }.joined(separator: "\n"))"
                )
            }
        }

        guard let contractData = output.contracts?["TestToken.sol"]?["TestToken"],
            let bytecodeHex = contractData.evm?.bytecode?.object,
            let abiArray = contractData.abi
        else {
            throw UniswapTestError.unexpectedValue("Failed to extract TestToken contract data")
        }

        print("Compilation successful!")

        // Parse ABI
        let abiJsonData = try JSONEncoder().encode(abiArray)
        let abiJsonString = String(data: abiJsonData, encoding: .utf8)!
        let abiParser = try AbiParser(fromJsonString: abiJsonString)

        // Deploy
        let deployableContract = DeployableEvmContract(
            bytecode: bytecodeHex,
            abi: abiParser.items,
            evmSigner: evmSigner
        )

        let (contract, _) = try await deployableContract.deploy(
            constructorArgs: [],
            importCallback: nil,
            value: TransactionValue(wei: Wei(bigInt: BigInt(0))),
            gasLimit: GasLimit(bigInt: BigInt(3_000_000)),
            gasPrice: nil as Gwei?
        )

        return contract
    }

    // MARK: - Liquidity Setup

    /// Setup liquidity pair between WETH and TestToken
    private func setupLiquidity(
        weth9: any EvmCore.Contract,
        testToken: any EvmCore.Contract,
        router: any EvmCore.Contract,
        factory: any EvmCore.Contract,
        signerAddress: String
    ) async throws {
        print("\n=== Setting Up Liquidity ===")

        // 1. Deposit ETH to get WETH
        print("\n--- Depositing ETH for WETH ---")
        let depositTxHash = try await callWriteFunction(
            contract: weth9,
            name: "deposit",
            args: [],
            value: Self.tenEther,
            gasLimit: BigInt(100_000)
        )
        print("deposit() tx: \(depositTxHash)")

        // Verify WETH balance
        let wethBalance = try await callReadFunction(
            contract: weth9,
            name: "balanceOf",
            args: [AnyCodable(signerAddress)]
        ) as! BigInt
        print("WETH balance: \(wethBalance)")
        #expect(wethBalance == Self.tenEther, "WETH balance should be 10 ETH")

        // 2. Mint test tokens
        print("\n--- Minting Test Tokens ---")
        let mintTxHash = try await callWriteFunction(
            contract: testToken,
            name: "mint",
            args: [AnyCodable(signerAddress), AnyCodable(Self.thousandTokens)],
            gasLimit: BigInt(100_000)
        )
        print("mint() tx: \(mintTxHash)")

        // Verify TEST balance
        let testBalance = try await callReadFunction(
            contract: testToken,
            name: "balanceOf",
            args: [AnyCodable(signerAddress)]
        ) as! BigInt
        print("TEST balance: \(testBalance)")
        #expect(testBalance == Self.thousandTokens, "TEST balance should be 1000 tokens")

        // 3. Approve router for WETH
        print("\n--- Approving Router for WETH ---")
        let approveWethTxHash = try await callWriteFunction(
            contract: weth9,
            name: "approve",
            args: [AnyCodable(router.address.value), AnyCodable(Self.maxUint256)],
            gasLimit: BigInt(100_000)
        )
        print("WETH approve() tx: \(approveWethTxHash)")

        // 4. Approve router for TEST
        print("\n--- Approving Router for TEST ---")
        let approveTestTxHash = try await callWriteFunction(
            contract: testToken,
            name: "approve",
            args: [AnyCodable(router.address.value), AnyCodable(Self.maxUint256)],
            gasLimit: BigInt(100_000)
        )
        print("TEST approve() tx: \(approveTestTxHash)")

        // 5. Add liquidity
        print("\n--- Adding Liquidity ---")
        // addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin, to, deadline)
        let deadline = BigInt(Date().timeIntervalSince1970 + 3600)  // 1 hour from now
        let addLiquidityTxHash = try await callWriteFunction(
            contract: router,
            name: "addLiquidity",
            args: [
                AnyCodable(weth9.address.value),
                AnyCodable(testToken.address.value),
                AnyCodable(Self.tenEther),  // amountADesired (10 WETH)
                AnyCodable(Self.thousandTokens),  // amountBDesired (1000 TEST)
                AnyCodable(Self.tenEther),  // amountAMin
                AnyCodable(Self.thousandTokens),  // amountBMin
                AnyCodable(signerAddress),  // to
                AnyCodable(deadline),  // deadline
            ],
            gasLimit: BigInt(3_000_000)
        )
        print("addLiquidity() tx: \(addLiquidityTxHash)")

        // 6. Verify pair was created
        print("\n--- Verifying Pair Creation ---")
        let pairAddress = try await callReadFunction(
            contract: factory,
            name: "getPair",
            args: [AnyCodable(weth9.address.value), AnyCodable(testToken.address.value)]
        ) as! String
        print("Pair address: \(pairAddress)")
        #expect(
            pairAddress.lowercased() != "0x0000000000000000000000000000000000000000",
            "Pair should be created (non-zero address)"
        )

        // Verify allPairsLength increased
        let pairsLength = try await callReadFunction(
            contract: factory,
            name: "allPairsLength"
        ) as! BigInt
        print("allPairsLength: \(pairsLength)")
        #expect(pairsLength == BigInt(1), "Should have 1 pair created")

        print("\n✅ Liquidity setup complete!")
    }

    // MARK: - getAmountOut Test (Pure Function)

    /// Test getAmountOut pure function with reserve values
    /// getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) -> uint256
    
    private func testGetAmountOut(router: any EvmCore.Contract) async throws {
        print("\n=== Testing getAmountOut (pure function) ===")

        // Test with known reserve values
        // Formula: amountOut = (amountIn * 997 * reserveOut) / (reserveIn * 1000 + amountIn * 997)
        let amountIn = BigInt(1000)
        let reserveIn = BigInt(10000)
        let reserveOut = BigInt(20000)

        print("amountIn: \(amountIn)")
        print("reserveIn: \(reserveIn)")
        print("reserveOut: \(reserveOut)")

        let result = try await callReadFunction(
            contract: router,
            name: "getAmountOut",
            args: [AnyCodable(amountIn), AnyCodable(reserveIn), AnyCodable(reserveOut)]
        )

        let amountOut = result as! BigInt
        print("amountOut: \(amountOut)")

        // Calculate expected: (1000 * 997 * 20000) / (10000 * 1000 + 1000 * 997)
        // = 19940000000 / 10997000 = 1814 (approximately)
        #expect(amountOut > BigInt(0), "amountOut should be > 0")
        #expect(amountOut < amountIn * reserveOut / reserveIn, "amountOut should be less than perfect ratio due to 0.3% fee")
        #expect(amountOut > BigInt(1800), "amountOut should be around 1814")
        #expect(amountOut < BigInt(1850), "amountOut should be around 1814")

        print("✅ getAmountOut test passed!")
    }

    // MARK: - getAmountIn Test (Pure Function)

    /// Test getAmountIn pure function with reserve values
    /// getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) -> uint256
    private func testGetAmountIn(router: any EvmCore.Contract) async throws {
        print("\n=== Testing getAmountIn (pure function) ===")

        // Test with known reserve values
        // Formula: amountIn = (reserveIn * amountOut * 1000) / ((reserveOut - amountOut) * 997) + 1
        let amountOut = BigInt(1000)
        let reserveIn = BigInt(10000)
        let reserveOut = BigInt(20000)

        print("amountOut: \(amountOut)")
        print("reserveIn: \(reserveIn)")
        print("reserveOut: \(reserveOut)")

        let result = try await callReadFunction(
            contract: router,
            name: "getAmountIn",
            args: [AnyCodable(amountOut), AnyCodable(reserveIn), AnyCodable(reserveOut)]
        )

        let amountIn = result as! BigInt
        print("amountIn: \(amountIn)")

        // Calculate expected: (10000 * 1000 * 1000) / ((20000 - 1000) * 997) + 1
        // = 10000000000 / 18943000 + 1 = 528 + 1 = 529 (approximately)
        #expect(amountIn > BigInt(0), "amountIn should be > 0")
        #expect(amountIn > amountOut * reserveIn / reserveOut, "amountIn should be more than perfect ratio due to 0.3% fee")
        #expect(amountIn > BigInt(520), "amountIn should be around 529")
        #expect(amountIn < BigInt(550), "amountIn should be around 529")

        print("✅ getAmountIn test passed!")
    }

    // MARK: - getAmountsOut Test

    /// Test getAmountsOut function with the WETH/TEST pair
    private func testGetAmountsOut(
        router: any EvmCore.Contract,
        weth9Address: String,
        testTokenAddress: String
    ) async throws {
        print("\n=== Testing getAmountsOut ===")

        // Path: WETH -> TEST
        let path = [weth9Address, testTokenAddress]
        let amountIn = oneEther  // 1 WETH

        print("Input: \(amountIn) wei (1 WETH)")
        print("Path: WETH -> TEST")

        // Call getAmountsOut
        let result = try await callReadFunction(
            contract: router,
            name: "getAmountsOut",
            args: [AnyCodable(amountIn), AnyCodable(path)]
        )

        // Parse result - should be array of BigInt
        guard let amounts = result as? [Any], amounts.count == 2 else {
            throw UniswapTestError.unexpectedValue(
                "getAmountsOut should return array with 2 elements, got: \(result)"
            )
        }

        let amountInResult = amounts[0] as! BigInt
        let amountOutResult = amounts[1] as! BigInt

        print("amounts[0] (input): \(amountInResult)")
        print("amounts[1] (output): \(amountOutResult)")

        // Calculate expected output for context
        // With 10 WETH : 1000 TEST liquidity, 1 WETH should give ~100 TEST minus 0.3% fee
        let expectedApproximate = BigInt(100) * oneEther  // Perfect ratio would be 100 TEST

        // Assertions
        #expect(amountInResult == amountIn, "First amount should equal input")
        #expect(amountOutResult > BigInt(0), "Output should be > 0")
        #expect(
            amountOutResult < expectedApproximate,
            "Output should be less than perfect ratio due to fees"
        )
        // With Uniswap's constant product formula and 0.3% fee, output should be around 90-99 tokens
        #expect(
            amountOutResult > BigInt(90) * oneEther,
            "Output should be reasonable (> 90 TEST tokens)"
        )

        print("✅ getAmountsOut test passed!")
    }

    // MARK: - getAmountsIn Test

    /// Test getAmountsIn function with the WETH/TEST pair
    private func testGetAmountsIn(
        router: any EvmCore.Contract,
        weth9Address: String,
        testTokenAddress: String
    ) async throws {
        print("\n=== Testing getAmountsIn ===")

        // Path: WETH -> TEST
        let path = [weth9Address, testTokenAddress]
        let amountOut = BigInt(50) * oneEther  // Want 50 TEST tokens

        print("Desired output: \(amountOut) wei (50 TEST tokens)")
        print("Path: WETH -> TEST")

        // Call getAmountsIn
        let result = try await callReadFunction(
            contract: router,
            name: "getAmountsIn",
            args: [AnyCodable(amountOut), AnyCodable(path)]
        )

        // Parse result - should be array of BigInt
        guard let amounts = result as? [Any], amounts.count == 2 else {
            throw UniswapTestError.unexpectedValue(
                "getAmountsIn should return array with 2 elements, got: \(result)"
            )
        }

        let amountInRequired = amounts[0] as! BigInt
        let amountOutResult = amounts[1] as! BigInt

        print("amounts[0] (required input): \(amountInRequired)")
        print("amounts[1] (output): \(amountOutResult)")

        // With 10 WETH : 1000 TEST liquidity, to get 50 TEST should need ~0.5 WETH plus fees
        // Perfect ratio: 50 TEST / 100 (ratio) = 0.5 WETH

        // Assertions
        #expect(amountOutResult == amountOut, "Last amount should equal requested output")
        #expect(amountInRequired > BigInt(0), "Required input should be > 0")
        #expect(
            amountInRequired > halfEther,
            "Required input should be > 0.5 WETH (includes fees)"
        )
        #expect(
            amountInRequired < oneEther,
            "Required input should be < 1 WETH (reasonable range)"
        )

        print("✅ getAmountsIn test passed!")
    }
}
