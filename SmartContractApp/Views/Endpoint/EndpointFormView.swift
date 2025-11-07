//
//  EndpointFormView.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/7/25.
//

import EvmCore
import SwiftData
import SwiftUI

enum EndpointError: LocalizedError {
    case invalidUrl
    case chainIdDetectionFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidUrl:
            return "The provided URL is not valid."
        case .chainIdDetectionFailed:
            return "Failed to detect chain ID from the endpoint."
        }
    }
}

struct EndpointFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Form state
    @State private var name: String = ""
    @State private var url: String = ""
    @State private var chainId: String = ""
    @State private var isAutoDetectingChainId: Bool = false
    @State private var isDetectingChainId: Bool = false
    @State private var detectedChainId: String = ""
    @State private var detectionError: String = ""
    
    // Validation states
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    
    // Edit mode
    private let endpoint: Endpoint?
    private var isEditing: Bool { endpoint != nil }
    
    init(endpoint: Endpoint? = nil) {
        self.endpoint = endpoint
    }
    
    var body: some View {
        Form {
            Section(header: Text("Endpoint Details")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Enter endpoint name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                    
                VStack(alignment: .leading, spacing: 8) {
                    Text("URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Endpoint URL", text: $url)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    #if os(iOS)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    #endif
                        .onChange(of: url) { _, newValue in
                            // Auto-detect chain ID when URL changes and auto-detect is enabled
                            if isAutoDetectingChainId && !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                // Debounce the detection to avoid too many requests
                                Task {
                                    try await Task.sleep(for: .milliseconds(500))
                                    if url == newValue { // Make sure URL hasn't changed during the delay
                                        await MainActor.run {
                                            detectChainId()
                                        }
                                    }
                                }
                            } else if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                // Clear detection results when URL is empty
                                detectedChainId = ""
                                detectionError = ""
                            }
                        }
                }
            }
            
            Section("Chain ID") {
                HStack {
                    Toggle("Auto-detect", isOn: $isAutoDetectingChainId)
                    Spacer()
                }
                .onChange(of: isAutoDetectingChainId) { _, newValue in
                    if newValue && !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        // Start detection when auto-detect is enabled and URL is available
                        detectChainId()
                    } else if !newValue {
                        // Clear detection results when auto-detect is disabled
                        detectedChainId = ""
                        detectionError = ""
                    }
                }
                
                if !isAutoDetectingChainId {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Chain ID")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("1, 137, 56, etc.", text: $chainId)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        #if os(iOS)
                            .keyboardType(.numberPad)
                        #endif
                    }
                } else {
                    // Auto-detect section
                    if isDetectingChainId {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Detecting chain ID...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    } else if !detectedChainId.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Detected Chain ID:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(detectedChainId)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }
                            
                            Button("Detect Again") {
                                detectChainId()
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    } else if !detectionError.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Detection failed")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Spacer()
                            }
                            
                            Text(detectionError)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                            
                            Button("Try Again") {
                                detectChainId()
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    } else if url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HStack {
                            Text("Enter URL first to detect chain ID")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                            Spacer()
                        }
                    } else {
                        Button("Detect Chain ID") {
                            detectChainId()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
            }
                
            if isEditing {
                Section(header: Text("Metadata")) {
                    if let endpoint = endpoint {
                        HStack {
                            Text("Created:")
                            Spacer()
                            Text(endpoint.createdAt, style: .date)
                                .foregroundColor(.secondary)
                        }
                            
                        HStack {
                            Text("Updated:")
                            Spacer()
                            Text(endpoint.updatedAt, style: .date)
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
            .toolbar {
                #if os(iOS)
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(isEditing ? "Update" : "Create") {
                            saveEndpoint()
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
                            saveEndpoint()
                        }
                        .disabled(!isFormValid)
                    }
                #endif
            }
            .onAppear {
                if let endpoint = endpoint {
                    loadEndpoint(endpoint)
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
            !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            (isAutoDetectingChainId ? !detectedChainId.isEmpty : !chainId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    
    private func loadEndpoint(_ endpoint: Endpoint) {
        name = endpoint.name
        url = endpoint.url
        chainId = endpoint.chainId
        isAutoDetectingChainId = endpoint.autoDetectChainId
    }
    
    private func saveEndpoint() {
        Task {
            do {
                try await performSave()
            } catch {
                await MainActor.run {
                    validationMessage = "Failed to save endpoint: \(error.localizedDescription)"
                    showingValidationAlert = true
                }
            }
        }
    }
    
    private func performSave() async throws {
        // Validate form (skip chain ID validation if auto-detecting)
        guard await validateFormAsync(skipChainId: isAutoDetectingChainId) else { return }
        
        var finalChainId: String
        
        if isAutoDetectingChainId {
            // Use the already detected chain ID
            finalChainId = detectedChainId
        } else {
            finalChainId = await MainActor.run { chainId.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        
        await MainActor.run {
            if let existingEndpoint = endpoint {
                // Update existing endpoint
                existingEndpoint.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                existingEndpoint.url = url.trimmingCharacters(in: .whitespacesAndNewlines)
                existingEndpoint.chainId = finalChainId
                existingEndpoint.autoDetectChainId = isAutoDetectingChainId
                existingEndpoint.updatedAt = Date()
            } else {
                // Create new endpoint
                let newEndpoint = Endpoint(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    url: url.trimmingCharacters(in: .whitespacesAndNewlines),
                    chainId: finalChainId,
                    autoDetectChainId: isAutoDetectingChainId
                )
                modelContext.insert(newEndpoint)
            }
            
            do {
                try modelContext.save()
                dismiss()
            } catch {
                validationMessage = "Failed to save endpoint: \(error.localizedDescription)"
                showingValidationAlert = true
            }
        }
    }
    
    private func validateFormAsync(skipChainId: Bool = false) async -> Bool {
        let trimmedName = await MainActor.run { name.trimmingCharacters(in: .whitespacesAndNewlines) }
        let trimmedUrl = await MainActor.run { url.trimmingCharacters(in: .whitespacesAndNewlines) }
        let trimmedChainId = await MainActor.run { chainId.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        if trimmedName.isEmpty {
            await MainActor.run {
                validationMessage = "Please enter a name for the endpoint."
                showingValidationAlert = true
            }
            return false
        }
        
        if trimmedUrl.isEmpty {
            await MainActor.run {
                validationMessage = "Please enter a URL for the endpoint."
                showingValidationAlert = true
            }
            return false
        }
        
        // Basic URL validation
        if !trimmedUrl.lowercased().hasPrefix("http://") && !trimmedUrl.lowercased().hasPrefix("https://") {
            await MainActor.run {
                validationMessage = "Please enter a valid URL starting with http:// or https://"
                showingValidationAlert = true
            }
            return false
        }
        
        // Skip chain ID validation if auto-detecting
        if !skipChainId {
            if trimmedChainId.isEmpty {
                await MainActor.run {
                    validationMessage = "Please enter a chain ID."
                    showingValidationAlert = true
                }
                return false
            }
            
            // Validate chain ID is numeric
            if Int(trimmedChainId) == nil {
                await MainActor.run {
                    validationMessage = "Chain ID must be a valid number."
                    showingValidationAlert = true
                }
                return false
            }
        }
        
        return true
    }
    
    private func validateForm(skipChainId: Bool = false) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedChainId = chainId.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            validationMessage = "Please enter a name for the endpoint."
            showingValidationAlert = true
            return false
        }
        
        if trimmedUrl.isEmpty {
            validationMessage = "Please enter a URL for the endpoint."
            showingValidationAlert = true
            return false
        }
        
        // Basic URL validation
        if !trimmedUrl.lowercased().hasPrefix("http://") && !trimmedUrl.lowercased().hasPrefix("https://") {
            validationMessage = "Please enter a valid URL starting with http:// or https://"
            showingValidationAlert = true
            return false
        }
        
        // Skip chain ID validation if auto-detecting
        if !skipChainId {
            if trimmedChainId.isEmpty {
                validationMessage = "Please enter a chain ID."
                showingValidationAlert = true
                return false
            }
            
            // Validate chain ID is numeric
            if Int(trimmedChainId) == nil {
                validationMessage = "Chain ID must be a valid number."
                showingValidationAlert = true
                return false
            }
        }
        
        return true
    }
    
    private func detectChainId() {
        let trimmedUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedUrl.isEmpty else {
            detectionError = "Please enter a URL first"
            return
        }
        
        guard let endpointUrl = URL(string: trimmedUrl) else {
            detectionError = "Invalid URL format"
            return
        }
        
        // Clear previous results
        detectedChainId = ""
        detectionError = ""
        isDetectingChainId = true
        
        Task {
            do {
                let transport = HttpTransport(url: endpointUrl)
                let evmClient = EvmClient(transport: transport)
                let chainIdBigInt = try await evmClient.chainId()
                
                await MainActor.run {
                    detectedChainId = String(chainIdBigInt)
                    detectionError = ""
                    isDetectingChainId = false
                }
            } catch {
                await MainActor.run {
                    detectedChainId = ""
                    detectionError = "Failed to connect to endpoint: \(error.localizedDescription)"
                    isDetectingChainId = false
                }
            }
        }
    }
}

#Preview("Create Mode") {
    EndpointFormView()
        .modelContainer(for: Endpoint.self, inMemory: true)
}

#Preview("Edit Mode") {
    let endpoint = Endpoint(
        name: "Ethereum Mainnet",
        url: "https://eth-mainnet.alchemyapi.io/v2/your-api-key",
        chainId: "1"
    )
    
    return EndpointFormView(endpoint: endpoint)
        .modelContainer(for: Endpoint.self, inMemory: true)
}
