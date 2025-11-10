//
//  AbiContentView.swift
//  SmartContractApp
//
//  Created by Claude on 11/7/25.
//
import SwiftData
import SwiftUI

struct AbiContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EvmAbi.createdAt, order: .reverse) private var abis: [EvmAbi]
    @Binding var selectedAbi: EvmAbi?

    @State private var showingCreateSheet = false
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var abiToDelete: EvmAbi?

    var body: some View {
        List(abis, selection: $selectedAbi) { abi in
            NavigationLink(value: abi) {
                AbiRowView(abi: abi)
            }
            .contextMenu {
                Button("Edit") {
                    selectedAbi = abi
                    showingEditSheet = true
                }

                Divider()

                Button("Delete", role: .destructive) {
                    abiToDelete = abi
                    showingDeleteAlert = true
                }
            }
        }
        .navigationTitle("ABI")
        .navigationSplitViewColumnWidth(min: 300, ideal: 350)
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingCreateSheet = true
                }) {
                    Image(systemName: "plus")
                }
            }
            #else
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showingCreateSheet = true
                }) {
                    Image(systemName: "plus")
                }
            }
            #endif
        }
        .sheet(isPresented: $showingCreateSheet) {
            AbiFormView()
        }
        .sheet(isPresented: $showingEditSheet) {
            if let abi = selectedAbi {
                AbiFormView(abi: abi)
            } else {
                Text("No ABI selected")
            }
        }
        .alert("Delete ABI", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let abi = abiToDelete {
                    deleteAbi(abi)
                }
            }
            Button("Cancel", role: .cancel) {
                abiToDelete = nil
            }
        } message: {
            if let abi = abiToDelete {
                Text("Are you sure you want to delete '\(abi.name)'? This action cannot be undone.")
            }
        }
    }

    private func deleteAbi(_ abi: EvmAbi) {
        withAnimation {
            modelContext.delete(abi)
            try? modelContext.save()
        }
        abiToDelete = nil

        // Clear selection if deleted ABI was selected
        if selectedAbi == abi {
            selectedAbi = nil
        }
    }
}
