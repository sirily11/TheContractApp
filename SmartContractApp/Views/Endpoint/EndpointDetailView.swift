//
//  EndpointDetailView.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/7/25.
//

import SwiftData
import SwiftUI

struct EndpointDetailView: View {
    let endpoint: Endpoint
    @Environment(\.modelContext) private var modelContext
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        Form {
            // Header section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(endpoint.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("Endpoint Details")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20))
            }
            
            // Endpoint Information
            Section("Connection Information") {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(endpoint.name)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity)
                
                HStack {
                    Text("URL")
                    Spacer()
                    Text(endpoint.url)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
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
            }
            
            // Timestamps
            Section("Timeline") {
                HStack {
                    Text("Created")
                    Spacer()
                    Text(endpoint.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                HStack {
                    Text("Last Updated")
                    Spacer()
                    Text(endpoint.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            
            // Test Connection Section
            Section("Connection Test") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Test the connection to this endpoint")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Button("Test Connection") {
                        // TODO: Implement connection test
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(true) // Disabled for now
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle("Endpoint")
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
            EndpointFormView(endpoint: endpoint)
        }
        .alert("Delete Endpoint", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteEndpoint()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete '\(endpoint.name)'? This action cannot be undone.")
        }
    }
    
    private func deleteEndpoint() {
        withAnimation {
            modelContext.delete(endpoint)
            try? modelContext.save()
        }
    }
}

#Preview {
    NavigationStack {
        EndpointDetailView(
            endpoint: Endpoint(
                id: 1,
                name: "Sample Endpoint",
                url: "https://eth-mainnet.example.com",
                chainId: "1"
            )
        )
    }
    .modelContainer(for: Endpoint.self, inMemory: true)
}
