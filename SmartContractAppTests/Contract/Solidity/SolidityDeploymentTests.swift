//
//  SolidityDeploymentTests.swift
//  SmartContractAppTests
//
//  Created by Qiwei Li on 11/13/25.
//

@testable import SmartContractApp
import SwiftData
import SwiftUI
import Testing
import ViewInspector

struct SolidityDeploymentTests {
    @Test @MainActor func testShowingCorrectCloseButton() async throws {
        // Create test wrapper with default configuration (includes Anvil endpoint and test wallet)
        let view = try SwiftUITestWrapper.withDefaults {
            SolidityDeploymentSheet(
                sourceCode: .constant(""),
                contractName: .constant("Test Contract")
            )
        }

        // Test the view can be inspected
        let navigationStack = try view.inspect().navigationStack()
        #expect(navigationStack != nil)
    }

    @Test @MainActor func testCustomConfiguration() async throws {
        // Example: Create custom configuration for more complex test scenarios
        let customEndpoint = Endpoint(
            name: "Sepolia Testnet",
            url: "https://sepolia.infura.io/v3/YOUR-PROJECT-ID",
            chainId: "11155111"
        )

        let customWallet = EVMWallet(
            alias: "Custom Wallet",
            address: "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
            keychainPath: "custom_wallet"
        )

        let customConfig = TestEnvironmentConfiguration(
            endpoints: [customEndpoint],
            wallets: [customWallet],
            currentWallet: customWallet
        )

        let view = try SwiftUITestWrapper(configuration: customConfig) {
            SolidityDeploymentSheet(
                sourceCode: .constant("pragma solidity ^0.8.0; contract Test {}"),
                contractName: .constant("Test")
            )
        }

        // Test with custom configuration
        let navigationStack = try view.inspect().navigationStack()
        #expect(navigationStack != nil)
    }
}
