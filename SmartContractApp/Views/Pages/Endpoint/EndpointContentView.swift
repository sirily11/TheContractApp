//
//  EndpointContentView.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/7/25.
//
import SwiftData
import SwiftUI

struct EndpointContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Endpoint.createdAt, order: .reverse) private var endpoints: [Endpoint]
    @Binding var selectedEndpoint: Endpoint?

    @State private var showingCreateSheet = false
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var endpointToDelete: Endpoint?

    var body: some View {
        List(endpoints, selection: $selectedEndpoint) { endpoint in
            NavigationLink(value: endpoint) {
                EndpointRowView(endpoint: endpoint)
            }
            .contextMenu {
                Button("Edit") {
                    selectedEndpoint = endpoint
                    showingEditSheet = true
                }

                Divider()

                Button("Delete", role: .destructive) {
                    endpointToDelete = endpoint
                    showingDeleteAlert = true
                }
            }
        }
        .navigationTitle("Endpoints")
        .navigationSplitViewColumnWidth(min: 300, ideal: 350)
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingCreateSheet = true
                }) {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier(.endpoint.addButton)
            }
            #else
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showingCreateSheet = true
                }) {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier(.endpoint.addButton)
            }
            #endif
        }
        .sheet(isPresented: $showingCreateSheet) {
            EndpointFormView()
        }
        .sheet(isPresented: $showingEditSheet) {
            if let endpoint = selectedEndpoint {
                EndpointFormView(endpoint: endpoint)
            } else {
                Text("No endpoint selected")
            }
        }
        .alert("Delete Endpoint", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let endpoint = endpointToDelete {
                    deleteEndpoint(endpoint)
                }
            }
            .accessibilityIdentifier(.endpoint.deleteConfirmButton)

            Button("Cancel", role: .cancel) {
                endpointToDelete = nil
            }
        } message: {
            if let endpoint = endpointToDelete {
                Text("Are you sure you want to delete '\(endpoint.name)'? This action cannot be undone.")
            }
        }
    }

    private func deleteEndpoint(_ endpoint: Endpoint) {
        withAnimation {
            modelContext.delete(endpoint)
            try? modelContext.save()
        }
        endpointToDelete = nil

        // Clear selection if deleted endpoint was selected
        if selectedEndpoint == endpoint {
            selectedEndpoint = nil
        }
    }
}
