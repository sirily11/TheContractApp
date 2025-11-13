//
//  SolidityDeploymentSheet.swift
//  SmartContractApp
//
//  Created by Kiro on 11/12/25.
//

import SwiftData
import SwiftUI

// MARK: - Navigation Destination

enum DeploymentDestination: Hashable {
    case compilation
    case success
}

struct SolidityDeploymentSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Environment(WalletSignerViewModel.self) var signerViewModel
    @Environment(WindowStateManager.self) var windowStateManager
    #if os(macOS)
    @Environment(\.openWindow) var openWindow
    #endif

    // MARK: - Bindings

    @Binding var sourceCode: String
    @Binding var contractName: String

    // MARK: - Navigation

    @State var navigationPath = NavigationPath()

    // MARK: - State Properties

    @State var selectedEndpoint: Endpoint?
    @State var solidityContractName: String = ""
    @State var availableContractNames: [String] = []
    @State var compilationState: TaskState = .idle
    @State var deploymentState: TaskState = .idle
    @State var compiledBytecode: String?
    @State var compiledAbi: String?
    @State var deployedAddress: String?
    @State var showingValidationAlert = false
    @State var validationMessage = ""

    // MARK: - Transaction Queue State

    @State var queuedTransactionId: UUID?
    @State var compilationResults: (bytecode: String, abi: String)?

    // MARK: - Version Management

    @AppStorage("selectedSolidityVersion") var selectedVersion: String = "0.8.21"
    @State var versionManager = SolidityVersionManager.shared

    // MARK: - Query for Endpoints

    @Query(sort: \Endpoint.name) var endpoints: [Endpoint]

    // MARK: - Dependencies

    @State private var _viewModel: ContractDeploymentViewModel?
    var onDeploy: ((EVMContract) -> Void)?

    /// Computed property that lazily creates ContractDeploymentViewModel using the environment's WalletSignerViewModel
    var viewModel: ContractDeploymentViewModel {
        if let vm = _viewModel {
            return vm
        }
        let vm = ContractDeploymentViewModel(modelContext: modelContext, walletSigner: signerViewModel)
        _viewModel = vm
        return vm
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $navigationPath) {
            formReviewPage
                .navigationDestination(for: DeploymentDestination.self) { destination in
                    switch destination {
                    case .compilation:
                        compilationProgressPage
                    case .success:
                        successPage
                    }
                }
        }
        .frame(minWidth: 600)
        .interactiveDismissDisabled(isProcessing || queuedTransactionId != nil)
        .task {
            await subscribeToTransactionEvents()
        }
        .alert("Validation Error", isPresented: $showingValidationAlert) {
            Button("OK") {}
        } message: {
            Text(validationMessage)
        }
    }
}

// MARK: - Preview

#Preview("Deployment Sheet") {
    @Previewable @State var sourceCode = """
    // SPDX-License-Identifier: MIT
    pragma solidity ^0.8.0;

    contract SimpleStorage {
        uint256 public value;

        function setValue(uint256 _value) public {
            value = _value;
        }
    }
    """

    @Previewable @State var contractName = "SimpleStorage"

    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Endpoint.self, EVMContract.self, EvmAbi.self,
        configurations: config
    )

    // Add sample endpoint
    let endpoint = Endpoint(
        name: "Anvil Local",
        url: "http://127.0.0.1:8545",
        chainId: "31337"
    )
    container.mainContext.insert(endpoint)

    // Create mock wallet signer
    let mockWallet = EVMWallet(
        alias: "Test Wallet",
        address: "0x1234567890123456789012345678901234567890",
        keychainPath: "test_wallet"
    )
    container.mainContext.insert(mockWallet)

    let walletSigner = WalletSignerViewModel(
        modelContext: container.mainContext,
        currentWallet: mockWallet
    )

    return SolidityDeploymentSheet(
        sourceCode: $sourceCode,
        contractName: $contractName
    )
    .modelContainer(container)
    .environment(walletSigner)
}
