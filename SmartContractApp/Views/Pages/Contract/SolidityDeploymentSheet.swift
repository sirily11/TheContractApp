//
//  SolidityDeploymentSheet.swift
//  SmartContractApp
//
//  Created by Kiro on 11/12/25.
//

import SwiftData
import SwiftUI

// MARK: - Navigation Destination

enum DeploymentDestination: Hashable {
    case compilation
    case success
}

struct SolidityDeploymentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(WalletSignerViewModel.self) private var signerViewModel

    // MARK: - Bindings

    @Binding var sourceCode: String
    @Binding var contractName: String

    // MARK: - Navigation

    @State private var navigationPath = NavigationPath()

    // MARK: - State Properties

    @State private var selectedEndpoint: Endpoint?
    @State private var solidityContractName: String = ""
    @State private var availableContractNames: [String] = []
    @State private var compilationState: TaskState = .idle
    @State private var deploymentState: TaskState = .idle
    @State private var compiledBytecode: String?
    @State private var compiledAbi: String?
    @State private var deployedAddress: String?
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""

    // MARK: - Version Management

    @AppStorage("selectedSolidityVersion") private var selectedVersion: String = "0.8.21"
    @State private var versionManager = SolidityVersionManager.shared

    // MARK: - Query for Endpoints

    @Query(sort: \Endpoint.name) private var endpoints: [Endpoint]

    // MARK: - Dependencies

    let viewModel: ContractDeploymentViewModel
    var onDeploy: ((EVMContract) -> Void)?

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $navigationPath) {
            formReviewPage
                .navigationDestination(for: DeploymentDestination.self) { destination in
                    switch destination {
                    case .compilation:
                        compilationProgressPage
                    case .success:
                        successPage
                    }
                }
        }
        .frame(minWidth: 500)
        .alert("Validation Error", isPresented: $showingValidationAlert) {
            Button("OK") {}
        } message: {
            Text(validationMessage)
        }
    }

    // MARK: - Page 1: Form Review

    private var formReviewPage: some View {
        Form {
            Section("Contract Information") {
                contractDetailsFields
                solidityContractNameFields
                endpointSelectionFields
                versionSelectionFields
            }

            Section("Contract Source Code") {
                SolidityView(content: $sourceCode)
                    .frame(minHeight: 300, maxHeight: 400)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Deploy Solidity Contract")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .task {
                // Load versions when view appears
                await versionManager.fetchVersions()
            }
            .onAppear {
                // Extract contract names when view appears
                availableContractNames = extractContractNames(from: sourceCode)
            }
            .onChange(of: sourceCode) { _, newValue in
                // Update available contracts when source code changes
                availableContractNames = extractContractNames(from: newValue)

                // Reset selection if selected contract is no longer available
                if !solidityContractName.isEmpty && !availableContractNames.contains(solidityContractName) {
                    solidityContractName = ""
                }
            }
            .toolbar {
                #if os(iOS)
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Next") {
                            startCompilationFlow()
                        }
                        .disabled(!isReviewFormValid)
                    }
                #else
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Next") {
                            startCompilationFlow()
                        }
                        .disabled(!isReviewFormValid)
                    }
                #endif
            }
    }

    // MARK: - Page 2: Compilation & Deployment Progress

    private var compilationProgressPage: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Deployment Progress")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 2) {
                    // Step 1: Compile Contract
                    ProgressStepView(
                        title: "Compile Contract",
                        state: compilationState,
                        systemImage: "doc.text"
                    )

                    // Step 2: Deploy to Network
                    ProgressStepView(
                        title: "Deploy to Network",
                        state: deploymentState,
                        systemImage: "network"
                    )
                }

                // Show compilation error details
                if case .failed(let errorMessage) = compilationState {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("Compilation Failed")
                                .font(.headline)
                                .foregroundColor(.red)
                        }

                        Text(errorMessage)
                            .font(.body)
                            .foregroundColor(.primary)
                            .textSelection(.enabled)

                        if errorMessage.contains("not found") {
                            Text("💡 Tip: Make sure the Solidity contract name exactly matches a contract in your source code.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }

                // Show deployment error details
                if case .failed(let errorMessage) = deploymentState {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("Deployment Failed")
                                .font(.headline)
                                .foregroundColor(.red)
                        }

                        Text(errorMessage)
                            .font(.body)
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }

                // Show deployment progress details
                if case .inProgress = deploymentState {
                    VStack(spacing: 8) {
                        Text(deploymentProgressMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("Waiting for transaction confirmation...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
        .navigationTitle("Deploying Contract")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .navigationBarBackButtonHidden(isProcessing)
            .toolbar {
                #if os(iOS)
                    ToolbarItem(placement: .navigationBarLeading) {
                        if !isProcessing {
                            Button("Back") {
                                navigationPath.removeLast()
                            }
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if case .idle = compilationState, case .idle = deploymentState {
                            Button("Deploy") {
                                startDeployment()
                            }
                            .buttonStyle(.borderedProminent)
                        } else if case .failed = compilationState {
                            Button("Back") {
                                resetStates()
                                navigationPath.removeLast()
                            }
                            .buttonStyle(.borderedProminent)
                        } else if case .failed = deploymentState {
                            Button("Retry") {
                                resetStates()
                                startDeployment()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                #else
                    ToolbarItem(placement: .cancellationAction) {
                        if !isProcessing {
                            Button("Back") {
                                navigationPath.removeLast()
                            }
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        if case .idle = compilationState, case .idle = deploymentState {
                            Button("Deploy") {
                                startDeployment()
                            }
                            .buttonStyle(.borderedProminent)
                        } else if case .failed = compilationState {
                            Button("Back") {
                                resetStates()
                                navigationPath.removeLast()
                            }
                            .buttonStyle(.borderedProminent)
                        } else if case .failed = deploymentState {
                            Button("Retry") {
                                resetStates()
                                startDeployment()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                #endif
            }
    }

    // MARK: - Page 3: Success

    private var successPage: some View {
        VStack(spacing: 24) {
            Spacer()

            // Success icon and message
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)

                Text("Deployment Successful!")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Your contract is now deployed")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Contract address
            if let address = deployedAddress {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Contract Address")
                        .font(.headline)

                    HStack {
                        Text(address)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)

                        Spacer()

                        Button(action: {
                            #if os(macOS)
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(address, forType: .string)
                            #else
                                UIPasteboard.general.string = address
                            #endif
                        }) {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(12)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(6)
                }
                .frame(maxWidth: .infinity)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Success")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .navigationBarBackButtonHidden(true)
            .toolbar {
                #if os(iOS)
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("OK") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                #else
                    ToolbarItem(placement: .primaryAction) {
                        Button("OK") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                #endif
            }
    }

    // MARK: - Helper Views

    private var contractDetailsFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Contract Alias")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("Enter contract alias", text: $contractName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            #if os(iOS)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            #endif

            Text("A friendly name for this contract instance")
                .font(.caption2)
                .foregroundColor(.secondary)

            if contractName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text("Contract alias is required")
                        .font(.caption2)
                }
                .foregroundColor(.orange)
            }
        }
    }

    private var solidityContractNameFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Solidity Contract Name")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if !availableContractNames.isEmpty {
                    Text("\(availableContractNames.count) contract\(availableContractNames.count == 1 ? "" : "s") found")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if availableContractNames.isEmpty {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                        .font(.caption)

                    Text("No contracts found in source code")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
                .padding(.vertical, 8)
            } else {
                Picker("Select Contract", selection: $solidityContractName) {
                    Text("Auto-detect (first contract)").tag("")
                    ForEach(availableContractNames, id: \.self) { contractName in
                        Text(contractName).tag(contractName)
                    }
                }
                .pickerStyle(.menu)
            }

            Text("Select which contract to deploy from your Solidity code")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var versionSelectionFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Solidity Version")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if versionManager.isLoadingVersions {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                }
            }

            if versionManager.availableVersions.isEmpty {
                HStack {
                    TextField("Version (e.g., 0.8.21)", text: $selectedVersion)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    #if os(iOS)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    #endif

                    Button {
                        Task {
                            await versionManager.fetchVersions(forceRefresh: true)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                }
            } else {
                HStack {
                    Picker("Select Version", selection: $selectedVersion) {
                        ForEach(versionManager.availableVersions, id: \.self) { version in
                            Text(version).tag(version)
                        }
                    }
                    .pickerStyle(.menu)

                    Button {
                        Task {
                            await versionManager.fetchVersions(forceRefresh: true)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh version list")
                }
            }

            if let error = versionManager.loadingError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text("Failed to load versions: \(error)")
                        .font(.caption2)
                }
                .foregroundColor(.orange)
            }
        }
    }

    private var endpointSelectionFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Endpoint")
                .font(.caption)
                .foregroundColor(.secondary)

            if endpoints.isEmpty {
                Text("No endpoints available")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .leading)
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

    private var deploymentProgressMessage: String {
        switch viewModel.deploymentProgress {
        case .idle:
            return "Preparing deployment..."
        case .compiling:
            return "Compiling contract..."
        case .preparingTransaction:
            return "Preparing transaction..."
        case .signing:
            return "Signing transaction..."
        case .sending:
            return "Sending transaction..."
        case .confirming:
            return "Confirming transaction..."
        case .completed:
            return "Deployment complete!"
        case .failed:
            return "Deployment failed"
        }
    }

    // MARK: - Computed Properties

    private var isProcessing: Bool {
        if case .inProgress = compilationState {
            return true
        }
        if case .inProgress = deploymentState {
            return true
        }
        return false
    }

    private var isReviewFormValid: Bool {
        !contractName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !sourceCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            selectedEndpoint != nil
    }

    // MARK: - Helper Functions

    /// Extract all contract names from Solidity source code using regex
    private func extractContractNames(from source: String) -> [String] {
        // Pattern matches: contract ContractName { or contract ContractName is BaseContract {
        // Captures the contract name in group 1
        let pattern = "contract\\s+(\\w+)\\s*(?:is\\s+[^{]*)?\\s*\\{"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        let nsString = source as NSString
        let results = regex.matches(in: source, options: [], range: NSRange(location: 0, length: nsString.length))

        var contractNames: [String] = []
        for match in results {
            if match.numberOfRanges > 1 {
                let range = match.range(at: 1)
                let contractName = nsString.substring(with: range)
                contractNames.append(contractName)
            }
        }

        return contractNames
    }

    // MARK: - Actions

    private func startCompilationFlow() {
        guard isReviewFormValid else {
            validationMessage = "Please fill in all required fields"
            showingValidationAlert = true
            return
        }

        navigationPath.append(DeploymentDestination.compilation)
    }

    private func resetStates() {
        compilationState = .idle
        deploymentState = .idle
        compiledBytecode = nil
        compiledAbi = nil
    }

    private func startDeployment() {
        // First compile, then deploy
        compileContract()
    }

    private func compileContract() {
        let trimmedSource = sourceCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContractName = solidityContractName.trimmingCharacters(in: .whitespacesAndNewlines)
        let contractNameToUse = trimmedContractName.isEmpty ? nil : trimmedContractName

        compilationState = .inProgress

        Task {
            do {
                // Compile using the view model's internal compilation method with selected version and contract name
                let result = try await viewModel.compileSolidity(
                    trimmedSource,
                    contractName: contractNameToUse,
                    version: selectedVersion
                )

                // Store compilation results
                compiledBytecode = result.bytecode
                compiledAbi = result.abi
                compilationState = .success

                // Automatically proceed to deployment after successful compilation
                deployToNetwork()
            } catch {
                compilationState = .failed(error.localizedDescription)
            }
        }
    }

    private func deployToNetwork() {
        guard let endpoint = selectedEndpoint,
              let bytecode = compiledBytecode,
              let abi = compiledAbi
        else {
            validationMessage = "Missing compilation results"
            showingValidationAlert = true
            return
        }

        let trimmedName = contractName.trimmingCharacters(in: .whitespacesAndNewlines)

        deploymentState = .inProgress

        Task {
            do {
                // Create ABI record
                let abiRecord = EvmAbi(name: "\(trimmedName) ABI", abiContent: abi)
                modelContext.insert(abiRecord)

                // Create contract record
                let contract = EVMContract(
                    name: trimmedName,
                    address: "", // Will be filled after deployment
                    abiId: abiRecord.id,
                    status: .pending,
                    type: .solidity,
                    endpointId: endpoint.id
                )
                contract.sourceCode = sourceCode
                contract.bytecode = bytecode
                contract.abi = abiRecord
                contract.endpoint = endpoint
                modelContext.insert(contract)

                // Deploy bytecode to network
                try await viewModel.deployBytecodeToNetwork(bytecode, endpoint: endpoint)
            } catch {
                deploymentState = .failed(error.localizedDescription)
            }
        }
    }
}

// MARK: - Preview

#Preview("Deployment Sheet") {
    @Previewable @State var sourceCode = """
    // SPDX-License-Identifier: MIT
    pragma solidity ^0.8.0;

    contract SimpleStorage {
        uint256 public value;

        function setValue(uint256 _value) public {
            value = _value;
        }
    }
    """

    @Previewable @State var contractName = "SimpleStorage"

    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Endpoint.self, EVMContract.self, EvmAbi.self,
        configurations: config
    )

    // Add sample endpoint
    let endpoint = Endpoint(
        name: "Anvil Local",
        url: "http://127.0.0.1:8545",
        chainId: "31337"
    )
    container.mainContext.insert(endpoint)

    // Create mock wallet signer
    let mockWallet = EVMWallet(
        alias: "Test Wallet",
        address: "0x1234567890123456789012345678901234567890",
        keychainPath: "test_wallet"
    )
    container.mainContext.insert(mockWallet)

    let walletSigner = WalletSignerViewModel(
        modelContext: container.mainContext,
        currentWallet: mockWallet
    )

    let viewModel = ContractDeploymentViewModel(
        modelContext: container.mainContext,
        walletSigner: walletSigner
    )

    return SolidityDeploymentSheet(
        sourceCode: $sourceCode,
        contractName: $contractName,
        viewModel: viewModel
    )
    .modelContainer(container)
}
