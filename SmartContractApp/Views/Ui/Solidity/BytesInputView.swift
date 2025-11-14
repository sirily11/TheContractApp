//
//  BytesInputView.swift
//  SmartContractApp
//
//  Created by Claude on 11/13/25.
//

import EvmCore
import SwiftUI

/// Input view for bytes and bytesN type parameters
struct BytesInputView: View {
    @Binding var parameter: TransactionParameter
    @State private var bytesValue: String = ""
    @State private var validationError: String?
    @FocusState private var isFocused: Bool

    private var fixedSize: Int? {
        if case .bytesN(let size) = parameter.type {
            return size
        }
        return nil
    }

    private var isFixedSize: Bool {
        fixedSize != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Bytes input
            HStack(spacing: 8) {
                TextField("0x...", text: $bytesValue, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
                    .focused($isFocused)
                    .lineLimit(2...4)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.asciiCapable)
                    #endif
                    .onChange(of: bytesValue) { _, newValue in
                        validateAndUpdate(newValue)
                    }

                // Validation indicator
                validationIndicator
            }

            // Error message or byte count
            if let error = validationError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else if !bytesValue.isEmpty {
                HStack {
                    Text(byteCountText)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if let size = fixedSize {
                        Spacer()
                        Text("Required: \(size) bytes")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .onAppear {
            loadValue()
        }
    }

    // MARK: - Validation Indicator

    @ViewBuilder
    private var validationIndicator: some View {
        if bytesValue.isEmpty {
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

    // MARK: - Byte Count Text

    private var byteCountText: String {
        let trimmed = bytesValue.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("0x") else { return "0 bytes" }

        let hexString = String(trimmed.dropFirst(2))
        let byteCount = (hexString.count + 1) / 2 // Round up for odd number of hex chars

        return "\(byteCount) byte\(byteCount == 1 ? "" : "s")"
    }

    // MARK: - Validation

    private func validateAndUpdate(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            validationError = nil
            parameter.value = AnyCodable("0x")
            return
        }

        // Check if it starts with 0x
        guard trimmed.hasPrefix("0x") else {
            validationError = "Bytes must start with '0x'"
            return
        }

        // Get hex part
        let hexString = String(trimmed.dropFirst(2))

        // Validate hex characters
        let hexCharacters = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        guard hexString.unicodeScalars.allSatisfy({ hexCharacters.contains($0) }) else {
            validationError = "Invalid hex characters"
            return
        }

        // Check for fixed size
        if let requiredSize = fixedSize {
            let byteCount = (hexString.count + 1) / 2

            if byteCount > requiredSize {
                validationError = "Too many bytes (max \(requiredSize))"
                return
            } else if byteCount < requiredSize {
                validationError = "Too few bytes (need \(requiredSize))"
                return
            }

            // For fixed size, ensure even number of hex chars
            if hexString.count != requiredSize * 2 {
                validationError = "Incomplete byte (need \(requiredSize * 2) hex chars)"
                return
            }
        }

        // Valid bytes
        validationError = nil
        parameter.value = AnyCodable(trimmed)
    }

    // MARK: - Value Loading

    private func loadValue() {
        if let string = parameter.value.value as? String {
            bytesValue = string
            validateAndUpdate(string)
        } else {
            bytesValue = "0x"
            validationError = nil
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        BytesInputView(
            parameter: .constant(
                TransactionParameter(
                    name: "data",
                    type: .bytes,
                    value: .init("0x1234abcd")
                )
            )
        )

        BytesInputView(
            parameter: .constant(
                TransactionParameter(
                    name: "hash",
                    type: .bytesN(32),
                    value: .init("0x0000000000000000000000000000000000000000000000000000000000000000")
                )
            )
        )

        BytesInputView(
            parameter: .constant(
                TransactionParameter(
                    name: "signature",
                    type: .bytesN(65),
                    value: .init("0x")
                )
            )
        )

        BytesInputView(
            parameter: .constant(
                TransactionParameter(
                    name: "small",
                    type: .bytesN(4),
                    value: .init("0x12345678")
                )
            )
        )
    }
    .padding()
    .frame(width: 500)
}
