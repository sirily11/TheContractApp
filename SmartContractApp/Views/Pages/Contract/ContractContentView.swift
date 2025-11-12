//
//  ContractContentView.swift
//  SmartContractApp
//
//  Created by Claude on 11/8/25.
//

import SwiftData
import SwiftUI

struct ContractContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EVMContract.createdAt, order: .reverse) private var contracts: [EVMContract]
    @Binding var selectedContract: EVMContract?

    @State private var showingCreateSheet = false
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var contractToDelete: EVMContract?

    var body: some View {
        List(contracts, selection: $selectedContract) { contract in
            NavigationLink(value: contract) {
                ContractRowView(contract: contract)
            }
            .contextMenu {
                Button("Edit") {
                    selectedContract = contract
                    showingEditSheet = true
                }

                Divider()

                Button("Delete", role: .destructive) {
                    contractToDelete = contract
                    showingDeleteAlert = true
                }
            }
        }
        .navigationTitle("Contracts")
        .navigationSplitViewColumnWidth(min: 300, ideal: 350)
        .toolbar {
            #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    contractCreationMenu
                }
            #else
                ToolbarItem(placement: .primaryAction) {
                    contractCreationMenu
                }
            #endif
        }
        .sheet(isPresented: $showingCreateSheet) {
            NavigationStack {
                ContractFormView()
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            if let contract = selectedContract {
                NavigationStack {
                    ContractFormView(contract: contract)
                }
            } else {
                Text("No contract selected")
            }
        }
        .alert("Delete Contract", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let contract = contractToDelete {
                    deleteContract(contract)
                }
            }
            Button("Cancel", role: .cancel) {
                contractToDelete = nil
            }
        } message: {
            if let contract = contractToDelete {
                Text(
                    "Are you sure you want to delete '\(contract.name)'? This action cannot be undone."
                )
            }
        }
    }

    private var contractCreationMenu: some View {
        Menu {
            Button(action: {
                showingCreateSheet = true
            }) {
                Label("Create New Contract", systemImage: "plus.square")
            }
        } label: {
            Image(systemName: "plus")
        }
    }

    private func deleteContract(_ contract: EVMContract) {
        withAnimation {
            modelContext.delete(contract)
            try? modelContext.save()
        }
        contractToDelete = nil

        // Clear selection if deleted contract was selected
        if selectedContract == contract {
            selectedContract = nil
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: EVMContract.self, EvmAbi.self, Endpoint.self,
        configurations: config
    )

    // Add sample data
    let endpoint = Endpoint(name: "Mainnet", url: "https://eth.llamarpc.com", chainId: "1")
    let abi = EvmAbi(name: "ERC20", abiContent: "[]")
    let contract1 = EVMContract(
        name: "USDC",
        address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        abiId: 1,
        status: .deployed,
        endpointId: 1
    )
    let contract2 = EVMContract(
        name: "DAI",
        address: "0x6B175474E89094C44Da98b954EedeAC495271d0F",
        abiId: 1,
        status: .pending,
        endpointId: 1
    )

    contract1.abi = abi
    contract1.endpoint = endpoint
    contract2.abi = abi
    contract2.endpoint = endpoint

    container.mainContext.insert(endpoint)
    container.mainContext.insert(abi)
    container.mainContext.insert(contract1)
    container.mainContext.insert(contract2)

    return NavigationSplitView {
        List {
            Text("Contracts")
        }
    } content: {
        ContractContentView(selectedContract: .constant(nil))
            .modelContainer(container)
    } detail: {
        Text("Select a contract")
    }
}
