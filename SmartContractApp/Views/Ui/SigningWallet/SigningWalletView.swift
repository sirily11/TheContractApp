//
//  SigningWalletView.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import BigInt
import Combine
import EvmCore
import SwiftData
import SwiftUI

/// Main wallet view with address, balance, actions, and tabs
struct SigningWalletView: View {
    // MARK: - Properties

    @Environment(WalletSignerViewModel.self) private var walletSigner
    @State private var navigationPath = NavigationPath()
    @State private var selectedTab: WalletTab = .pending
    @State private var showingEndpointPopover = false

    // MARK: - AppStorage for persistence

    @AppStorage("selectedEndpointId") private var selectedEndpointId: Int = 0
    @AppStorage("selectedWalletId") private var selectedWalletId: Int = 0

    // MARK: - SwiftData Queries

    @Query(sort: \Endpoint.name) private var endpoints: [Endpoint]
    @Query(sort: \EVMWallet.alias) private var wallets: [EVMWallet]

    // MARK: - Computed Properties

    private var selectedEndpoint: Endpoint? {
        endpoints.first { $0.id == selectedEndpointId } ?? endpoints.first
    }

    private var selectedWallet: EVMWallet? {
        wallets.first { $0.id == selectedWalletId } ?? wallets.first
    }

    private var walletAddress: String {
        selectedWallet?.address ?? "No wallet selected"
    }

    private var nativeTokenSymbol: String {
        selectedEndpoint?.nativeTokenSymbol ?? "ETH"
    }

    private var nativeTokenName: String {
        selectedEndpoint?.nativeTokenName ?? "Ethereum"
    }

    private var nativeTokenDecimals: Int {
        selectedEndpoint?.nativeTokenDecimals ?? 18
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Endpoint picker button (top right)
                HStack {
                    Spacer()
                    endpointPickerButton
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

                // Wallet header (address + balance) with wallet picker
                WalletHeaderView(
                    wallets: wallets,
                    selectedWalletId: $selectedWalletId,
                    endpoint: selectedEndpoint,
                    refreshInterval: 10.0 // Refresh balance every 10 seconds
                )
                .padding(.bottom, 20)

                // Action buttons (Send/Receive)
                WalletActionsView(
                    navigationPath: $navigationPath
                )
                .padding(.bottom, 16)

                // Tabs (Assets / Transaction History)
                tabView
            }
            .navigationDestination(for: QueuedTransaction.self) { transaction in
                SignTransactionView(transaction: transaction)
            }
            .navigationDestination(for: SendDestination.self) { _ in
                SendView(
                    wallet: selectedWallet,
                    endpoint: selectedEndpoint
                )
            }
            .navigationDestination(for: ReceiveDestination.self) { _ in
                ReceiveView(
                    walletAddress: walletAddress
                )
            }
            .navigationDestination(for: Transaction.self) { transaction in
                TransactionDetailView(transaction: transaction)
            }
            .task {
                await listenToTransactionEvents()
            }
        }
    }

    // MARK: - Helper Methods

    /// Listen to transaction events from the view model
    private func listenToTransactionEvents() async {
        for await event in walletSigner.transactionEventPublisher.values {
            print("Getting event: \(event)")
            await handleTransactionEvent(event)
        }
    }

    /// Handle transaction events
    @MainActor
    private func handleTransactionEvent(_ event: TransactionEvent) async {
        switch event {
        case .queued(let transaction):
            // When a transaction is queued, navigate to the signing view
            navigationPath.append(transaction)
        default:
            break
        }
    }

    // MARK: - Views

    private var endpointPickerButton: some View {
        Button(action: {
            showingEndpointPopover.toggle()
        }) {
            HStack(spacing: 6) {
                Image(systemName: "network")
                    .font(.system(size: 14))
                Text(selectedEndpoint?.name ?? "Select Network")
                    .font(.subheadline)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingEndpointPopover, arrowEdge: .top) {
            endpointPickerPopover
        }
    }

    private var endpointPickerPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Network")
                .font(.headline)
                .padding(.bottom, 4)

            if endpoints.isEmpty {
                Text("No endpoints available")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .padding()
            } else {
                ForEach(endpoints, id: \.id) { endpoint in
                    Button(action: {
                        selectedEndpointId = endpoint.id
                        showingEndpointPopover = false
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(endpoint.name)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Text("Chain ID: \(endpoint.chainId)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if endpoint.id == selectedEndpointId {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 14))
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            endpoint.id == selectedEndpointId
                                ? Color.blue.opacity(0.1)
                                : Color.clear
                        )
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .frame(minWidth: 250)
        .onChange(of: selectedEndpointId) { _, newValue in
            // Sync with first available endpoint if selection is invalid
            if endpoints.first(where: { $0.id == newValue }) == nil,
               let firstEndpoint = endpoints.first
            {
                selectedEndpointId = firstEndpoint.id
            }
        }
    }

    private var tabView: some View {
        TabView(selection: $selectedTab) {
            AssetsView(
                selectedWallet: selectedWallet,
                endpoint: selectedEndpoint,
                refreshInterval: 10.0 // Refresh balance every 10 seconds
            )
            .tabItem {
                Label("Assets", systemImage: "dollarsign.circle")
            }
            .tag(WalletTab.assets)

            QueuedTransactionsView(
                onSelectTransaction: { transaction in
                    navigationPath.append(transaction)
                }
            )
            .tabItem {
                Label("Pending", systemImage: "clock.fill")
            }
            .tag(WalletTab.pending)

            TransactionHistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .tag(WalletTab.history)
        }
        .frame(minHeight: 250)
    }
}

// MARK: - Wallet Tab Enum

enum WalletTab: String, CaseIterable {
    case assets = "Assets"
    case pending = "Pending"
    case history = "History"
}

// MARK: - Preview

#Preview("Main Wallet View") {
    SigningWalletView()
        .modelContainer(TransactionMockDataGenerator.createPopulatedPreviewContainer())
}

#Preview("With No Transactions") {
    SigningWalletView()
        .modelContainer(TransactionMockDataGenerator.createPreviewContainer())
}

#Preview("With Queued Transactions") {
    let container = TransactionMockDataGenerator.createPreviewContainer()
    let context = container.mainContext

    // Create a sample wallet
    let wallet = EVMWallet(
        id: 1,
        alias: "Test Wallet",
        address: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
        keychainPath: "preview/test_wallet"
    )
    context.insert(wallet)

    // Create endpoint
    let endpoint = Endpoint(
        id: 1,
        name: "Localhost",
        url: "http://127.0.0.1:8545",
        chainId: "31337"
    )
    context.insert(endpoint)

    let viewModel = WalletSignerViewModel(modelContext: context, currentWallet: wallet)

    // Queue sample transactions using the public API
    _ = try? viewModel.queueTransaction(
        to: "0x1234567890abcdef1234567890abcdef12345678",
        value: .ether(.init(bigInt: .init(integerLiteral: 1)))
    )
    _ = try? viewModel.queueTransaction(
        to: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        value: .wei(.init(bigInt: .init(integerLiteral: 1000000)))
    )
    return SigningWalletView()
        .modelContainer(container)
        .environment(viewModel)
}

#Preview("Assets Tab") {
    @Previewable @State var tab: WalletTab = .assets

    SigningWalletView()
        .modelContainer(TransactionMockDataGenerator.createPreviewContainer())
}

#Preview("Navigation Detail - Sign Transaction") {
    SigningWalletView()
        .modelContainer(TransactionMockDataGenerator.createPreviewContainer())
        .environment(
            WalletSignerViewModel(
                modelContext: TransactionMockDataGenerator.createPreviewContainer().mainContext
            )
        )
}
