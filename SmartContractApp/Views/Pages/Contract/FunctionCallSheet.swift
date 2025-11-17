//
//  FunctionCallSheet.swift
//  SmartContractApp
//
//  Created by Claude on 11/17/25.
//

import Combine
import EvmCore
import SwiftData
import SwiftUI

// MARK: - Navigation Destination

enum FunctionCallDestination: Hashable {
    case parameters
    case confirmation // For write functions only
    case processing
    case result
}

// MARK: - Function Call Sheet

/// Multi-page sheet for calling contract functions
/// Uses NavigationStack with navigation path similar to SolidityDeploymentSheet
struct FunctionCallSheet: View {
    let contract: EVMContract
    let function: AbiFunction

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Environment(WalletSignerViewModel.self) var walletSigner
    @Environment(ContractInteractionViewModel.self) var interactionViewModel
    @Environment(\.openWindow) var openWindow

    // MARK: - Navigation

    @State var navigationPath = NavigationPath()
    @State var currentDestination: FunctionCallDestination?

    // MARK: - State Properties

    @State var parameters: [TransactionParameter]
    @State var executionState: ExecutionState = .idle
    @State var result: String?
    @State var errorMessage: String?
    @State var transactionHash: String?
    @State var queuedTransaction: QueuedTransaction?

    // Value for payable functions
    @State var ethValue: String = "0"
    @State var selectedValueUnit: EthereumValueUnit = .ether

    // Cancellables for event subscription
    @State var cancellables = Set<AnyCancellable>()

    enum ExecutionState {
        case idle
        case executing
        case waitingForSignature
        case completed
        case failed
    }

    // MARK: - Initialization

    init(contract: EVMContract, function: AbiFunction) {
        self.contract = contract
        self.function = function

        // Initialize parameters from function inputs immediately
        self._parameters = State(initialValue: function.inputs.map { input in
            let solidityType = try? SolidityType(parsing: input.type)
            return TransactionParameter(
                name: input.name.isEmpty ? "(unnamed)" : input.name,
                type: solidityType ?? .string,
                value: .init("")
            )
        })
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            parametersPage
                .navigationDestination(for: FunctionCallDestination.self) { destination in
                    switch destination {
                    case .parameters:
                        parametersPage
                            .onAppear { currentDestination = .parameters }
                    case .confirmation:
                        confirmationPage
                            .onAppear { currentDestination = .confirmation }
                    case .processing:
                        processingPage
                            .onAppear { currentDestination = .processing }
                    case .result:
                        resultPage
                            .onAppear { currentDestination = .result }
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
                if let destination = currentDestination {
                    switch destination {
                    case .parameters:
                        Button("Cancel") {
                            dismiss()
                        }
                    case .confirmation:
                        Button("Back") {
                            navigationPath.removeLast()
                            currentDestination = .parameters
                        }
                    case .processing:
                        // No button during processing
                        EmptyView()
                    case .result:
                        Button("Done") {
                            dismiss()
                        }
                    }
                } else {
                    // First page
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }

            ToolbarItem(placement: .primaryAction) {
                if let destination = currentDestination {
                    switch destination {
                    case .parameters:
                        Button(isReadFunction ? "Call Function" : "Continue") {
                            handleCallFunction()
                        }
                        .disabled(!canCallFunction)
                    case .confirmation:
                        Button {
                            handleConfirmTransaction()
                        } label: {
                            Label("Sign & Send", systemImage: "signature")
                        }
                        .tint(.orange)
                    case .processing, .result:
                        EmptyView()
                    }
                } else {
                    // First page - parameters
                    Button(isReadFunction ? "Call Function" : "Continue") {
                        handleCallFunction()
                    }
                    .disabled(!canCallFunction)
                }
            }
        }
        .interactiveDismissDisabled(isProcessing)
    }

    // MARK: - Computed Properties

    var isProcessing: Bool {
        executionState == .executing || executionState == .waitingForSignature
    }

    var isReadFunction: Bool {
        function.stateMutability == .view || function.stateMutability == .pure
    }

    var isWriteFunction: Bool {
        function.stateMutability == .nonpayable || function.stateMutability == .payable
    }

    var isPayableFunction: Bool {
        function.stateMutability == .payable
    }

    var transactionValue: TransactionValue {
        (try? selectedValueUnit.toTransactionValue(from: ethValue)) ?? .ether(.init(bigInt: .zero))
    }
}

// MARK: - Preview

#Preview("Read Function") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: EVMContract.self, EvmAbi.self, Endpoint.self, EVMWallet.self,
        configurations: config
    )

    let endpoint = Endpoint(name: "Mainnet", url: "https://eth.llamarpc.com", chainId: "1")
    let contract = EVMContract(
        name: "USDC",
        address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        status: .deployed,
        endpointId: endpoint.id
    )
    contract.endpoint = endpoint

    let wallet = EVMWallet(alias: "Test Wallet", address: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb", keychainPath: "preview-wallet")

    container.mainContext.insert(endpoint)
    container.mainContext.insert(contract)
    container.mainContext.insert(wallet)

    let walletSignerViewModel = WalletSignerViewModel(currentWallet: wallet)
    walletSignerViewModel.modelContext = container.mainContext

    let contractInteractionViewModel = ContractInteractionViewModel()
    contractInteractionViewModel.modelContext = container.mainContext
    contractInteractionViewModel.walletSigner = walletSignerViewModel

    let function = AbiFunction(
        name: "balanceOf",
        inputs: [
            AbiParameter(name: "account", type: "address")
        ],
        outputs: [
            AbiParameter(name: "", type: "uint256")
        ],
        stateMutability: .view
    )

    return FunctionCallSheet(contract: contract, function: function)
        .modelContainer(container)
        .environment(walletSignerViewModel)
        .environment(contractInteractionViewModel)
}

#Preview("Write Function") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: EVMContract.self, EvmAbi.self, Endpoint.self, EVMWallet.self,
        configurations: config
    )

    let endpoint = Endpoint(name: "Mainnet", url: "https://eth.llamarpc.com", chainId: "1")
    let contract = EVMContract(
        name: "USDC",
        address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        status: .deployed,
        endpointId: endpoint.id
    )
    contract.endpoint = endpoint

    let wallet = EVMWallet(alias: "Test Wallet", address: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb", keychainPath: "preview-wallet")

    container.mainContext.insert(endpoint)
    container.mainContext.insert(contract)
    container.mainContext.insert(wallet)

    let walletSignerViewModel = WalletSignerViewModel(currentWallet: wallet)
    walletSignerViewModel.modelContext = container.mainContext

    let contractInteractionViewModel = ContractInteractionViewModel()
    contractInteractionViewModel.modelContext = container.mainContext
    contractInteractionViewModel.walletSigner = walletSignerViewModel

    let function = AbiFunction(
        name: "transfer",
        inputs: [
            AbiParameter(name: "recipient", type: "address"),
            AbiParameter(name: "amount", type: "uint256")
        ],
        outputs: [
            AbiParameter(name: "", type: "bool")
        ],
        stateMutability: .nonpayable
    )

    return FunctionCallSheet(contract: contract, function: function)
        .modelContainer(container)
        .environment(walletSignerViewModel)
        .environment(contractInteractionViewModel)
}
