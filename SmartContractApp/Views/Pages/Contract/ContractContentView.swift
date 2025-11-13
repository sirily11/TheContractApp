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

    // Deployment sheets
    @State private var showingSolidityDeploymentSheet = false
    @State private var showingBytecodeDeploymentSheet = false
    @State private var soliditySourceCode = ""
    @State private var solidityContractName = ""
    @State private var bytecodeData = ""
    @State private var bytecodeContractName = ""

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
            ContractFormView()
        }
        .sheet(isPresented: $showingEditSheet) {
            if let contract = selectedContract {
                ContractFormView(contract: contract)
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
        .sheet(isPresented: $showingSolidityDeploymentSheet) {
            SolidityDeploymentSheet(
                sourceCode: $soliditySourceCode,
                contractName: $solidityContractName,
                onDeploy: { contract in
                    selectedContract = contract
                }
            )
        }
        .sheet(isPresented: $showingBytecodeDeploymentSheet) {
            BytecodeDeploymentSheet(
                bytecode: $bytecodeData,
                contractName: $bytecodeContractName,
                viewModel: createDeploymentViewModel(),
                onDeploy: { contract in
                    selectedContract = contract
                }
            )
        }
    }

    private var contractCreationMenu: some View {
        Menu {
            Menu("Deploy") {
                Button {
                    // Reset state and show Solidity deployment sheet
                    soliditySourceCode = ""
                    solidityContractName = ""
                    showingSolidityDeploymentSheet = true
                } label: {
                    Label("Solidity", systemImage: "document")
                }

                Button {
                    // Reset state and show Bytecode deployment sheet
                    bytecodeData = ""
                    bytecodeContractName = ""
                    showingBytecodeDeploymentSheet = true
                } label: {
                    Label("Bytecode", systemImage: "doc.text")
                }
            }

            Button(action: {
                showingCreateSheet = true
            }) {
                Label("Import Existing Contract", systemImage: "plus.square")
            }

        } label: {
            Image(systemName: "plus")
        }
    }

    private func createDeploymentViewModel() -> ContractDeploymentViewModel {
        // Fetch the first available wallet from the model context
        // In a real app, this would use the currently selected wallet
        let fetchDescriptor = FetchDescriptor<EVMWallet>()
        let wallets = (try? modelContext.fetch(fetchDescriptor)) ?? []
        let currentWallet = wallets.first

        let walletSigner = WalletSignerViewModel(
            modelContext: modelContext,
            currentWallet: currentWallet
        )

        return ContractDeploymentViewModel(
            modelContext: modelContext,
            walletSigner: walletSigner
        )
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
        abiId: abi.id,
        status: .deployed,
        endpointId: endpoint.id
    )
    let contract2 = EVMContract(
        name: "DAI",
        address: "0x6B175474E89094C44Da98b954EedeAC495271d0F",
        abiId: abi.id,
        status: .pending,
        endpointId: endpoint.id
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
