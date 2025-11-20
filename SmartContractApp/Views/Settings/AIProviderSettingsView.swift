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
    @State private var autoFetchModels: Bool = true
    @State private var availableModels: [String] = []
    @State private var isFetchingModels: Bool = false
    @State private var fetchError: String?

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
                .onChange(of: type) { oldType, newType in
                    // Update endpoint when type changes
                    if endpoint.isEmpty || endpoint == oldType.defaultEndpoint {
                        endpoint = newType.defaultEndpoint
                    }
                    // Clear models when type changes
                    availableModels = []
                    fetchError = nil
                }
            }

            Section("Configuration") {
                providerConfigurationFields
            }

            Section("Models") {
                modelsSection
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
                autoFetchModels = provider.autoFetchModels
                availableModels = provider.availableModels
            } else {
                endpoint = type.defaultEndpoint
            }
        }
    }

    // MARK: - Provider Configuration Fields

    @ViewBuilder
    private var providerConfigurationFields: some View {
        SecureField("API Key", text: $apiKey)
            .accessibilityIdentifier(.settings.apiKeyField)

        if type.supportsCustomEndpoint {
            TextField("Endpoint", text: $endpoint)
                .accessibilityIdentifier(.settings.endpointTextField)

            Text("Default: \(type.defaultEndpoint)")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            LabeledContent("Endpoint") {
                Text(type.defaultEndpoint)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Models Section

    @ViewBuilder
    private var modelsSection: some View {
        if type.supportsAutoFetchModels {
            Toggle("Auto-fetch models", isOn: $autoFetchModels)
                .accessibilityIdentifier(.settings.autoFetchToggle)

            HStack {
                Button {
                    Task {
                        await fetchModels()
                    }
                } label: {
                    if isFetchingModels {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("Fetch Models")
                    }
                }
                .disabled(apiKey.isEmpty || isFetchingModels)
                .accessibilityIdentifier(.settings.fetchModelsButton)

                if !availableModels.isEmpty {
                    Spacer()
                    Text("\(availableModels.count) models")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }

            if let error = fetchError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            if !availableModels.isEmpty {
                DisclosureGroup("Available Models (\(availableModels.count))") {
                    ForEach(availableModels, id: \.self) { model in
                        Text(model)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } else {
            Text("Models will be configured manually")
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }

    // MARK: - Fetch Models

    private func fetchModels() async {
        isFetchingModels = true
        fetchError = nil

        do {
            let effectiveEndpoint = type.supportsCustomEndpoint ? endpoint : type.defaultEndpoint
            let models = try await ModelFetchService.shared.fetchModels(
                providerType: type,
                endpoint: effectiveEndpoint,
                apiKey: apiKey
            )
            await MainActor.run {
                availableModels = models
                isFetchingModels = false
            }
        } catch {
            await MainActor.run {
                fetchError = error.localizedDescription
                isFetchingModels = false
            }
        }
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        let hasName = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasApiKey = !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if type.supportsCustomEndpoint {
            return hasName && hasApiKey
                && !endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            return hasName && hasApiKey
        }
    }

    // MARK: - Actions

    private func saveProvider() {
        let effectiveEndpoint =
            type.supportsCustomEndpoint
            ? endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
            : type.defaultEndpoint

        if let provider = editingProvider {
            // Update existing
            provider.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            provider.type = type
            provider.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            provider.endpoint = effectiveEndpoint
            provider.autoFetchModels = autoFetchModels
            provider.availableModels = availableModels
            provider.updatedAt = Date()
        } else {
            // Create new
            let newProvider = AIProvider(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                type: type,
                apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
                endpoint: effectiveEndpoint,
                availableModels: availableModels,
                autoFetchModels: autoFetchModels
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
