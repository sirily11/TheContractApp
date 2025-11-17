//
//  SwiftUITestWrapper.swift
//  SmartContractAppTests
//
//  Created by Claude on 11/14/25.
//

@testable import SmartContractApp
import SwiftData
import SwiftUI

// MARK: - Test Configuration

/// Configuration for setting up a SwiftUI test environment
/// Note: This mirrors `PreviewHelper.Configuration` from the main app
/// to maintain consistency between tests and previews
struct TestEnvironmentConfiguration {
    /// Sample endpoints to insert
    var endpoints: [Endpoint] = []

    /// Sample wallets to insert
    var wallets: [EVMWallet] = []

    /// Sample contracts to insert
    var contracts: [EVMContract] = []

    /// Sample ABIs to insert
    var abis: [EvmAbi] = []

    /// The wallet to use as current wallet (must be in wallets array)
    var currentWallet: EVMWallet?

    /// Creates a default test configuration with Anvil endpoint and test wallet
    static var `default`: TestEnvironmentConfiguration {
        let endpoint = Endpoint(
            name: "Anvil Local",
            url: "http://127.0.0.1:8545",
            chainId: "31337"
        )

        let wallet = EVMWallet(
            alias: "Test Wallet",
            address: "0x1234567890123456789012345678901234567890",
            keychainPath: "test_wallet"
        )

        return TestEnvironmentConfiguration(
            endpoints: [endpoint],
            wallets: [wallet],
            currentWallet: wallet
        )
    }

    /// Creates a minimal configuration with no pre-populated data
    static var empty: TestEnvironmentConfiguration {
        TestEnvironmentConfiguration()
    }

    /// Creates a configuration with custom data
    init(
        endpoints: [Endpoint] = [],
        wallets: [EVMWallet] = [],
        contracts: [EVMContract] = [],
        abis: [EvmAbi] = [],
        currentWallet: EVMWallet? = nil
    ) {
        self.endpoints = endpoints
        self.wallets = wallets
        self.contracts = contracts
        self.abis = abis
        self.currentWallet = currentWallet
    }
}

// MARK: - Test Wrapper View

/// A reusable wrapper view that provides all necessary environment objects for testing SwiftUI views
struct SwiftUITestWrapper<Content: View>: View {
    /// The configuration used to create this wrapper (exposed for testing)
    let configuration: TestEnvironmentConfiguration

    /// The content view being wrapped
    let content: Content

    // Environment objects created from configuration (exposed for testing)

    /// The in-memory model container with test data
    let modelContainer: ModelContainer

    /// The wallet signer view model
    let walletSigner: WalletSignerViewModel

    /// The window state manager
    let windowStateManager: WindowStateManager

    init(
        configuration: TestEnvironmentConfiguration = .default,
        @ViewBuilder content: () -> Content
    ) throws {
        self.configuration = configuration

        // Create in-memory model container
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Endpoint.self, EVMContract.self, EvmAbi.self, EVMWallet.self,
            configurations: config
        )
        self.modelContainer = container

        // Insert sample data
        for endpoint in configuration.endpoints {
            container.mainContext.insert(endpoint)
        }

        for wallet in configuration.wallets {
            container.mainContext.insert(wallet)
        }

        for contract in configuration.contracts {
            container.mainContext.insert(contract)
        }

        for abi in configuration.abis {
            container.mainContext.insert(abi)
        }

        // Create wallet signer view model
        let walletSigner = WalletSignerViewModel(currentWallet: configuration.currentWallet)
        walletSigner.modelContext = container.mainContext
        self.walletSigner = walletSigner

        // Create window state manager
        self.windowStateManager = WindowStateManager()

        // Create content
        self.content = content()
    }

    var body: some View {
        content
            .modelContainer(modelContainer)
            .environment(walletSigner)
            .environment(windowStateManager)
    }
}

// MARK: - Test Helper Extensions

extension SwiftUITestWrapper {
    /// Convenience initializer for testing with default configuration
    static func withDefaults(@ViewBuilder content: () -> Content) throws -> SwiftUITestWrapper<Content> {
        try SwiftUITestWrapper(configuration: .default, content: content)
    }

    /// Convenience initializer for testing with empty configuration
    static func withEmpty(@ViewBuilder content: () -> Content) throws -> SwiftUITestWrapper<Content> {
        try SwiftUITestWrapper(configuration: .empty, content: content)
    }
}

// MARK: - Preview Helper

/// Helper for creating consistent previews with the same test infrastructure
@MainActor
struct PreviewTestWrapper {
    /// Creates a preview configuration with sample data
    static func preview<Content: View>(
        configuration: TestEnvironmentConfiguration = .default,
        @ViewBuilder content: () -> Content
    ) throws -> some View {
        try SwiftUITestWrapper(configuration: configuration, content: content)
    }
}
