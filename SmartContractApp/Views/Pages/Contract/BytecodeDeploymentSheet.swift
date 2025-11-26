//
//  BytecodeDeploymentSheet.swift
//  SmartContractApp
//
//  Created by Kiro on 11/12/25.
//

import SwiftData
import SwiftUI

struct BytecodeDeploymentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - Bindings
    
    @Binding var bytecode: String
    @Binding var contractName: String
    
    // MARK: - State Properties
    
    @State private var selectedEndpoint: Endpoint?
    @State private var selectedAbi: EvmAbi?
    @State private var showingAbiSheet: Bool = false
    @State private var isDeploying: Bool = false
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    @State private var bytecodeValidationError: String?
    
    // MARK: - Query for Endpoints and ABIs
    
    @Query(sort: \Endpoint.name) private var endpoints: [Endpoint]
    @Query(sort: \EvmAbi.name) private var abis: [EvmAbi]
    
    // MARK: - Dependencies
    
    let viewModel: ContractDeploymentViewModel
    var onDeploy: ((EVMContract) -> Void)?
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // Contract Details Section
                contractDetailsSection
                
                // Bytecode Input Section
                bytecodeInputSection
                
                // ABI Selection Section
                abiSelectionSection
                
                // Endpoint Selection Section
                endpointSelectionSection
                
                // Deployment Progress Section
                if isDeploying {
                    deploymentProgressSection
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Deploy from Bytecode")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    #if os(iOS)
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                dismiss()
                            }
                            .disabled(isDeploying)
                        }
                
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Deploy") {
                                deployContract()
                            }
                            .disabled(!isFormValid || isDeploying)
                        }
                    #else
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                dismiss()
                            }
                            .disabled(isDeploying)
                        }
                
                        ToolbarItem(placement: .primaryAction) {
                            Button("Deploy") {
                                deployContract()
                            }
                            .disabled(!isFormValid || isDeploying)
                        }
                    #endif
                }
                .alert("Validation Error", isPresented: $showingValidationAlert) {
                    Button("OK") {}
                } message: {
                    Text(validationMessage)
                }
                .sheet(isPresented: $showingAbiSheet) {
                    AbiSelectionSheet(onSave: { createdAbi in
                        selectedAbi = createdAbi
                    })
                }
        }
    }
    
    // MARK: - View Sections
    
    private var contractDetailsSection: some View {
        Section(header: Text("Contract Details")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Contract Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Enter contract alias", text: $contractName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                #if os(iOS)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                #endif
                
                if contractName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text("Contract name is required")
                            .font(.caption2)
                    }
                    .foregroundColor(.orange)
                }
            }
        }
    }
    
    private var bytecodeInputSection: some View {
        Section(header: Text("Bytecode")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Contract Bytecode")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                #if os(macOS)
                    TextEditor(text: $bytecode)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 100, maxHeight: 200)
                        .border(Color.gray.opacity(0.3), width: 1)
                        .onChange(of: bytecode) { _, newValue in
                            validateBytecodeFormat(newValue)
                        }
                #else
                    TextEditor(text: $bytecode)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 100, maxHeight: 200)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: bytecode) { _, newValue in
                            validateBytecodeFormat(newValue)
                        }
                #endif
                
                Text("Enter the compiled bytecode (must start with 0x)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if let error = bytecodeValidationError {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption2)
                        Text(error)
                            .font(.caption2)
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
    
    private var abiSelectionSection: some View {
        Section(header: Text("ABI (Optional)")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Contract ABI")
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
                    Picker("Select ABI", selection: $selectedAbi) {
                        Text("No ABI selected").tag(nil as EvmAbi?)
                        ForEach(abis, id: \.id) { abi in
                            Text(abi.name).tag(abi as EvmAbi?)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Button(action: {
                    showingAbiSheet = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add New ABI")
                    }
                }
                .buttonStyle(.borderless)
                
                if selectedAbi != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text("ABI selected: \(selectedAbi?.name ?? "")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("You can deploy without an ABI, but you won't be able to interact with the contract")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
    }
    
    private var endpointSelectionSection: some View {
        Section(header: Text("Deployment Configuration")) {
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
                    Picker("Select Endpoint", selection: $selectedEndpoint) {
                        Text("Select Endpoint...").tag(nil as Endpoint?)
                        ForEach(endpoints, id: \.id) { endpoint in
                            HStack {
                                Text(endpoint.name)
                                Text("(Chain \(endpoint.chainId))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(endpoint as Endpoint?)
                        }
                    }
                    .accessibilityIdentifier(.contract.endpointButton)
                    .pickerStyle(.menu)
                }
                
                if selectedEndpoint == nil && !endpoints.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text("Please select an endpoint")
                            .font(.caption2)
                    }
                    .foregroundColor(.orange)
                }
            }
        }
    }
    
    private var deploymentProgressSection: some View {
        Section(header: Text("Deployment Progress")) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text(progressMessage)
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                
                if case .completed(let address) = viewModel.deploymentProgress {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Deployment Successful")
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                        
                        Text("Contract Address:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(address)
                            .font(.caption)
                            .monospaced()
                            .padding(8)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                if case .failed(let error) = viewModel.deploymentProgress {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text("Deployment Failed")
                                .font(.headline)
                                .foregroundColor(.red)
                        }
                        
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(4)
                        
                        // Retry button
                        Button(action: {
                            deployContract()
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Retry Deployment")
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        !contractName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !bytecode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            bytecodeValidationError == nil &&
            selectedEndpoint != nil
    }
    
    private var progressMessage: String {
        switch viewModel.deploymentProgress {
        case .idle:
            return "Preparing..."
        case .compiling:
            return "Compiling source code..."
        case .preparingTransaction:
            return "Preparing transaction..."
        case .signing:
            return "Signing transaction..."
        case .sending:
            return "Sending transaction to network..."
        case .confirming:
            return "Waiting for confirmation..."
        case .completed:
            return "Deployment complete!"
        case .failed:
            return "Deployment failed"
        }
    }
    
    // MARK: - Actions
    
    private func validateBytecodeFormat(_ bytecode: String) {
        let trimmed = bytecode.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Allow empty during editing
        if trimmed.isEmpty {
            bytecodeValidationError = nil
            return
        }
        
        // Check if it starts with 0x
        guard trimmed.hasPrefix("0x") else {
            bytecodeValidationError = "Bytecode must start with '0x'"
            return
        }
        
        // Check if it contains only valid hex characters
        let hexString = String(trimmed.dropFirst(2))
        if hexString.isEmpty {
            bytecodeValidationError = "Bytecode cannot be empty after '0x'"
            return
        }
        
        let hexCharacterSet = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        guard hexString.unicodeScalars.allSatisfy({ hexCharacterSet.contains($0) }) else {
            bytecodeValidationError = "Bytecode contains invalid hex characters"
            return
        }
        
        // Valid bytecode
        bytecodeValidationError = nil
    }
    
    private func deployContract() {
        guard validateForm() else { return }
        
        guard let endpoint = selectedEndpoint else {
            validationMessage = "Please select an endpoint"
            showingValidationAlert = true
            return
        }
        
        let trimmedName = contractName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBytecode = bytecode.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            do {
                isDeploying = true
                
                let contract = try await viewModel.deployBytecodeContract(
                    bytecode: trimmedBytecode,
                    name: trimmedName,
                    endpoint: endpoint,
                    abi: selectedAbi
                )
                
                isDeploying = false
                
                // Dismiss sheet after a brief delay to show success
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                dismiss()
            } catch {
                isDeploying = false
                
                validationMessage = error.localizedDescription
                showingValidationAlert = true
            }
        }
    }
    
    private func validateForm() -> Bool {
        let trimmedName = contractName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBytecode = bytecode.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            validationMessage = "Please enter a contract name"
            showingValidationAlert = true
            return false
        }
        
        if trimmedBytecode.isEmpty {
            validationMessage = "Bytecode cannot be empty"
            showingValidationAlert = true
            return false
        }
        
        if bytecodeValidationError != nil {
            validationMessage = bytecodeValidationError ?? "Invalid bytecode format"
            showingValidationAlert = true
            return false
        }
        
        if selectedEndpoint == nil {
            validationMessage = "Please select an endpoint"
            showingValidationAlert = true
            return false
        }
        
        return true
    }
}

// MARK: - Preview

#Preview("Bytecode Deployment Sheet") {
    @Previewable @State var bytecode = "0x608060405234801561001057600080fd5b5060405161012c38038061012c83398101604081905261002f91610054565b600055610084565b634e487b7160e01b600052604160045260246000fd5b60006020828403121561006657600080fd5b815160208201519092506001600160401b038082111561008557600080fd5b818401915084601f83011261009957600080fd5b8151818111156100ab576100ab61003e565b604051601f8201601f19908116603f011681019083821181831017156100d3576100d361003e565b816040528281528760208487010111156100ec57600080fd5b826020860160208301376000602084830101528095505050505050509250929050565b60a58061011a6000396000f3fe6080604052348015600f57600080fd5b506004361060325760003560e01c80632e64cec11460375780636057361d146051575b600080fd5b603d6069565b6040516048919060a0565b60405180910390f35b6067605c3660046084565b600055565b005b60005481565b60208101819052600090815260409020805460ff19166001179055565b60006020828403121560a057600080fd5b503591905056fea2646970667358221220"
    @Previewable @State var contractName = "MyContract"
    
    BytecodeDeploymentSheet(
        bytecode: $bytecode,
        contractName: $contractName,
        viewModel: {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try! ModelContainer(
                for: Endpoint.self, EVMContract.self, EvmAbi.self, EVMWallet.self,
                configurations: config
            )
            
            // Add sample endpoint
            let endpoint = Endpoint(
                name: "Anvil Local",
                url: "http://127.0.0.1:8545",
                chainId: "31337"
            )
            container.mainContext.insert(endpoint)
            
            // Add sample ABI
            let sampleAbi = EvmAbi(
                name: "Sample ABI",
                abiContent: "[{\"inputs\":[],\"name\":\"getValue\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"}]"
            )
            container.mainContext.insert(sampleAbi)
            
            // Create mock wallet
            let mockWallet = EVMWallet(
                alias: "Test Wallet",
                address: "0x1234567890123456789012345678901234567890",
                keychainPath: "test_wallet"
            )
            container.mainContext.insert(mockWallet)
            
            let walletSigner = WalletSignerViewModel(
                currentWallet: mockWallet
            )
            walletSigner.modelContext = container.mainContext
            
            return ContractDeploymentViewModel(
                modelContext: container.mainContext,
                walletSigner: walletSigner
            )
        }()
    )
    .modelContainer({
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Endpoint.self, EVMContract.self, EvmAbi.self, EVMWallet.self,
            configurations: config
        )
        
        // Add sample endpoint
        let endpoint = Endpoint(
            name: "Anvil Local",
            url: "http://127.0.0.1:8545",
            chainId: "31337"
        )
        container.mainContext.insert(endpoint)
        
        // Add sample ABI
        let sampleAbi = EvmAbi(
            name: "Sample ABI",
            abiContent: "[{\"inputs\":[],\"name\":\"getValue\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"}]"
        )
        container.mainContext.insert(sampleAbi)
        
        return container
    }())
}
