//
//  EndpointDetailView.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/7/25.
//

import SwiftData
import SwiftUI
import EvmCore

enum ConnectionStatus {
    case testing
    case connected
    case failed(String)
    
    var statusText: String {
        switch self {
        case .testing:
            return "Testing connection..."
        case .connected:
            return "Connected"
        case .failed:
            return "Connection failed"
        }
    }
    
    var statusColor: Color {
        switch self {
        case .testing:
            return .orange
        case .connected:
            return .green
        case .failed:
            return .red
        }
    }
    
    var statusIcon: String {
        switch self {
        case .testing:
            return "antenna.radiowaves.left.and.right"
        case .connected:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }
}

struct EndpointDetailView: View {
    let endpoint: Endpoint
    @Environment(\.modelContext) private var modelContext
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false

    // Connection test state
    @State private var connectionStatus: ConnectionStatus = .testing
    @State private var detectedChainId: String = ""
    @State private var connectionTimer: Timer?
    
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
            
            // Connection Status Section
            Section("Connection Status") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: connectionStatus.statusIcon)
                            .foregroundColor(connectionStatus.statusColor)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(connectionStatus.statusText)
                                .font(.headline)
                                .foregroundColor(connectionStatus.statusColor)
                            
                            if case .testing = connectionStatus {
                                Text("Verifying endpoint connectivity...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else if case .connected = connectionStatus {
                                if !detectedChainId.isEmpty {
                                    Text("Chain ID: \(detectedChainId)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else if case .failed(let error) = connectionStatus {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                                
                                Button("Retry Connection") {
                                    testConnection()
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.top, 4)
                            }
                        }
                        
                        Spacer()
                        
                        if case .testing = connectionStatus {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
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
        .onAppear {
            testConnection()
            startPeriodicCheck()
        }
        .onDisappear {
            stopPeriodicCheck()
        }
        .refreshable {
            testConnection()
        }
    }
    
    private func deleteEndpoint() {
        withAnimation {
            modelContext.delete(endpoint)
            try? modelContext.save()
        }
    }
    
    private func testConnection() {
        connectionStatus = .testing
        detectedChainId = ""

        Task {
            do {
                let chainId = try await endpoint.fetchChainId()

                await MainActor.run {
                    detectedChainId = chainId
                    connectionStatus = .connected
                }
            } catch let error as ChainValidationError {
                await MainActor.run {
                    connectionStatus = .failed(error.localizedDescription ?? "Unknown error")
                }
            } catch {
                await MainActor.run {
                    connectionStatus = .failed("Failed to connect: \(error.localizedDescription)")
                }
            }
        }
    }

    private func startPeriodicCheck() {
        stopPeriodicCheck() // Clean up any existing timer
        connectionTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            testConnection()
        }
    }

    private func stopPeriodicCheck() {
        connectionTimer?.invalidate()
        connectionTimer = nil
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
