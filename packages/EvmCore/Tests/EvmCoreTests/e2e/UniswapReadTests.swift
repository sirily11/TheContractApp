import BigInt
import Foundation
import Testing

@testable import EvmCore

/// E2E Tests for Uniswap contract read functions
/// Tests deployment of WETH9, UniswapV2Factory, and UniswapV2Router02
/// and verifies all read functions can be called and decoded without error
@Suite("Uniswap Read Function E2E Tests", .serialized)
struct UniswapReadTests {

    // MARK: - Main Test

    @Test("Deploy Uniswap contracts and test all read functions")
    func testUniswapDeploymentAndReadFunctions() async throws {
        // Setup
        print("Setting up transport and signer...")
        let (evmSigner, signer) = try createTestSigner(privateKey: AnvilAccounts.privateKey2)

        // Deploy all Uniswap contracts
        print("\n=== Deploying Contracts ===")
        let contracts = try await deployUniswapContracts(
            evmSigner: evmSigner,
            feeToSetter: signer.address.value
        )

        // Run all read function tests
        try await testWeth9ReadFunctions(contract: contracts.weth9, signerAddress: signer.address.value)
        try await testFactoryReadFunctions(
            contract: contracts.factory,
            signerAddress: signer.address.value,
            weth9Address: contracts.weth9.address.value
        )
        try await testRouterReadFunctions(
            contract: contracts.router,
            weth9Address: contracts.weth9.address.value,
            factoryAddress: contracts.factory.address.value
        )

        print("\n✅ All Uniswap read function tests passed!")
    }

    // MARK: - WETH9 Read Function Tests

    private func testWeth9ReadFunctions(contract: any Contract, signerAddress: String) async throws {
        print("\n=== Testing WETH9 Read Functions ===")

        // name() -> string
        let wethName = try await callReadFunction(contract: contract, name: "name")
        print("WETH9.name() = \(wethName)")
        #expect((wethName as? String) == "Wrapped Ether", "name() should return 'Wrapped Ether'")

        // symbol() -> string
        let wethSymbol = try await callReadFunction(contract: contract, name: "symbol")
        print("WETH9.symbol() = \(wethSymbol)")
        #expect((wethSymbol as? String) == "WETH", "symbol() should return 'WETH'")

        // decimals() -> uint8
        let wethDecimals = try await callReadFunction(contract: contract, name: "decimals")
        print("WETH9.decimals() = \(wethDecimals)")
        if let decimals = wethDecimals as? BigInt {
            #expect(decimals == BigInt(18), "decimals() should return 18")
        } else if let decimals = wethDecimals as? UInt64 {
            #expect(decimals == 18, "decimals() should return 18")
        }

        // totalSupply() -> uint256
        let wethTotalSupply = try await callReadFunction(contract: contract, name: "totalSupply")
        print("WETH9.totalSupply() = \(wethTotalSupply)")
        if let supply = wethTotalSupply as? BigInt {
            #expect(supply == BigInt(0), "totalSupply() should return 0")
        }

        // balanceOf(address) -> uint256
        let wethBalance = try await callReadFunction(
            contract: contract,
            name: "balanceOf",
            args: [AnyCodable(signerAddress)]
        )
        print("WETH9.balanceOf(\(signerAddress)) = \(wethBalance)")
        if let balance = wethBalance as? BigInt {
            #expect(balance == BigInt(0), "balanceOf() should return 0")
        }

        // allowance(address, address) -> uint256
        let zeroAddress = "0x0000000000000000000000000000000000000000"
        let wethAllowance = try await callReadFunction(
            contract: contract,
            name: "allowance",
            args: [AnyCodable(signerAddress), AnyCodable(zeroAddress)]
        )
        print("WETH9.allowance(\(signerAddress), \(zeroAddress)) = \(wethAllowance)")
        if let allowance = wethAllowance as? BigInt {
            #expect(allowance == BigInt(0), "allowance() should return 0")
        }
    }

    // MARK: - Factory Read Function Tests

    private func testFactoryReadFunctions(
        contract: any Contract,
        signerAddress: String,
        weth9Address: String
    ) async throws {
        print("\n=== Testing UniswapV2Factory Read Functions ===")

        // feeToSetter() -> address
        let feeToSetter = try await callReadFunction(contract: contract, name: "feeToSetter")
        print("Factory.feeToSetter() = \(feeToSetter)")
        if let setter = feeToSetter as? String {
            #expect(
                setter.lowercased() == signerAddress.lowercased(),
                "feeToSetter() should return deployer address"
            )
        }

        // feeTo() -> address
        let feeTo = try await callReadFunction(contract: contract, name: "feeTo")
        print("Factory.feeTo() = \(feeTo)")
        // feeTo starts as zero address
        if let to = feeTo as? String {
            #expect(
                to.lowercased() == "0x0000000000000000000000000000000000000000",
                "feeTo() should return zero address"
            )
        }

        // allPairsLength() -> uint256
        let pairsLength = try await callReadFunction(contract: contract, name: "allPairsLength")
        print("Factory.allPairsLength() = \(pairsLength)")
        if let length = pairsLength as? BigInt {
            #expect(length == BigInt(0), "allPairsLength() should return 0")
        }

        // getPair(address, address) -> address
        let pair = try await callReadFunction(
            contract: contract,
            name: "getPair",
            args: [AnyCodable(weth9Address), AnyCodable(signerAddress)]
        )
        print("Factory.getPair(...) = \(pair)")
        if let pairAddress = pair as? String {
            #expect(
                pairAddress.lowercased() == "0x0000000000000000000000000000000000000000",
                "getPair() should return zero address for non-existent pair"
            )
        }

        // Note: allPairs(uint256) is skipped because it will revert with index out of bounds
    }

    // MARK: - Router Read Function Tests

    private func testRouterReadFunctions(
        contract: any Contract,
        weth9Address: String,
        factoryAddress: String
    ) async throws {
        print("\n=== Testing UniswapV2Router02 Read Functions ===")

        // WETH() -> address
        let routerWeth = try await callReadFunction(contract: contract, name: "WETH")
        print("Router.WETH() = \(routerWeth)")
        if let wethAddr = routerWeth as? String {
            #expect(
                wethAddr.lowercased() == weth9Address.lowercased(),
                "WETH() should return WETH9 address"
            )
        }

        // factory() -> address
        let routerFactory = try await callReadFunction(contract: contract, name: "factory")
        print("Router.factory() = \(routerFactory)")
        if let factoryAddr = routerFactory as? String {
            #expect(
                factoryAddr.lowercased() == factoryAddress.lowercased(),
                "factory() should return Factory address"
            )
        }

        // quote(uint256 amountA, uint256 reserveA, uint256 reserveB) -> uint256
        // This is a pure function: amountB = amountA * reserveB / reserveA
        // quote(1000, 1000, 2000) = 2000
        let quoteResult = try await callReadFunction(
            contract: contract,
            name: "quote",
            args: [AnyCodable(BigInt(1000)), AnyCodable(BigInt(1000)), AnyCodable(BigInt(2000))]
        )
        print("Router.quote(1000, 1000, 2000) = \(quoteResult)")
        if let quote = quoteResult as? BigInt {
            #expect(quote == BigInt(2000), "quote(1000, 1000, 2000) should return 2000")
        }

        // getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) -> uint256
        // Pure function with fee calculation
        let amountOut = try await callReadFunction(
            contract: contract,
            name: "getAmountOut",
            args: [AnyCodable(BigInt(1000)), AnyCodable(BigInt(10000)), AnyCodable(BigInt(20000))]
        )
        print("Router.getAmountOut(1000, 10000, 20000) = \(amountOut)")
        // Just verify it doesn't revert and returns a BigInt
        #expect(amountOut is BigInt, "getAmountOut() should return a BigInt")

        // getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) -> uint256
        // Pure function with fee calculation
        let amountIn = try await callReadFunction(
            contract: contract,
            name: "getAmountIn",
            args: [AnyCodable(BigInt(1000)), AnyCodable(BigInt(10000)), AnyCodable(BigInt(20000))]
        )
        print("Router.getAmountIn(1000, 10000, 20000) = \(amountIn)")
        // Just verify it doesn't revert and returns a BigInt
        #expect(amountIn is BigInt, "getAmountIn() should return a BigInt")

        // Note: getAmountsIn and getAmountsOut are skipped because they require existing pairs
    }
}
