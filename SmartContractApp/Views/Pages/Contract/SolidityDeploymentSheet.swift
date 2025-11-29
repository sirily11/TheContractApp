//
//  SolidityDeploymentSheet.swift
//  SmartContractApp
//
//  Created by Kiro on 11/12/25.
//

import Solidity
import SwiftData
import SwiftUI

// MARK: - Navigation Destination

enum DeploymentDestination: Hashable {
    case compilation
    case constructorParams
    case deployment
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
    @Binding var editorCompilationOutput: Output?

    // MARK: - Navigation

    @State var navigationPath = NavigationPath()
    @State var currentDestination: DeploymentDestination?

    // MARK: - State Properties

    @State var selectedEndpoint: Endpoint?
    @State var solidityContractName: String = ""
    @State var availableContractNames: [String] = []
    @State var compilationState: TaskState = .idle
    @State var deploymentState: TaskState = .idle
    @State var compiledBytecode: String?
    @State var compiledAbi: String?
    @State var deployedAddress: String?
    @State var constructorParameters: [TransactionParameter] = []
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
        let vm = ContractDeploymentViewModel()
        vm.modelContext = modelContext
        vm.walletSigner = signerViewModel
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
                            .onAppear { currentDestination = .compilation }
                    case .constructorParams:
                        constructorParamsPage
                            .onAppear { currentDestination = .constructorParams }
                    case .deployment:
                        deploymentProgressPage
                            .onAppear { currentDestination = .deployment }
                    case .success:
                        successPage
                            .onAppear { currentDestination = .success }
                    }
                }
                .onAppear {
                    if navigationPath.isEmpty {
                        currentDestination = nil
                    }
                }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                // Show different buttons based on current page
                if let destination = currentDestination {
                    switch destination {
                    case .compilation:
                        // Compilation page: Hide button when processing, show Back when failed
                        if case .failed = compilationState {
                            Button("Back") {
                                navigationPath.removeLast()
                                currentDestination = nil
                            }
                        } else if !isProcessing {
                            Button("Back") {
                                navigationPath.removeLast()
                                currentDestination = nil
                            }
                        }
                    case .constructorParams:
                        // Constructor params page: Show Back
                        Button("Back") {
                            navigationPath.removeLast()
                            currentDestination = .compilation
                        }
                    case .deployment:
                        // Deployment page: Hide button when processing, show Back when failed
                        if case .failed = deploymentState {
                            Button("Back") {
                                navigationPath.removeLast()
                                currentDestination = .constructorParams
                            }
                        } else if !isProcessing {
                            Button("Back") {
                                navigationPath.removeLast()
                                currentDestination = .constructorParams
                            }
                        }
                    case .success:
                        // Success page: Show Close
                        Button("Close") {
                            dismiss()
                        }
                        .accessibilityIdentifier(.deployment.closeButton)
                    }
                } else {
                    // First page: Show Cancel
                    Button("Cancel") {
                        dismiss()
                    }
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
    @Previewable @State var compilationOutput: Output? = nil

    // Use PreviewHelper for consistent test data setup
    try! PreviewHelper.wrap {
        SolidityDeploymentSheet(
            sourceCode: $sourceCode,
            contractName: $contractName,
            editorCompilationOutput: $compilationOutput
        )
    }
}
