//
//  AbiDetailView.swift
//  SmartContractApp
//
//  Created by Claude on 11/7/25.
//

import EvmCore
import SwiftData
import SwiftUI

struct AbiDetailView: View {
    let abi: EvmAbi
    let showConnectedContracts: Bool

    @Environment(\.modelContext) private var modelContext
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false

    @Query private var allContracts: [EVMContract]

    init(abi: EvmAbi, showConnectedContracts: Bool = true) {
        self.abi = abi
        self.showConnectedContracts = showConnectedContracts

        // Query all contracts - will filter in computed property
        _allContracts = Query(sort: \EVMContract.name)
    }

    private var parser: AbiParser? {
        try? AbiParser(fromJsonString: abi.abiContent)
    }

    private var connectedContracts: [EVMContract] {
        allContracts.filter { $0.abiId == abi.id }
    }

    var body: some View {
        Form {
            // Header section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(abi.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("ABI Details")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20))
            }

            if let parser = parser {
                // Summary Section
                Section("Summary") {
                    HStack {
                        Text("Functions")
                        Spacer()
                        Text("\(parser.functions.count)")
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }

                    HStack {
                        Text("Events")
                        Spacer()
                        Text("\(parser.events.count)")
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }

                    HStack {
                        Text("Errors")
                        Spacer()
                        Text("\(parser.errors.count)")
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }

                    HStack {
                        Text("Constructor")
                        Spacer()
                        Text(parser.constructor != nil ? "Yes" : "No")
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }

                // Connected Contracts Section
                if showConnectedContracts {
                    Section("Connected Contracts") {
                        if connectedContracts.isEmpty {
                            HStack {
                                Text("No contracts using this ABI")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                                    .italic()
                                Spacer()
                            }
                        } else {
                            ForEach(connectedContracts, id: \.id) { contract in
                                NavigationLink(value: contract) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(contract.name)
                                                .font(.headline)

                                            Text(truncatedAddress(contract.address))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        // Status badge
                                        Text(contract.status.rawValue.capitalized)
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(contractStatusColor(contract.status).opacity(0.2))
                                            .foregroundColor(contractStatusColor(contract.status))
                                            .cornerRadius(4)
                                    }
                                }
                            }
                        }
                    }
                }

                // Functions Section
                if !parser.functions.isEmpty {
                    Section("Functions") {
                        ForEach(parser.typedFunctions(), id: \.name) { function in
                            DisclosureGroup {
                                VStack(alignment: .leading, spacing: 12) {
                                    // State Mutability
                                    HStack {
                                        Text("State:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(function.stateMutability.rawValue)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(stateColor(function.stateMutability))
                                        Spacer()
                                    }

                                    // Inputs
                                    if !function.inputs.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Inputs:")
                                                .font(.caption)
                                                .foregroundColor(.secondary)

                                            ForEach(function.inputs, id: \.name) { param in
                                                HStack(alignment: .top, spacing: 4) {
                                                    Text("•")
                                                        .font(.caption2)
                                                    Text(param.name.isEmpty ? "(unnamed)" : param.name)
                                                        .font(.caption)
                                                    Text(":")
                                                        .font(.caption)
                                                    Text(param.type)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                    Spacer()
                                                }
                                            }
                                        }
                                    } else {
                                        Text("No inputs")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .italic()
                                    }

                                    // Outputs
                                    if !function.outputs.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Returns:")
                                                .font(.caption)
                                                .foregroundColor(.secondary)

                                            ForEach(function.outputs, id: \.name) { param in
                                                HStack(alignment: .top, spacing: 4) {
                                                    Text("•")
                                                        .font(.caption2)
                                                    Text(param.name.isEmpty ? "(unnamed)" : param.name)
                                                        .font(.caption)
                                                    Text(":")
                                                        .font(.caption)
                                                    Text(param.type)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                    Spacer()
                                                }
                                            }
                                        }
                                    } else {
                                        Text("No return values")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .italic()
                                    }
                                }
                                .padding(.vertical, 4)
                            } label: {
                                HStack {
                                    Text(function.name)
                                        .font(.body)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(functionSignature(function))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }

                // Events Section
                if !parser.events.isEmpty {
                    Section("Events") {
                        ForEach(parser.typedEvents(), id: \.name) { event in
                            DisclosureGroup {
                                VStack(alignment: .leading, spacing: 8) {
                                    // Anonymous flag
                                    if event.anonymous {
                                        HStack {
                                            Image(systemName: "eye.slash")
                                                .font(.caption2)
                                            Text("Anonymous")
                                                .font(.caption)
                                            Spacer()
                                        }
                                        .foregroundColor(.orange)
                                    }

                                    // Inputs
                                    if !event.inputs.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Parameters:")
                                                .font(.caption)
                                                .foregroundColor(.secondary)

                                            ForEach(event.inputs, id: \.name) { param in
                                                HStack(alignment: .top, spacing: 4) {
                                                    Text("•")
                                                        .font(.caption2)
                                                    if param.indexed == true {
                                                        Text("indexed")
                                                            .font(.caption2)
                                                            .foregroundColor(.blue)
                                                            .padding(.horizontal, 4)
                                                            .padding(.vertical, 1)
                                                            .background(Color.blue.opacity(0.1))
                                                            .cornerRadius(3)
                                                    }
                                                    Text(param.name.isEmpty ? "(unnamed)" : param.name)
                                                        .font(.caption)
                                                    Text(":")
                                                        .font(.caption)
                                                    Text(param.type)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                    Spacer()
                                                }
                                            }
                                        }
                                    } else {
                                        Text("No parameters")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .italic()
                                    }
                                }
                                .padding(.vertical, 4)
                            } label: {
                                HStack {
                                    Text(event.name)
                                        .font(.body)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text("\(event.inputs.count) param\(event.inputs.count == 1 ? "" : "s")")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                // Constructor Section
                if let constructor = parser.constructor {
                    Section("Constructor") {
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 8) {
                                if let inputs = constructor.inputs, !inputs.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Parameters:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        ForEach(inputs, id: \.name) { param in
                                            HStack(alignment: .top, spacing: 4) {
                                                Text("•")
                                                    .font(.caption2)
                                                Text(param.name.isEmpty ? "(unnamed)" : param.name)
                                                    .font(.caption)
                                                Text(":")
                                                    .font(.caption)
                                                Text(param.type)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                Spacer()
                                            }
                                        }
                                    }
                                } else {
                                    Text("No parameters")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .italic()
                                }

                                if let stateMutability = constructor.stateMutability {
                                    HStack {
                                        Text("State:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(stateMutability.rawValue)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(stateColor(stateMutability))
                                        Spacer()
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        } label: {
                            Text("Constructor Details")
                                .font(.body)
                                .fontWeight(.medium)
                        }
                    }
                }
            } else {
                // Invalid ABI
                Section("Error") {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Failed to parse ABI")
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
            }

            // Timestamps
            Section("Timeline") {
                HStack {
                    Text("Created")
                    Spacer()
                    Text(abi.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Last Updated")
                    Spacer()
                    Text(abi.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("ABI")
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
            AbiFormView(abi: abi)
        }
        .alert("Delete ABI", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteAbi()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete '\(abi.name)'? This action cannot be undone.")
        }
    }

    private func deleteAbi() {
        withAnimation {
            modelContext.delete(abi)
            try? modelContext.save()
        }
    }

    private func stateColor(_ state: StateMutability) -> Color {
        switch state {
        case .view, .pure:
            return .blue
        case .nonpayable:
            return .orange
        case .payable:
            return .red
        }
    }

    private func functionSignature(_ function: AbiFunction) -> String {
        let inputs = function.inputs.map { $0.type }.joined(separator: ", ")
        let outputs = function.outputs.map { $0.type }.joined(separator: ", ")
        if outputs.isEmpty {
            return "(\(inputs))"
        }
        return "(\(inputs)) → (\(outputs))"
    }

    private func truncatedAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        let start = address.prefix(6)
        let end = address.suffix(4)
        return "\(start)...\(end)"
    }

    private func contractStatusColor(_ status: DeploymentStatus) -> Color {
        switch status {
        case .deployed:
            return .green
        case .pending:
            return .orange
        case .failed:
            return .red
        }
    }
}

#Preview {
    let sampleAbi = """
    [
        {
            "type": "constructor",
            "inputs": [
                {"name": "initialSupply", "type": "uint256"}
            ],
            "stateMutability": "nonpayable"
        },
        {
            "type": "function",
            "name": "transfer",
            "inputs": [
                {"name": "to", "type": "address"},
                {"name": "amount", "type": "uint256"}
            ],
            "outputs": [
                {"name": "success", "type": "bool"}
            ],
            "stateMutability": "nonpayable"
        },
        {
            "type": "function",
            "name": "balanceOf",
            "inputs": [
                {"name": "account", "type": "address"}
            ],
            "outputs": [
                {"name": "balance", "type": "uint256"}
            ],
            "stateMutability": "view"
        },
        {
            "type": "event",
            "name": "Transfer",
            "inputs": [
                {"name": "from", "type": "address", "indexed": true},
                {"name": "to", "type": "address", "indexed": true},
                {"name": "value", "type": "uint256", "indexed": false}
            ],
            "anonymous": false
        }
    ]
    """

    return NavigationStack {
        AbiDetailView(
            abi: EvmAbi(
                name: "ERC20 Token",
                abiContent: sampleAbi
            )
        )
    }
    .modelContainer(for: EvmAbi.self, inMemory: true)
}
