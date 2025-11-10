//
//  ContractFormView.swift
//  SmartContractApp
//
//  Created by Claude on 11/8/25.
//

import SwiftData
import SwiftUI

struct ContractFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var name: String = ""
    @State private var address: String = ""
    @State private var selectedAbiId: Int?
    @State private var selectedEndpointId: Int?

    // Validation states
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""

    // Query for available ABIs and Endpoints
    @Query(sort: \EvmAbi.name) private var abis: [EvmAbi]
    @Query(sort: \Endpoint.name) private var endpoints: [Endpoint]

    // Edit mode
    private let contract: EVMContract?
    private var isEditing: Bool { contract != nil }

    init(contract: EVMContract? = nil) {
        self.contract = contract
    }

    var body: some View {
        Form {
            Section(header: Text("Contract Details")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Enter contract name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Contract Address")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("0x...", text: $address)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    #if os(iOS)
                        .keyboardType(.asciiCapable)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    #endif
                    if !address.isEmpty && !isValidAddress(address) {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                            Text("Invalid address format. Must be 0x followed by 40 hex characters.")
                                .font(.caption2)
                        }
                        .foregroundColor(.orange)
                    }
                }
            }

            Section(header: Text("Configuration")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ABI")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if abis.isEmpty {
                        HStack {
                            Text("No ABIs available")
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .italic()
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    } else {
                        Picker("Select ABI", selection: $selectedAbiId) {
                            Text("Select ABI...").tag(nil as Int?)
                            ForEach(abis, id: \.id) { abi in
                                Text(abi.name).tag(abi.id as Int?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Endpoint")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if endpoints.isEmpty {
                        HStack {
                            Text("No endpoints available")
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .italic()
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    } else {
                        Picker("Select Endpoint", selection: $selectedEndpointId) {
                            Text("Select Endpoint...").tag(nil as Int?)
                            ForEach(endpoints, id: \.id) { endpoint in
                                HStack {
                                    Text(endpoint.name)
                                    Text("(Chain \(endpoint.chainId))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .tag(endpoint.id as Int?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }

            if isEditing {
                Section(header: Text("Metadata")) {
                    if let contract = contract {
                        HStack {
                            Text("Status:")
                            Spacer()
                            Text(contract.status.rawValue.capitalized)
                                .foregroundColor(statusColor(for: contract.status))
                        }

                        HStack {
                            Text("Created:")
                            Spacer()
                            Text(contract.createdAt, style: .date)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Updated:")
                            Spacer()
                            Text(contract.updatedAt, style: .date)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .navigationTitle(isEditing ? "Edit Contract" : "New Contract")
            .toolbar {
                #if os(iOS)
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(isEditing ? "Update" : "Create") {
                            saveContract()
                        }
                        .disabled(!isFormValid)
                    }
                #else
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .primaryAction) {
                        Button(isEditing ? "Update" : "Create") {
                            saveContract()
                        }
                        .disabled(!isFormValid)
                    }
                #endif
            }
            .onAppear {
                if let contract = contract {
                    loadContract(contract)
                }
            }
            .alert("Validation Error", isPresented: $showingValidationAlert) {
                Button("OK") {}
            } message: {
                Text(validationMessage)
            }
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            isValidAddress(address) &&
            selectedEndpointId != nil
    }

    private func isValidAddress(_ address: String) -> Bool {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        // Check if it starts with 0x and has exactly 42 characters (0x + 40 hex chars)
        guard trimmed.lowercased().hasPrefix("0x") && trimmed.count == 42 else {
            return false
        }
        // Check if the rest are valid hex characters
        let hexChars = trimmed.dropFirst(2)
        return hexChars.allSatisfy { $0.isHexDigit }
    }

    private func statusColor(for status: DeploymentStatus) -> Color {
        switch status {
        case .deployed:
            return .green
        case .pending:
            return .orange
        case .failed:
            return .red
        }
    }

    private func loadContract(_ contract: EVMContract) {
        name = contract.name
        address = contract.address
        selectedAbiId = contract.abiId
        selectedEndpointId = contract.endpointId
    }

    private func saveContract() {
        guard validateForm() else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existingContract = contract {
            // Update existing contract
            existingContract.name = trimmedName
            existingContract.address = trimmedAddress
            existingContract.abiId = selectedAbiId
            existingContract.endpointId = selectedEndpointId!
            existingContract.updatedAt = Date()

            // Update relationships
            existingContract.abi = abis.first { $0.id == selectedAbiId }
            existingContract.endpoint = endpoints.first { $0.id == selectedEndpointId }
        } else {
            // Create new contract
            let newContract = EVMContract(
                name: trimmedName,
                address: trimmedAddress,
                abiId: selectedAbiId,
                status: .deployed,
                endpointId: selectedEndpointId!
            )

            // Set relationships
            newContract.abi = abis.first { $0.id == selectedAbiId }
            newContract.endpoint = endpoints.first { $0.id == selectedEndpointId }

            modelContext.insert(newContract)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            validationMessage = "Failed to save contract: \(error.localizedDescription)"
            showingValidationAlert = true
        }
    }

    private func validateForm() -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty {
            validationMessage = "Please enter a name for the contract."
            showingValidationAlert = true
            return false
        }

        if trimmedAddress.isEmpty {
            validationMessage = "Please enter a contract address."
            showingValidationAlert = true
            return false
        }

        if !isValidAddress(trimmedAddress) {
            validationMessage = "Please enter a valid Ethereum address (0x followed by 40 hex characters)."
            showingValidationAlert = true
            return false
        }

        if selectedEndpointId == nil {
            validationMessage = "Please select an endpoint."
            showingValidationAlert = true
            return false
        }

        return true
    }
}

#Preview("Create Mode") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: EVMContract.self, EvmAbi.self, Endpoint.self,
        configurations: config
    )

    // Add sample data
    let endpoint = Endpoint(name: "Mainnet", url: "https://eth.llamarpc.com", chainId: "1")
    let abi = EvmAbi(name: "ERC20", abiContent: "[]")

    container.mainContext.insert(endpoint)
    container.mainContext.insert(abi)

    return NavigationStack {
        ContractFormView()
            .modelContainer(container)
    }
}

#Preview("Edit Mode") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: EVMContract.self, EvmAbi.self, Endpoint.self,
        configurations: config
    )

    let endpoint = Endpoint(name: "Mainnet", url: "https://eth.llamarpc.com", chainId: "1")
    let abi = EvmAbi(name: "ERC20", abiContent: "[]")
    let contract = EVMContract(
        name: "USDC",
        address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        abiId: 1,
        status: .deployed,
        endpointId: 1
    )
    contract.abi = abi
    contract.endpoint = endpoint

    container.mainContext.insert(endpoint)
    container.mainContext.insert(abi)
    container.mainContext.insert(contract)

    return NavigationStack {
        ContractFormView(contract: contract)
            .modelContainer(container)
    }
}
