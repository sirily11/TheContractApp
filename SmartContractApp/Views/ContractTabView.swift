//
//  ContractTabView.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/12/25.
//

import SwiftData
import SwiftUI

enum ContractCategory: String, CaseIterable, Hashable, Identifiable {
    case contracts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .contracts: return "Contracts"
        }
    }

    var systemImage: String {
        switch self {
        case .contracts: return "doc.text.fill"
        }
    }
}

struct ContractTabView: View {
    @State private var selectedCategory: ContractCategory?
    @State private var selectedContract: EVMContract?

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(ContractCategory.allCases, selection: $selectedCategory) { category in
                NavigationLink(value: category) {
                    Label(category.title, systemImage: category.systemImage)
                }
            }
            .navigationTitle("Contract")
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } content: {
            // Content
            if let selectedCategory = selectedCategory {
                switch selectedCategory {
                case .contracts:
                    ContractContentView(selectedContract: $selectedContract)
                }
            } else {
                ContentUnavailableView(
                    "Select Category",
                    systemImage: "sidebar.left",
                    description: Text("Choose a category from the sidebar.")
                )
            }
        } detail: {
            // Detail
            if let selectedContract = selectedContract {
                ContractDetailView(contract: selectedContract)
            } else if selectedCategory != nil {
                ContentUnavailableView(
                    "No Selection",
                    systemImage: "doc.text.fill",
                    description: Text("Select a contract to view its details.")
                )
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)

                    Text("Contracts")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Select a category from the sidebar")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .onChange(of: selectedCategory) { _, _ in
            // Clear contract selection when category changes
            selectedContract = nil
        }
    }
}

#Preview {
    ContractTabView()
        .modelContainer(for: [EVMContract.self, Endpoint.self, EvmAbi.self], inMemory: true)
}
