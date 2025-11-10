//
//  ContractDetailView.swift
//  SmartContractApp
//
//  Created by Claude on 11/8/25.
//

import SwiftData
import SwiftUI

struct ContractDetailView: View {
    let contract: EVMContract
    @Environment(\.modelContext) private var modelContext
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingAbiPopover = false

    var body: some View {
        Form {
            // Header section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Text(contract.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        statusBadge
                    }

                    Text("Contract Details")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20))
            }

            // Contract Information
            Section("Contract Information") {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(contract.name)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Address")
                        Spacer()
                    }
                    Text(contract.address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .frame(maxWidth: .infinity)

                HStack {
                    Text("Status")
                    Spacer()
                    Text(contract.status.rawValue.capitalized)
                        .foregroundColor(statusColor)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity)
            }

            // ABI Information
            Section("ABI") {
                if let abi = contract.abi {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(abi.name)
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                        }

                        Button(action: {
                            showingAbiPopover = true
                        }) {
                            HStack {
                                Image(systemName: "doc.text.magnifyingglass")
                                Text("Show ABI Detail")
                            }
                        }
                        .buttonStyle(.borderless)
                    }
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("No ABI associated")
                            .foregroundColor(.secondary)
                            .italic()
                        Spacer()
                    }
                }
            }

            // Endpoint Information
            Section("Endpoint") {
                if let endpoint = contract.endpoint {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(endpoint.name)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("URL")
                            Spacer()
                        }
                        Text(endpoint.url)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .frame(maxWidth: .infinity)

                    HStack {
                        Text("Chain ID")
                        Spacer()
                        Text(endpoint.chainId)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("No endpoint associated")
                            .foregroundColor(.secondary)
                            .italic()
                        Spacer()
                    }
                }
            }

            // Timestamps
            Section("Timeline") {
                HStack {
                    Text("Created")
                    Spacer()
                    Text(contract.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                HStack {
                    Text("Last Updated")
                    Spacer()
                    Text(contract.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Contract")
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Edit") {
                        showingEditSheet = true
                    }

                    Divider()

                    Button("Delete", role: .destructive) {
                        showingDeleteAlert = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            ContractFormView(contract: contract)
        }
        .popover(isPresented: $showingAbiPopover) {
            if let abi = contract.abi {
                NavigationStack {
                    AbiDetailView(abi: abi, showConnectedContracts: false)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") {
                                    showingAbiPopover = false
                                }
                            }
                        }
                }
                .frame(minWidth: 600, minHeight: 500)
            }
        }
        .alert("Delete Contract", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteContract()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete '\(contract.name)'? This action cannot be undone.")
        }
    }

    private var statusBadge: some View {
        Text(contract.status.rawValue.capitalized)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(6)
    }

    private var statusColor: Color {
        switch contract.status {
        case .deployed:
            return .green
        case .pending:
            return .orange
        case .failed:
            return .red
        }
    }

    private func deleteContract() {
        withAnimation {
            modelContext.delete(contract)
            try? modelContext.save()
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: EVMContract.self, EvmAbi.self, Endpoint.self,
        configurations: config
    )

    let endpoint = Endpoint(name: "Mainnet", url: "https://eth.llamarpc.com", chainId: "1")
    let abi = EvmAbi(name: "ERC20", abiContent: """
        [
            {
                "type": "function",
                "name": "transfer",
                "inputs": [
                    {"name": "to", "type": "address"},
                    {"name": "amount", "type": "uint256"}
                ],
                "outputs": [{"name": "success", "type": "bool"}],
                "stateMutability": "nonpayable"
            }
        ]
        """)
    let contract = EVMContract(
        name: "USDC",
        address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        abiId: 1,
        status: .deployed,
        endpointId: 1
    )
    contract.abi = abi
    contract.endpoint = endpoint

    container.mainContext.insert(endpoint)
    container.mainContext.insert(abi)
    container.mainContext.insert(contract)

    return NavigationStack {
        ContractDetailView(contract: contract)
            .modelContainer(container)
    }
}
