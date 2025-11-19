//
//  ContractFormView.swift
//  SmartContractApp
//
//  Created by Claude on 11/8/25.
//

import Solidity
import SwiftData
import SwiftUI

struct ContractFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var name: String = ""
    @State private var address: String = ""
    @State private var selectedAbiId: UUID?
    @State private var selectedEndpointId: UUID?
    @State private var contractType: ContractType = .import
    @State private var sourceCode: String = ""
    @State private var bytecode: String = ""

    // Direct input for import mode
    @State private var abiContent: String = ""
    @State private var endpointUrl: String = ""
    @State private var endpointChainId: String = ""

    // Validation states
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""

    // Deployment sheet state
    @State private var showingDeploymentSheet = false

    // Compilation output from editor (shared with deployment sheet)
    @State private var compilationOutput: Output? = nil

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

                // Show address field only for import type
                if contractType == .import {
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
            }
            
            // Type-specific sections
            if contractType == .solidity {
                soliditySection
            } else if contractType == .bytecode {
                bytecodeSection
            }

            // Configuration section - show for import type or when editing deployed contracts
            if contractType == .import || (isEditing && contract?.status == .deployed) {
                Section(header: Text("ABI Configuration")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ABI JSON")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        #if os(macOS)
                        TextEditor(text: $abiContent)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 150, maxHeight: 300)
                            .border(Color.gray.opacity(0.3), width: 1)
                        #else
                        TextEditor(text: $abiContent)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 150, maxHeight: 300)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        #endif

                        Text("Paste the contract ABI JSON")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Endpoint Configuration")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("RPC URL")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("https://...", text: $endpointUrl)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        #if os(iOS)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        #endif
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Chain ID")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("1", text: $endpointChainId)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        #if os(iOS)
                            .keyboardType(.numberPad)
                        #endif

                        Text("Network chain ID (e.g., 1 for Ethereum Mainnet)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
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
                        if shouldShowDeployButton {
                            Button("Deploy") {
                                showingDeploymentSheet = true
                            }
                            .disabled(!isFormValid)
                        } else {
                            Button(isEditing ? "Update" : "Create") {
                                saveContract()
                            }
                            .disabled(!isFormValid)
                        }
                    }
                #else
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .primaryAction) {
                        if shouldShowDeployButton {
                            Button("Deploy") {
                                showingDeploymentSheet = true
                            }
                            .disabled(!isFormValid)
                        } else {
                            Button(isEditing ? "Update" : "Create") {
                                saveContract()
                            }
                            .disabled(!isFormValid)
                        }
                    }
                #endif
            }
            .sheet(isPresented: $showingDeploymentSheet) {
                deploymentSheet
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

    // MARK: - Computed Properties
    
    private var shouldShowDeployButton: Bool {
        !isEditing && (contractType == .solidity || contractType == .bytecode)
    }
    
    private var isFormValid: Bool {
        let nameValid = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        switch contractType {
        case .import:
            return nameValid &&
                !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                isValidAddress(address) &&
                !abiContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !endpointUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !endpointChainId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .solidity:
            return nameValid && !sourceCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .bytecode:
            return nameValid && !bytecode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    // MARK: - View Sections
    
    private var soliditySection: some View {
        Section(header: Text("Solidity Source Code")) {
            VStack(alignment: .leading, spacing: 8) {
                SolidityView(
                    content: $sourceCode,
                    compilationOutput: $compilationOutput
                )
                .frame(minHeight: 300, maxHeight: 500)

                Text("Enter your Solidity source code. It will be compiled during deployment.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var bytecodeSection: some View {
        Section(header: Text("Contract Bytecode")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Bytecode")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                #if os(macOS)
                TextEditor(text: $bytecode)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 100, maxHeight: 200)
                    .border(Color.gray.opacity(0.3), width: 1)
                #else
                TextEditor(text: $bytecode)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 100, maxHeight: 200)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                #endif
                
                Text("Enter the compiled bytecode (must start with 0x)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var deploymentSheet: some View {
        if contractType == .solidity {
            SolidityDeploymentSheet(
                sourceCode: $sourceCode,
                contractName: $name,
                editorCompilationOutput: $compilationOutput,
                onDeploy: { deployedContract in
                    // Dismiss the form after successful deployment
                    dismiss()
                }
            )
        } else if contractType == .bytecode {
            if let walletSigner = getWalletSigner() {
                let viewModel = ContractDeploymentViewModel(
                    modelContext: modelContext,
                    walletSigner: walletSigner
                )
                BytecodeDeploymentSheet(
                    bytecode: $bytecode,
                    contractName: $name,
                    viewModel: viewModel,
                    onDeploy: { deployedContract in
                        // Dismiss the form after successful deployment
                        dismiss()
                    }
                )
            } else {
                Text("No wallet available for deployment")
                    .padding()
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func getWalletSigner() -> WalletSignerViewModel? {
        // Query for the first available wallet
        let descriptor = FetchDescriptor<EVMWallet>()
        guard let wallet = try? modelContext.fetch(descriptor).first else {
            return nil
        }
        let viewModel = WalletSignerViewModel(currentWallet: wallet)
        viewModel.modelContext = modelContext
        return viewModel
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
        contractType = contract.type
        sourceCode = contract.sourceCode ?? ""
        bytecode = contract.bytecode ?? ""

        // Load direct input fields for import type
        if contract.type == .import {
            abiContent = contract.abi?.abiContent ?? ""
            endpointUrl = contract.endpoint?.url ?? ""
            endpointChainId = contract.endpoint?.chainId ?? ""
        }
    }

    private func saveContract() {
        guard validateForm() else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existingContract = contract {
            // Update existing contract
            existingContract.name = trimmedName
            existingContract.updatedAt = Date()

            // Update type-specific fields
            switch contractType {
            case .import:
                existingContract.address = trimmedAddress

                // Create or find ABI
                let trimmedAbi = abiContent.trimmingCharacters(in: .whitespacesAndNewlines)
                let abiName = "\(trimmedName)_ABI"

                let abiDescriptor = FetchDescriptor<EvmAbi>()
                let existingAbis = (try? modelContext.fetch(abiDescriptor)) ?? []
                let abi = existingAbis.first { $0.abiContent == trimmedAbi } ?? {
                    let newAbi = EvmAbi(name: abiName, abiContent: trimmedAbi)
                    modelContext.insert(newAbi)
                    return newAbi
                }()

                // Create or find Endpoint
                let trimmedUrl = endpointUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedChainId = endpointChainId.trimmingCharacters(in: .whitespacesAndNewlines)
                let endpointName = "Chain \(trimmedChainId)"

                let endpointDescriptor = FetchDescriptor<Endpoint>()
                let existingEndpoints = (try? modelContext.fetch(endpointDescriptor)) ?? []
                let endpoint = existingEndpoints.first { $0.url == trimmedUrl && $0.chainId == trimmedChainId } ?? {
                    let newEndpoint = Endpoint(name: endpointName, url: trimmedUrl, chainId: trimmedChainId)
                    modelContext.insert(newEndpoint)
                    return newEndpoint
                }()

                existingContract.abiId = abi.id
                existingContract.abi = abi
                existingContract.endpointId = endpoint.id
                existingContract.endpoint = endpoint

            case .solidity:
                existingContract.sourceCode = sourceCode
                // Preserve other fields when updating source code
            case .bytecode:
                existingContract.bytecode = bytecode
                // Allow updating ABI association for bytecode contracts
                if let abiId = selectedAbiId {
                    existingContract.abiId = abiId
                    existingContract.abi = abis.first { $0.id == abiId }
                }
            }
        } else {
            // Create new contract (only for import type, others use deployment)
            guard contractType == .import else {
                validationMessage = "Use the Deploy button to create Solidity or Bytecode contracts"
                showingValidationAlert = true
                return
            }

            // Create or find ABI
            let trimmedAbi = abiContent.trimmingCharacters(in: .whitespacesAndNewlines)
            let abiName = "\(trimmedName)_ABI"

            // Check if an ABI with the same content already exists
            let abiDescriptor = FetchDescriptor<EvmAbi>()
            let existingAbis = (try? modelContext.fetch(abiDescriptor)) ?? []
            let abi = existingAbis.first { $0.abiContent == trimmedAbi } ?? {
                let newAbi = EvmAbi(name: abiName, abiContent: trimmedAbi)
                modelContext.insert(newAbi)
                return newAbi
            }()

            // Create or find Endpoint
            let trimmedUrl = endpointUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedChainId = endpointChainId.trimmingCharacters(in: .whitespacesAndNewlines)
            let endpointName = "Chain \(trimmedChainId)"

            // Check if an endpoint with the same URL and chainId already exists
            let endpointDescriptor = FetchDescriptor<Endpoint>()
            let existingEndpoints = (try? modelContext.fetch(endpointDescriptor)) ?? []
            let endpoint = existingEndpoints.first { $0.url == trimmedUrl && $0.chainId == trimmedChainId } ?? {
                let newEndpoint = Endpoint(name: endpointName, url: trimmedUrl, chainId: trimmedChainId)
                modelContext.insert(newEndpoint)
                return newEndpoint
            }()

            let newContract = EVMContract(
                name: trimmedName,
                address: trimmedAddress,
                abiId: abi.id,
                status: .deployed,
                type: .import,
                endpointId: endpoint.id
            )

            // Set relationships
            newContract.abi = abi
            newContract.endpoint = endpoint

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

        if trimmedName.isEmpty {
            validationMessage = "Please enter a name for the contract."
            showingValidationAlert = true
            return false
        }

        switch contractType {
        case .import:
            let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)

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

            let trimmedAbi = abiContent.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedAbi.isEmpty {
                validationMessage = "Please enter the contract ABI JSON."
                showingValidationAlert = true
                return false
            }

            // Validate ABI is valid JSON
            if let data = trimmedAbi.data(using: .utf8) {
                do {
                    _ = try JSONSerialization.jsonObject(with: data)
                } catch {
                    validationMessage = "Invalid ABI JSON format: \(error.localizedDescription)"
                    showingValidationAlert = true
                    return false
                }
            }

            let trimmedUrl = endpointUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedUrl.isEmpty {
                validationMessage = "Please enter an endpoint URL."
                showingValidationAlert = true
                return false
            }

            // Validate URL format
            guard let _ = URL(string: trimmedUrl), trimmedUrl.hasPrefix("http") else {
                validationMessage = "Please enter a valid HTTP/HTTPS URL."
                showingValidationAlert = true
                return false
            }

            let trimmedChainId = endpointChainId.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedChainId.isEmpty {
                validationMessage = "Please enter a chain ID."
                showingValidationAlert = true
                return false
            }

            // Validate chain ID is a number
            guard Int(trimmedChainId) != nil else {
                validationMessage = "Chain ID must be a number."
                showingValidationAlert = true
                return false
            }

        case .solidity:
            let trimmedSource = sourceCode.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedSource.isEmpty {
                validationMessage = "Please enter Solidity source code."
                showingValidationAlert = true
                return false
            }
            
        case .bytecode:
            let trimmedBytecode = bytecode.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedBytecode.isEmpty {
                validationMessage = "Please enter contract bytecode."
                showingValidationAlert = true
                return false
            }
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
        abiId: abi.id,
        status: .deployed,
        endpointId: endpoint.id
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
