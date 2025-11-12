//
//  AbiSelectionSheet.swift
//  SmartContractApp
//
//  Created by Kiro on 11/12/25.
//

import SwiftData
import SwiftUI

struct AbiSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - State Properties
    
    @State private var abiName: String = ""
    @State private var abiJson: String = ""
    @State private var validationError: String?
    @State private var showingValidationAlert = false
    
    // MARK: - Callback
    
    var onSave: (EvmAbi) -> Void
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                abiDetailsSection
                abiJsonSection
            }
            .formStyle(.grouped)
            .navigationTitle("Add New ABI")
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
                    Button("Save") {
                        saveAbi()
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
                    Button("Save") {
                        saveAbi()
                    }
                    .disabled(!isFormValid)
                }
                #endif
            }
            .alert("Validation Error", isPresented: $showingValidationAlert) {
                Button("OK") {}
            } message: {
                Text(validationError ?? "Unknown error")
            }
        }
    }
    
    // MARK: - View Sections
    
    private var abiDetailsSection: some View {
        Section(header: Text("ABI Details")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("ABI Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Enter ABI name", text: $abiName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                #if os(iOS)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                #endif
                
                if abiName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !abiName.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text("ABI name is required")
                            .font(.caption2)
                    }
                    .foregroundColor(.orange)
                }
            }
        }
    }
    
    private var abiJsonSection: some View {
        Section(header: Text("ABI JSON")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("ABI Content")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                #if os(macOS)
                TextEditor(text: $abiJson)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200, maxHeight: 400)
                    .border(Color.gray.opacity(0.3), width: 1)
                #else
                TextEditor(text: $abiJson)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200, maxHeight: 400)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                #endif
                
                Text("Enter the ABI as a JSON array")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if let error = validationError {
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
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        !abiName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !abiJson.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Actions
    
    private func saveAbi() {
        let trimmedName = abiName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedJson = abiJson.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate ABI JSON format
        guard let data = trimmedJson.data(using: .utf8) else {
            validationError = "Invalid JSON encoding"
            showingValidationAlert = true
            return
        }
        
        do {
            // Try to parse as JSON array
            _ = try JSONSerialization.jsonObject(with: data, options: [])
            
            // Create new ABI
            let newAbi = EvmAbi(
                name: trimmedName,
                abiContent: trimmedJson
            )
            modelContext.insert(newAbi)
            
            try modelContext.save()
            
            // Call completion handler
            onSave(newAbi)
            
            // Dismiss sheet
            dismiss()
        } catch {
            validationError = "Invalid ABI JSON format: \(error.localizedDescription)"
            showingValidationAlert = true
        }
    }
}

// MARK: - Preview

#Preview("ABI Selection Sheet") {
    AbiSelectionSheet(onSave: { abi in
        print("Created ABI: \(abi.name)")
    })
    .modelContainer({
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: EvmAbi.self,
            configurations: config
        )
        return container
    }())
}
