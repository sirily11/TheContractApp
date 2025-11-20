//
//  AIProviderSettingsView.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/20/25.
//

import SwiftData
import SwiftUI

// MARK: - Settings Tab Enum

enum SettingsTab: String, CaseIterable, Identifiable {
    case providers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .providers:
            return "Providers"
        }
    }

    var systemImage: String {
        switch self {
        case .providers:
            return "server.rack"
        }
    }
}

// MARK: - Providers Settings Tab

struct ProvidersSettingsTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AIProvider.name) private var providers: [AIProvider]
    @State private var showingAddSheet = false

    var body: some View {
        NavigationStack {
            Form {
                List {
                    if providers.isEmpty {
                        Text("No model providers configured. Please add one to get started.")
                    }
                    // Provider List
                    ForEach(providers) { provider in
                        NavigationLink {
                            AIProviderFormView(mode: .edit(provider))
                        } label: {
                            HStack {
                                Text(provider.name)
                                    .font(.body)

                                Spacer()
                            }
                            .padding()
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteProvider(provider)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .accessibilityIdentifier(.settings.providerRow(provider.id.uuidString))
                    }
                }
                .navigationTitle("Providers")
                .sheet(isPresented: $showingAddSheet) {
                    NavigationStack {
                        AIProviderFormView(mode: .create)
                    }
                }

                HStack {
                    Spacer()
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("Add a Model Provider...", systemImage: "plus")
                    }
                    .accessibilityIdentifier(.settings.addButton)
                }
            }
            .formStyle(.grouped)
        }
    }

    // MARK: - Actions

    private func deleteProvider(_ provider: AIProvider) {
        modelContext.delete(provider)
    }
}

// MARK: - Provider Form View

enum AIProviderFormMode {
    case create
    case edit(AIProvider)
}

struct AIProviderFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: AIProviderFormMode
    var onSave: ((AIProvider) -> Void)?

    @State private var name: String = ""
    @State private var type: ProviderType = .openAI
    @State private var apiKey: String = ""
    @State private var endpoint: String = ""

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var editingProvider: AIProvider? {
        if case .edit(let provider) = mode { return provider }
        return nil
    }

    var body: some View {
        Form {
            Section("Provider Information") {
                TextField("Name", text: $name)
                    .accessibilityIdentifier(.settings.nameTextField)

                Picker("Type", selection: $type) {
                    ForEach(ProviderType.allCases) { providerType in
                        Text(providerType.displayName).tag(providerType)
                    }
                }
                .accessibilityIdentifier(.settings.typePicker)
                .onChange(of: type) { _, newType in
                    if endpoint.isEmpty || endpoint == ProviderType.openAI.defaultEndpoint {
                        endpoint = newType.defaultEndpoint
                    }
                }
            }

            Section("Configuration") {
                providerConfigurationFields
            }

            HStack {
                Spacer()
                Button(isEditing ? "Save" : "Add") {
                    saveProvider()
                }
                .accessibilityIdentifier(isEditing ? .settings.updateButton : .settings.createButton)
                .disabled(!isFormValid)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(isEditing ? "Edit Provider" : "Add Provider")
        .onAppear {
            if let provider = editingProvider {
                name = provider.name
                type = provider.type
                apiKey = provider.apiKey
                endpoint = provider.endpoint
            } else {
                endpoint = type.defaultEndpoint
            }
        }
    }

    // MARK: - Provider Configuration Fields

    @ViewBuilder
    private var providerConfigurationFields: some View {
        switch type {
        case .openAI:
            SecureField("API Key", text: $apiKey)
                .accessibilityIdentifier(.settings.apiKeyField)

            TextField("Endpoint", text: $endpoint)
                .accessibilityIdentifier(.settings.endpointTextField)

            Text("Default: \(ProviderType.openAI.defaultEndpoint)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    private func saveProvider() {
        if let provider = editingProvider {
            // Update existing
            provider.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            provider.type = type
            provider.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            provider.endpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
            provider.updatedAt = Date()
        } else {
            // Create new
            let newProvider = AIProvider(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                type: type,
                apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
                endpoint: endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            modelContext.insert(newProvider)
            onSave?(newProvider)
            dismiss()
        }
    }
}

#Preview("Settings View") {
    let container = try! ModelContainer(
        for: AIProvider.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    // Add sample provider
    let provider = AIProvider(
        name: "My OpenAI",
        type: .openAI,
        apiKey: "sk-test-key",
        endpoint: "https://api.openai.com/v1"
    )
    container.mainContext.insert(provider)

    return SettingsPage()
        .modelContainer(container)
}

#Preview("Add Provider") {
    let container = try! ModelContainer(
        for: AIProvider.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    return NavigationStack {
        AIProviderFormView(mode: .create)
    }
    .modelContainer(container)
}
