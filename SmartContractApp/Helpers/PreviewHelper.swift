//
//  PreviewHelper.swift
//  SmartContractApp
//
//  Created by Claude on 11/14/25.
//

import SwiftData
import SwiftUI

/// Helper for creating consistent SwiftUI previews with test data
@MainActor
struct PreviewHelper {
    /// Configuration for preview data
    struct Configuration {
        var endpoints: [Endpoint]
        var wallets: [EVMWallet]
        var contracts: [EVMContract]
        var abis: [EvmAbi]
        var currentWallet: EVMWallet?

        /// Default configuration with Anvil endpoint and test wallet
        static var `default`: Configuration {
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

            return Configuration(
                endpoints: [endpoint],
                wallets: [wallet],
                contracts: [],
                abis: [],
                currentWallet: wallet
            )
        }

        /// Empty configuration
        static var empty: Configuration {
            Configuration(endpoints: [], wallets: [], contracts: [], abis: [], currentWallet: nil)
        }
    }

    /// Environment container for preview
    struct Environment {
        let modelContainer: ModelContainer
        let walletSigner: WalletSignerViewModel
        let windowStateManager: WindowStateManager

        init(configuration: Configuration = .default) throws {
            // Create in-memory model container
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(
                for: Endpoint.self, EVMContract.self, EvmAbi.self, EVMWallet.self,
                configurations: config
            )

            // Insert data
            configuration.endpoints.forEach { container.mainContext.insert($0) }
            configuration.wallets.forEach { container.mainContext.insert($0) }
            configuration.contracts.forEach { container.mainContext.insert($0) }
            configuration.abis.forEach { container.mainContext.insert($0) }

            self.modelContainer = container
            self.walletSigner = WalletSignerViewModel(
                modelContext: container.mainContext,
                currentWallet: configuration.currentWallet
            )
            self.windowStateManager = WindowStateManager()
        }
    }

    /// Apply preview environment to a view
    static func wrap<Content: View>(
        configuration: Configuration = .default,
        @ViewBuilder content: () -> Content
    ) throws -> some View {
        let env = try Environment(configuration: configuration)
        return content()
            .modelContainer(env.modelContainer)
            .environment(env.walletSigner)
            .environment(env.windowStateManager)
    }
}
