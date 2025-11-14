//
//  SolidityDeploymentSheet+Sections.swift
//  SmartContractApp
//
//  Created by Kiro on 11/12/25.
//

import SwiftUI

// MARK: - View Sections

extension SolidityDeploymentSheet {
    // MARK: - Page 1: Form Review

    var formReviewPage: some View {
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
                ToolbarItem(placement: .primaryAction) {
                    Button("Next") {
                        startCompilationFlow()
                    }
                    .disabled(!isReviewFormValid)
                }
            }
    }

    // MARK: - Page 2: Compilation & Deployment Progress

    var compilationProgressPage: some View {
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
            }
    }

    // MARK: - Page 3: Success

    var successPage: some View {
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
    }

    // MARK: - Form Field Views

    var contractDetailsFields: some View {
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

    var solidityContractNameFields: some View {
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

    var versionSelectionFields: some View {
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

    var endpointSelectionFields: some View {
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
}
