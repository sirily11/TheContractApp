//
//  ContractTabView.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/12/25.
//

import SwiftData
import SwiftUI

struct ContractTabView: View {
    @State private var selectedContract: EVMContract?

    var body: some View {
        NavigationSplitView {
            // Sidebar - Contract list
            ContractContentView(selectedContract: $selectedContract)
        } content: {
            // Content - Contract detail
            if let selectedContract = selectedContract {
                ContractDetailView(contract: selectedContract)
            } else {
                ContentUnavailableView(
                    "No Selection",
                    systemImage: "doc.text.fill",
                    description: Text("Select a contract to view its details.")
                )
            }
        } detail: {
            // Detail - Contract functions with tabs
            if let selectedContract = selectedContract {
                ContractFunctionsTabView(contract: selectedContract)
                    .padding(.top, 1)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "function")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)

                    Text("Contract Functions")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Select a contract to view and interact with its functions")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
    }
}

#Preview {
    ContractTabView()
        .modelContainer(for: [EVMContract.self, Endpoint.self, EvmAbi.self], inMemory: true)
}
