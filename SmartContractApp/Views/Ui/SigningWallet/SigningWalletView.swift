//
//  SigningWalletView.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import SwiftUI
import SwiftData

/// Main wallet view with address, balance, actions, and tabs
struct SigningWalletView: View {

    // MARK: - Properties

    @State private var selectedTab: WalletTab = .pending
    @State private var showingSendSheet = false
    @State private var showingReceiveSheet = false
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

    private var balance: String {
        // TODO: Fetch actual balance from blockchain
        "0.0 \(nativeTokenSymbol)"
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

    private var numericBalance: String {
        // TODO: Fetch actual balance from blockchain
        "0.0"
    }

    // MARK: - Body

    var body: some View {
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
                balance: balance
            )
            .padding(.bottom, 20)

            // Action buttons (Send/Receive)
            WalletActionsView(
                showingSendSheet: $showingSendSheet,
                showingReceiveSheet: $showingReceiveSheet
            )
            .padding(.bottom, 16)

            // Tabs (Assets / Transaction History)
            tabView
        }
        .sheet(isPresented: $showingSendSheet) {
            sendSheet
        }
        .sheet(isPresented: $showingReceiveSheet) {
            receiveSheet
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
        .onChange(of: selectedEndpointId) { oldValue, newValue in
            // Sync with first available endpoint if selection is invalid
            if endpoints.first(where: { $0.id == newValue }) == nil,
               let firstEndpoint = endpoints.first {
                selectedEndpointId = firstEndpoint.id
            }
        }
    }

    private var tabView: some View {
        TabView(selection: $selectedTab) {
            AssetsView(
                nativeTokenSymbol: nativeTokenSymbol,
                nativeTokenName: nativeTokenName,
                balance: numericBalance
            )
            .tabItem {
                Label("Assets", systemImage: "dollarsign.circle")
            }
            .tag(WalletTab.assets)

            QueuedTransactionsView()
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

    private var sendSheet: some View {
        SendView(
            isPresented: $showingSendSheet,
            walletAddress: walletAddress,
            nativeTokenSymbol: nativeTokenSymbol,
            nativeTokenName: nativeTokenName,
            nativeTokenDecimals: nativeTokenDecimals,
            balance: numericBalance
        )
    }

    private var receiveSheet: some View {
        ReceiveView(
            isPresented: $showingReceiveSheet,
            walletAddress: walletAddress
        )
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
    let container = {
        let container = TransactionMockDataGenerator.createPopulatedPreviewContainer()
        let context = container.mainContext

        // Add queued transactions
        QueuedTransaction.allPending.forEach { tx in
            context.insert(tx)
        }

        return container
    }()

    SigningWalletView()
        .modelContainer(container)
}

#Preview("Assets Tab") {
    @Previewable @State var tab: WalletTab = .assets

    SigningWalletView()
        .modelContainer(TransactionMockDataGenerator.createPreviewContainer())
}
