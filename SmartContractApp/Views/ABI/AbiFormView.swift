//
//  AbiFormView.swift
//  SmartContractApp
//
//  Created by Claude on 11/7/25.
//

import AppKit
import EvmCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

enum AbiError: LocalizedError {
    case invalidJson
    case parsingFailed(String)
    case fileReadFailed

    var errorDescription: String? {
        switch self {
        case .invalidJson:
            return "The provided JSON is not valid."
        case .parsingFailed(let message):
            return "Failed to parse ABI: \(message)"
        case .fileReadFailed:
            return "Failed to read the selected file."
        }
    }
}

struct AbiFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var name: String = ""
    @State private var abiContent: String = ""
    @State private var validationStatus: ValidationStatus = .notValidated
    @State private var validationMessage: String = ""
    @State private var parsedParser: AbiParser?

    // Input method
    @State private var inputMethod: InputMethod = .file
    @State private var selectedFileURL: URL?
    @State private var selectedFileName: String = ""

    // URL download
    @State private var remoteUrl: String = ""
    @State private var isDownloading: Bool = false
    @State private var downloadError: String = ""

    // File import
    @State private var showingFileImporter = false

    // Validation states
    @State private var showingValidationAlert = false

    // Stepper state
    @State private var currentStep: Int = 1

    // Edit mode
    private let abi: EvmAbi?
    private var isEditing: Bool { abi != nil }

    init(abi: EvmAbi? = nil) {
        self.abi = abi
    }

    enum InputMethod: String, CaseIterable, Identifiable {
        case file = "Select File"
        case url = "Download from URL"
        case paste = "Paste JSON"

        var id: String { rawValue }
    }

    enum ValidationStatus {
        case notValidated
        case validating
        case valid
        case invalid
    }

    var body: some View {
        VStack(spacing: 0) {
            if currentStep == 1 {
                formView
            } else {
                previewView
            }
        }
        .frame(minWidth: 700, minHeight: 400)
    }

    var formView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(isEditing ? "Edit ABI" : "Create ABI")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.horizontal)
                .padding(.top)

            Form {
                Section(header: Text("ABI Details")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter ABI name (e.g., ERC20 Token)", text: $name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }

                Section(header: Text("ABI Content")) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Input method selector
                        Picker("Input Method", selection: $inputMethod) {
                            ForEach(InputMethod.allCases) { method in
                                Text(method.rawValue).tag(method)
                            }
                        }
                        .pickerStyle(.segmented)

                        // Conditional content based on input method
                        if inputMethod == .file {
                            // File picker mode
                            HStack {
                                Text(selectedFileName.isEmpty ? "No file selected" : selectedFileName)
                                    .foregroundColor(.primary)
                                Spacer()
                                Button(action: {
                                    showingFileImporter = true
                                }) {
                                    Text("Upload")
                                }
                                .buttonStyle(.bordered)
                            }
                        } else if inputMethod == .url {
                            // URL download mode
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Remote ABI URL")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                HStack(spacing: 8) {
                                    TextField("Enter URL (e.g., https://example.com/abi.json)", text: $remoteUrl)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .disabled(isDownloading)

                                    Button(action: {
                                        downloadAbiFromUrl()
                                    }) {
                                        if isDownloading {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                                .frame(width: 16, height: 16)
                                        } else {
                                            Text("Download")
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .fixedSize()
                                    .disabled(remoteUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isDownloading)
                                }

                                if !downloadError.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                        Text(downloadError)
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }

                                if !selectedFileName.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text("Downloaded: \(selectedFileName)")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        } else {
                            // Paste mode
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Paste JSON ABI")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                JsonView(content: $abiContent)
                                    .frame(minHeight: 300)
                                    .onChange(of: abiContent) { _, _ in
                                        validateAbi()
                                    }
                            }
                        }

                        // Validation status
                        HStack(spacing: 8) {
                            switch validationStatus {
                            case .notValidated:
                                EmptyView()

                            case .validating:
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Validating...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                            case .valid:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Valid ABI")
                                    .font(.caption)
                                    .foregroundColor(.green)

                            case .invalid:
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(validationMessage)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            Spacer()
                        }
                    }
                }

                if isEditing {
                    Section(header: Text("Metadata")) {
                        if let abi = abi {
                            HStack {
                                Text("Created:")
                                Spacer()
                                Text(abi.createdAt, style: .date)
                                    .foregroundColor(.secondary)
                            }

                            HStack {
                                Text("Updated:")
                                Spacer()
                                Text(abi.updatedAt, style: .date)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .padding()
        }
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
                if isFormValid {
                    Button("Next") {
                        withAnimation {
                            currentStep = 2
                        }
                    }
                }
            }
#else
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button("Next") {
                    withAnimation {
                        currentStep = 2
                    }
                }
                .disabled(!isFormValid)
            }
#endif
        }
        .onAppear {
            if let abi = abi {
                loadAbi(abi)
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .alert("Validation Error", isPresented: $showingValidationAlert) {
            Button("OK") {}
        } message: {
            Text(validationMessage)
        }
    }

    var previewView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Preview")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.horizontal)
                .padding(.top)

            if let parser = parsedParser {
                ScrollView {
                    AbiPreviewView(parser: parser)
                        .padding()
                }
            } else {
                VStack {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    Text("Preview is not available.")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        withAnimation {
                            currentStep = 1
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Update" : "Create") {
                        saveAbi()
                    }
                }
#else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") {
                        withAnimation {
                            currentStep = 1
                        }
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(isEditing ? "Update" : "Create") {
                        saveAbi()
                    }
                }
#endif
            }
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !abiContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            validationStatus == .valid
    }

    private func loadAbi(_ abi: EvmAbi) {
        name = abi.name
        abiContent = abi.abiContent

        // Restore the input method based on what was used originally
        if let sourceUrl = abi.sourceUrl, !sourceUrl.isEmpty {
            inputMethod = .url
            remoteUrl = sourceUrl
            selectedFileName = abi.sourceFileName ?? ""
        } else if let fileName = abi.sourceFileName, !fileName.isEmpty {
            inputMethod = .file
            selectedFileName = fileName
        } else {
            inputMethod = .paste
        }

        validateAbi()
    }

    private func validateAbi() {
        let trimmedContent = abiContent.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedContent.isEmpty else {
            validationStatus = .notValidated
            parsedParser = nil
            return
        }

        validationStatus = .validating

        // Use a slight delay to avoid validating on every keystroke
        Task {
            try await Task.sleep(for: .milliseconds(300))

            await MainActor.run {
                do {
                    let parser = try AbiParser(fromJsonString: trimmedContent)
                    validationStatus = .valid
                    parsedParser = parser
                    validationMessage = ""
                } catch {
                    validationStatus = .invalid
                    parsedParser = nil
                    validationMessage = error.localizedDescription
                }
            }
        }
    }

    private func downloadAbiFromUrl() {
        let trimmedUrl = remoteUrl.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedUrl.isEmpty else {
            downloadError = "Please enter a URL"
            return
        }

        guard let url = URL(string: trimmedUrl) else {
            downloadError = "Invalid URL format"
            return
        }

        isDownloading = true
        downloadError = ""

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse else {
                    await MainActor.run {
                        downloadError = "Invalid response from server"
                        isDownloading = false
                    }
                    return
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    await MainActor.run {
                        downloadError = "Server returned error: \(httpResponse.statusCode)"
                        isDownloading = false
                    }
                    return
                }

                guard let content = String(data: data, encoding: .utf8) else {
                    await MainActor.run {
                        downloadError = "Failed to decode response as UTF-8"
                        isDownloading = false
                    }
                    return
                }

                await MainActor.run {
                    abiContent = content
                    selectedFileName = url.lastPathComponent
                    isDownloading = false
                    validateAbi()
                }
            } catch {
                await MainActor.run {
                    downloadError = "Download failed: \(error.localizedDescription)"
                    isDownloading = false
                }
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                validationMessage = "Failed to access file."
                showingValidationAlert = true
                return
            }

            defer {
                url.stopAccessingSecurityScopedResource()
            }

            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                abiContent = content
                selectedFileURL = url
                selectedFileName = url.lastPathComponent
                // Explicitly call validateAbi since onChange is only on TextEditor
                validateAbi()
            } catch {
                validationMessage = "Failed to read file: \(error.localizedDescription)"
                showingValidationAlert = true
            }

        case .failure(let error):
            validationMessage = "File import failed: \(error.localizedDescription)"
            showingValidationAlert = true
        }
    }

    private func saveAbi() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = abiContent.trimmingCharacters(in: .whitespacesAndNewlines)

        // Final validation
        guard !trimmedName.isEmpty else {
            validationMessage = "Please enter a name for the ABI."
            showingValidationAlert = true
            return
        }

        guard !trimmedContent.isEmpty else {
            validationMessage = "Please enter the ABI content."
            showingValidationAlert = true
            return
        }

        guard validationStatus == .valid else {
            validationMessage = "Please ensure the ABI is valid before saving."
            showingValidationAlert = true
            return
        }

        // Determine source URL and filename based on input method
        let sourceUrl: String?
        let sourceFileName: String?

        switch inputMethod {
        case .url:
            sourceUrl = remoteUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            sourceFileName = selectedFileName.isEmpty ? nil : selectedFileName
        case .file:
            sourceUrl = nil
            sourceFileName = selectedFileName.isEmpty ? nil : selectedFileName
        case .paste:
            sourceUrl = nil
            sourceFileName = nil
        }

        if let existingAbi = abi {
            // Update existing ABI
            existingAbi.name = trimmedName
            existingAbi.abiContent = trimmedContent
            existingAbi.sourceUrl = sourceUrl
            existingAbi.sourceFileName = sourceFileName
            existingAbi.updatedAt = Date()
        } else {
            // Create new ABI
            let newAbi = EvmAbi(
                name: trimmedName,
                abiContent: trimmedContent,
                sourceUrl: sourceUrl,
                sourceFileName: sourceFileName
            )
            modelContext.insert(newAbi)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            validationMessage = "Failed to save ABI: \(error.localizedDescription)"
            showingValidationAlert = true
        }
    }
}

#Preview("Create Mode") {
    AbiFormView()
        .modelContainer(for: EvmAbi.self, inMemory: true)
}

#Preview("Edit Mode") {
    let sampleAbi = """
    [
        {
            "type": "function",
            "name": "transfer",
            "inputs": [
                {"name": "to", "type": "address"},
                {"name": "amount", "type": "uint256"}
            ],
            "outputs": [{"name": "", "type": "bool"}],
            "stateMutability": "nonpayable"
        }
    ]
    """

    let abi = EvmAbi(
        name: "ERC20 Token",
        abiContent: sampleAbi
    )

    return AbiFormView(abi: abi)
        .modelContainer(for: EvmAbi.self, inMemory: true)
}
