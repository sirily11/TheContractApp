//
//  ContentView.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/5/25.
//

import SwiftData
import SwiftUI

enum AppTab: String, CaseIterable, Hashable, Identifiable {
    case configurations
    case run

    var id: String { rawValue }

    var title: String {
        switch self {
        case .configurations: return "Configurations"
        case .run: return "Run"
        }
    }

    var systemImage: String {
        switch self {
        case .configurations: return "gearshape.2"
        case .run: return "doc.text.fill"
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WalletSignerViewModel.self) private var walletSigner
    @Environment(WindowStateManager.self) private var windowStateManager
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    #endif
    @State private var selectedTab: AppTab = .configurations
    @State private var showingQueuedTransactions = false

    var body: some View {
        TabView(selection: $selectedTab) {
            ConfigurationsTabView()
                .tabItem {
                    Label(AppTab.configurations.title, systemImage: AppTab.configurations.systemImage)
                }
                .tag(AppTab.configurations)

            ContractTabView()
                .tabItem {
                    Label(AppTab.run.title, systemImage: AppTab.run.systemImage)
                }
                .tag(AppTab.run)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    #if os(macOS)
                    toggleSigningWalletWindow()
                    #else
                    showingQueuedTransactions = true
                    #endif
                } label: {
                    walletToolbarButton
                }
                .help("Pending Transactions")
            }
        }
        #if os(iOS)
        .sheet(isPresented: $showingQueuedTransactions) {
            NavigationStack {
                SigningWalletView()
            }
        }
        #endif
    }

    // MARK: - Actions

    #if os(macOS)
    private func toggleSigningWalletWindow() {
        if windowStateManager.isSigningWalletWindowOpen {
            dismissWindow(id: "signing-wallet")
        } else {
            openWindow(id: "signing-wallet")
        }
    }
    #endif

    // MARK: - Toolbar Button

    @ViewBuilder
    private var walletToolbarButton: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "wallet.pass")
                .font(.title3)
                .imageScale(.medium)

            if walletSigner.pendingTransactionCount > 0 {
                ZStack {
                    Circle()
                        .fill(.red)
                        .frame(width: 18, height: 18)

                    Text("\(min(walletSigner.pendingTransactionCount, 99))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .offset(x: 8, y: -8)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Endpoint.self, EVMContract.self, EvmAbi.self, EVMWallet.self], inMemory: true)
}
