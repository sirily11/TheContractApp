import BigInt
import Foundation
import Testing

@testable import EvmCore

/// E2E Tests for Uniswap contract write functions
/// Tests state-changing functions on WETH9 and UniswapV2Factory
/// and verifies state changes via read function calls
@Suite("Uniswap Write Function E2E Tests", .serialized)
struct UniswapWriteTests {

    // MARK: - Main Test

    @Test("Test WETH9 and Factory write functions")
    func testUniswapWriteFunctions() async throws {
        // Setup - use privateKey1 to avoid nonce conflicts with read tests (which use privateKey2)
        print("Setting up transport and signer...")
        let (evmSigner, signer) = try createTestSigner(privateKey: AnvilAccounts.privateKey1)

        // Deploy all Uniswap contracts
        let contracts = try await deployUniswapContracts(
            evmSigner: evmSigner,
            feeToSetter: signer.address.value
        )

        // Run write function tests
        try await testWeth9WriteFunctions(
            contract: contracts.weth9,
            routerAddress: contracts.router.address.value,
            signerAddress: signer.address.value
        )
        try await testFactoryWriteFunctions(
            contract: contracts.factory
        )

        print("\n✅ All Uniswap write function tests passed!")
    }

    // MARK: - WETH9 Write Function Tests

    private func testWeth9WriteFunctions(
        contract: any Contract,
        routerAddress: String,
        signerAddress: String
    ) async throws {
        print("\n=== Testing WETH9 Write Functions ===")

        // Test deposit() - payable function
        print("\n--- Testing deposit() ---")
        let depositTxHash = try await callWriteFunction(
            contract: contract,
            name: "deposit",
            args: [],
            value: oneEther
        )
        print("deposit() tx: \(depositTxHash)")

        // Verify balanceOf increased
        let balanceAfterDeposit = try await callReadFunction(
            contract: contract,
            name: "balanceOf",
            args: [AnyCodable(signerAddress)]
        ) as! BigInt
        print("balanceOf after deposit: \(balanceAfterDeposit)")
        #expect(balanceAfterDeposit == oneEther, "balanceOf should be 1 ETH after deposit")

        // Verify totalSupply increased
        let totalSupplyAfterDeposit = try await callReadFunction(
            contract: contract,
            name: "totalSupply"
        ) as! BigInt
        print("totalSupply after deposit: \(totalSupplyAfterDeposit)")
        #expect(totalSupplyAfterDeposit == oneEther, "totalSupply should be 1 ETH after deposit")

        // Test approve() - approve router to spend WETH
        print("\n--- Testing approve() ---")
        let maxUint256 = BigInt(2).power(256) - 1
        let approveTxHash = try await callWriteFunction(
            contract: contract,
            name: "approve",
            args: [AnyCodable(routerAddress), AnyCodable(maxUint256)]
        )
        print("approve() tx: \(approveTxHash)")

        // Verify allowance
        let allowanceAfterApprove = try await callReadFunction(
            contract: contract,
            name: "allowance",
            args: [AnyCodable(signerAddress), AnyCodable(routerAddress)]
        ) as! BigInt
        print("allowance after approve: \(allowanceAfterApprove)")
        #expect(allowanceAfterApprove == maxUint256, "allowance should be max uint256 after approve")

        // Test transfer() - transfer WETH to another address
        print("\n--- Testing transfer() ---")
        let recipient = AnvilAccounts.account2
        let transferAmount = halfEther
        let transferTxHash = try await callWriteFunction(
            contract: contract,
            name: "transfer",
            args: [AnyCodable(recipient), AnyCodable(transferAmount)]
        )
        print("transfer() tx: \(transferTxHash)")

        // Verify sender balance decreased
        let senderBalanceAfterTransfer = try await callReadFunction(
            contract: contract,
            name: "balanceOf",
            args: [AnyCodable(signerAddress)]
        ) as! BigInt
        print("sender balance after transfer: \(senderBalanceAfterTransfer)")
        #expect(
            senderBalanceAfterTransfer == oneEther - transferAmount,
            "sender balance should be 0.5 ETH after transfer"
        )

        // Verify recipient balance increased
        let recipientBalance = try await callReadFunction(
            contract: contract,
            name: "balanceOf",
            args: [AnyCodable(recipient)]
        ) as! BigInt
        print("recipient balance: \(recipientBalance)")
        #expect(recipientBalance == transferAmount, "recipient balance should be 0.5 ETH")

        // Test withdraw() - withdraw remaining WETH back to ETH
        print("\n--- Testing withdraw() ---")
        let withdrawAmount = halfEther
        let withdrawTxHash = try await callWriteFunction(
            contract: contract,
            name: "withdraw",
            args: [AnyCodable(withdrawAmount)]
        )
        print("withdraw() tx: \(withdrawTxHash)")

        // Verify balance decreased
        let balanceAfterWithdraw = try await callReadFunction(
            contract: contract,
            name: "balanceOf",
            args: [AnyCodable(signerAddress)]
        ) as! BigInt
        print("balance after withdraw: \(balanceAfterWithdraw)")
        #expect(balanceAfterWithdraw == BigInt(0), "balance should be 0 after withdrawing all")

        // Verify totalSupply decreased (only recipient's WETH remains)
        let totalSupplyAfterWithdraw = try await callReadFunction(
            contract: contract,
            name: "totalSupply"
        ) as! BigInt
        print("totalSupply after withdraw: \(totalSupplyAfterWithdraw)")
        #expect(
            totalSupplyAfterWithdraw == transferAmount,
            "totalSupply should be 0.5 ETH (recipient's balance)"
        )
    }

    // MARK: - Factory Write Function Tests

    private func testFactoryWriteFunctions(contract: any Contract) async throws {
        print("\n=== Testing UniswapV2Factory Write Functions ===")

        // Test setFeeTo() - set fee recipient
        print("\n--- Testing setFeeTo() ---")
        let newFeeTo = AnvilAccounts.account2
        let setFeeToTxHash = try await callWriteFunction(
            contract: contract,
            name: "setFeeTo",
            args: [AnyCodable(newFeeTo)]
        )
        print("setFeeTo() tx: \(setFeeToTxHash)")

        // Verify feeTo changed
        let feeToAfterSet = try await callReadFunction(
            contract: contract,
            name: "feeTo"
        ) as! String
        print("feeTo after setFeeTo: \(feeToAfterSet)")
        #expect(
            feeToAfterSet.lowercased() == newFeeTo.lowercased(),
            "feeTo should be set to new address"
        )

        // Test setFeeToSetter() - transfer fee setter role
        print("\n--- Testing setFeeToSetter() ---")
        let newFeeToSetter = AnvilAccounts.account2
        let setFeeToSetterTxHash = try await callWriteFunction(
            contract: contract,
            name: "setFeeToSetter",
            args: [AnyCodable(newFeeToSetter)]
        )
        print("setFeeToSetter() tx: \(setFeeToSetterTxHash)")

        // Verify feeToSetter changed
        let feeToSetterAfterSet = try await callReadFunction(
            contract: contract,
            name: "feeToSetter"
        ) as! String
        print("feeToSetter after setFeeToSetter: \(feeToSetterAfterSet)")
        #expect(
            feeToSetterAfterSet.lowercased() == newFeeToSetter.lowercased(),
            "feeToSetter should be transferred to new address"
        )
    }
}
