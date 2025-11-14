//
//  AddressInputView.swift
//  SmartContractApp
//
//  Created by Claude on 11/13/25.
//

import EvmCore
import SwiftUI

/// Input view for Ethereum address type parameters
struct AddressInputView: View {
    @Binding var parameter: TransactionParameter
    @State private var addressValue: String = ""
    @State private var validationError: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Address input field
            HStack(spacing: 8) {
                TextField("0x...", text: $addressValue)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .focused($isFocused)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.asciiCapable)
                    #endif
                    .onChange(of: addressValue) { _, newValue in
                        validateAndUpdate(newValue)
                    }

                // Validation indicator
                validationIndicator
            }

            // Error message
            if let error = validationError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            // Display with copy button when valid
            if validationError == nil && !addressValue.isEmpty {
                CopyableView(
                    text: addressValue,
                    style: .compact
                )
            }
        }
        .onAppear {
            loadValue()
        }
    }

    // MARK: - Validation Indicator

    @ViewBuilder
    private var validationIndicator: some View {
        if addressValue.isEmpty {
            Image(systemName: "circle")
                .foregroundColor(.secondary)
                .font(.caption)
        } else if validationError == nil {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
        } else {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.orange)
                .font(.caption)
        }
    }

    // MARK: - Validation

    private func validateAndUpdate(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespaces)

        // Validate address format
        if trimmed.isEmpty {
            validationError = nil
            parameter.value = AnyCodable("")
            return
        }

        // Check if it starts with 0x
        guard trimmed.hasPrefix("0x") else {
            validationError = "Address must start with '0x'"
            return
        }

        // Check length (0x + 40 hex chars = 42 total)
        guard trimmed.count == 42 else {
            if trimmed.count < 42 {
                validationError = "Address too short (need 40 hex characters)"
            } else {
                validationError = "Address too long (need 40 hex characters)"
            }
            return
        }

        // Check if all characters after 0x are valid hex
        let hexPart = String(trimmed.dropFirst(2))
        let hexCharacters = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        guard hexPart.unicodeScalars.allSatisfy({ hexCharacters.contains($0) }) else {
            validationError = "Address contains invalid hex characters"
            return
        }

        // Valid address
        validationError = nil
        parameter.value = AnyCodable(trimmed)
    }

    // MARK: - Value Loading

    private func loadValue() {
        if let string = parameter.value.value as? String {
            addressValue = string
            validateAndUpdate(string)
        } else {
            addressValue = ""
            validationError = nil
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        AddressInputView(
            parameter: .constant(
                TransactionParameter(
                    name: "recipient",
                    type: .address,
                    value: .init("0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")
                )
            )
        )

        AddressInputView(
            parameter: .constant(
                TransactionParameter(
                    name: "contract",
                    type: .address,
                    value: .init("")
                )
            )
        )

        AddressInputView(
            parameter: .constant(
                TransactionParameter(
                    name: "invalid",
                    type: .address,
                    value: .init("0xinvalid")
                )
            )
        )
    }
    .padding()
    .frame(width: 500)
}
