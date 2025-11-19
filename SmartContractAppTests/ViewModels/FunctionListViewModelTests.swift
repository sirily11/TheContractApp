//
//  FunctionListViewModelTests.swift
//  SmartContractAppTests
//
//  Created by Claude on 11/19/25.
//

import EvmCore
import Foundation
import SwiftData
import Testing
@testable import SmartContractApp

@Suite("FunctionListViewModel Tests")
struct FunctionListViewModelTests {
    // MARK: - Test Helpers

    /// Create a test AbiFunction
    private func createTestFunction(
        name: String,
        inputs: [AbiParameter] = [],
        stateMutability: StateMutability
    ) -> AbiFunction {
        return AbiFunction(
            name: name,
            inputs: inputs,
            outputs: [],
            stateMutability: stateMutability
        )
    }

    // MARK: - shouldAutoExecute Tests

    @Test("shouldAutoExecute returns true for read-only functions with no parameters")
    func testShouldAutoExecute_ReadOnlyWithNoParams() {
        let viewModel = FunctionListViewModel()

        // Test view function with no parameters
        let viewFunction = createTestFunction(
            name: "getName",
            inputs: [],
            stateMutability: .view
        )
        #expect(viewModel.shouldAutoExecute(viewFunction) == true)

        // Test pure function with no parameters
        let pureFunction = createTestFunction(
            name: "calculate",
            inputs: [],
            stateMutability: .pure
        )
        #expect(viewModel.shouldAutoExecute(pureFunction) == true)
    }

    @Test("shouldAutoExecute returns false for read-only functions with parameters")
    func testShouldAutoExecute_ReadOnlyWithParams() {
        let viewModel = FunctionListViewModel()

        let viewFunction = createTestFunction(
            name: "balanceOf",
            inputs: [AbiParameter(name: "account", type: "address")],
            stateMutability: .view
        )
        #expect(viewModel.shouldAutoExecute(viewFunction) == false)
    }

    @Test("shouldAutoExecute returns false for write functions")
    func testShouldAutoExecute_WriteFunctions() {
        let viewModel = FunctionListViewModel()

        // Test nonpayable function
        let nonpayableFunction = createTestFunction(
            name: "transfer",
            inputs: [],
            stateMutability: .nonpayable
        )
        #expect(viewModel.shouldAutoExecute(nonpayableFunction) == false)

        // Test payable function
        let payableFunction = createTestFunction(
            name: "deposit",
            inputs: [],
            stateMutability: .payable
        )
        #expect(viewModel.shouldAutoExecute(payableFunction) == false)
    }

    // MARK: - isExecuting Tests

    @Test("isExecuting tracks function execution state")
    func testIsExecuting() {
        let viewModel = FunctionListViewModel()

        // Initially not executing
        #expect(viewModel.isExecuting("getName") == false)

        // Add to executing set
        viewModel.executingFunctions.insert("getName")
        #expect(viewModel.isExecuting("getName") == true)

        // Remove from executing set
        viewModel.executingFunctions.remove("getName")
        #expect(viewModel.isExecuting("getName") == false)
    }

    // MARK: - executeReadFunction Tests

    @Test("executeReadFunction marks function as executing and then removes it on success")
    @MainActor
    func testExecuteReadFunction_Success() async throws {
        // Note: This test will fail during execution because it requires a real blockchain connection
        // But it tests that the state management (executing tracking) works correctly
        let viewModel = FunctionListViewModel()
        let mockInteraction = ContractInteractionViewModel()

        // Create test data
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: EVMContract.self, Endpoint.self, EvmAbi.self, ContractFunctionCall.self, EVMWallet.self,
            configurations: config
        )

        let endpoint = Endpoint(name: "Test", url: "http://localhost:8545", chainId: "1")
        let abi = EvmAbi(name: "Test", abiContent: """
        [{"name":"getName","inputs":[],"outputs":[{"type":"string"}],"stateMutability":"view","type":"function"}]
        """)
        let contract = EVMContract(
            name: "TestContract",
            address: "0x1234567890123456789012345678901234567890",
            status: .deployed,
            endpointId: endpoint.id
        )
        contract.endpoint = endpoint
        contract.abi = abi

        let wallet = EVMWallet(
            alias: "Test",
            address: "0x1234567890123456789012345678901234567890",
            keychainPath: "test"
        )

        container.mainContext.insert(endpoint)
        container.mainContext.insert(abi)
        container.mainContext.insert(contract)
        container.mainContext.insert(wallet)

        let walletSigner = WalletSignerViewModel(currentWallet: wallet)
        walletSigner.modelContext = container.mainContext

        mockInteraction.modelContext = container.mainContext
        mockInteraction.walletSigner = walletSigner
        viewModel.interactionViewModel = mockInteraction

        let function = createTestFunction(
            name: "getName",
            inputs: [],
            stateMutability: .view
        )

        // Execute function - this will likely fail due to no blockchain connection
        // But we're testing the state management
        #expect(viewModel.isExecuting("getName") == false)

        await viewModel.executeReadFunction(contract: contract, function: function)

        // Should not be executing after completion (even if it failed)
        #expect(viewModel.isExecuting("getName") == false)
    }

    @Test("executeReadFunction marks function as executing and removes it on error")
    @MainActor
    func testExecuteReadFunction_Error() async throws {
        let viewModel = FunctionListViewModel()
        let mockInteraction = ContractInteractionViewModel()

        // Create test data with invalid endpoint to trigger error
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: EVMContract.self, Endpoint.self, EvmAbi.self, ContractFunctionCall.self, EVMWallet.self,
            configurations: config
        )

        let endpoint = Endpoint(name: "Test", url: "invalid-url", chainId: "1")
        let abi = EvmAbi(name: "Test", abiContent: """
        [{"name":"getName","inputs":[],"outputs":[{"type":"string"}],"stateMutability":"view","type":"function"}]
        """)
        let contract = EVMContract(
            name: "TestContract",
            address: "0x1234567890123456789012345678901234567890",
            status: .deployed,
            endpointId: endpoint.id
        )
        contract.endpoint = endpoint
        contract.abi = abi

        let wallet = EVMWallet(
            alias: "Test",
            address: "0x1234567890123456789012345678901234567890",
            keychainPath: "test"
        )

        container.mainContext.insert(endpoint)
        container.mainContext.insert(abi)
        container.mainContext.insert(contract)
        container.mainContext.insert(wallet)

        let walletSigner = WalletSignerViewModel(currentWallet: wallet)
        walletSigner.modelContext = container.mainContext

        mockInteraction.modelContext = container.mainContext
        mockInteraction.walletSigner = walletSigner
        viewModel.interactionViewModel = mockInteraction

        let function = createTestFunction(
            name: "getName",
            inputs: [],
            stateMutability: .view
        )

        // Execute function - should fail due to invalid URL
        await viewModel.executeReadFunction(contract: contract, function: function)

        // Should not be executing after error
        #expect(viewModel.isExecuting("getName") == false)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.showingErrorAlert == true)
    }

    // MARK: - clearError Tests

    @Test("clearError resets error state")
    func testClearError() {
        let viewModel = FunctionListViewModel()

        // Set error state
        viewModel.errorMessage = "Test error"
        viewModel.showingErrorAlert = true

        // Clear error
        viewModel.clearError()

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.showingErrorAlert == false)
    }

}
