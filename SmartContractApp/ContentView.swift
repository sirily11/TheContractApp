//
//  ContentView.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/5/25.
//

import SwiftData
import SwiftUI

enum SidebarCategory: String, CaseIterable, Hashable, Identifiable {
    case endpoints
    case abi
    case contract
    case wallet

    var id: String { rawValue }

    var title: String {
        switch self {
        case .endpoints: return "Endpoints"
        case .abi: return "ABI"
        case .contract: return "Contract"
        case .wallet: return "Wallet"
        }
    }

    var systemImage: String {
        switch self {
        case .endpoints: return "network"
        case .abi: return "doc.text"
        case .contract: return "scroll"
        case .wallet: return "creditcard"
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedCategory: SidebarCategory?
    @State private var selectedEndpoint: Endpoint?

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(SidebarCategory.allCases, selection: $selectedCategory) { category in
                NavigationLink(value: category) {
                    Label(category.title, systemImage: category.systemImage)
                }
            }
            .navigationTitle("Smart Contract App")
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } content: {
            // Content
            if let selectedCategory = selectedCategory {
                switch selectedCategory {
                case .endpoints:
                    EndpointContentView(selectedEndpoint: $selectedEndpoint)
                case .abi:
                    EmptyPlaceholderView(title: "ABI Management", description: "ABI management features coming soon")
                case .contract:
                    EmptyPlaceholderView(title: "Contract Management", description: "Contract management features coming soon")
                case .wallet:
                    EmptyPlaceholderView(title: "Wallet Management", description: "Wallet management features coming soon")
                }
            } else {
                ContentUnavailableView(
                    "Select Category",
                    systemImage: "sidebar.left",
                    description: Text("Choose a category from the sidebar to view its contents.")
                )
            }
        } detail: {
            // Detail
            if let selectedEndpoint = selectedEndpoint {
                EndpointDetailView(endpoint: selectedEndpoint)
            } else if selectedCategory != nil {
                ContentUnavailableView(
                    "No Selection",
                    systemImage: "doc",
                    description: Text("Select an item to view its details.")
                )
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "network")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)

                    Text("Welcome to Smart Contract App")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Select a category from the sidebar to get started")
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
    ContentView()
        .modelContainer(for: [Endpoint.self, EVMContract.self, EvmAbi.self], inMemory: true)
}
