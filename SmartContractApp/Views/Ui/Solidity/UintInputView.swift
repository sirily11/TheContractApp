//
//  UintInputView.swift
//  SmartContractApp
//
//  Created by Claude on 11/13/25.
//

import EvmCore
import SwiftUI
import BigInt

/// Input view for unsigned integer type parameters with base selection
struct UintInputView: View {
    @Binding var parameter: TransactionParameter
    @State private var inputValue: String = ""
    @State private var base: NumberBase = .decimal
    @State private var validationError: String?
    @FocusState private var isFocused: Bool

    private var bitSize: Int {
        if case .uint(let size) = parameter.type {
            return size
        }
        return 256 // Default
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Base selector
            Picker("Base", selection: $base) {
                Text("Decimal").tag(NumberBase.decimal)
                Text("Hexadecimal").tag(NumberBase.hexadecimal)
            }
            .pickerStyle(.segmented)
            .onChange(of: base) { oldValue, newValue in
                convertBase(from: oldValue, to: newValue)
            }

            // Number input
            HStack(spacing: 8) {
                TextField(base == .decimal ? "0" : "0x0", text: $inputValue)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .focused($isFocused)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(base == .decimal ? .numberPad : .asciiCapable)
                    #endif
                    .onChange(of: inputValue) { _, newValue in
                        validateAndUpdate(newValue)
                    }

                // Validation indicator
                validationIndicator
            }

            // Error message or bit size info
            if let error = validationError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else if !inputValue.isEmpty {
                Text("uint\(bitSize) • max: \(maxValueString)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            loadValue()
        }
    }

    // MARK: - Validation Indicator

    @ViewBuilder
    private var validationIndicator: some View {
        if inputValue.isEmpty {
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

    // MARK: - Max Value String

    private var maxValueString: String {
        let maxValue = BigUInt(2).power(bitSize) - 1
        if base == .decimal {
            return maxValue.description
        } else {
            return "0x" + String(maxValue, radix: 16)
        }
    }

    // MARK: - Validation

    private func validateAndUpdate(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            validationError = nil
            parameter.value = AnyCodable("0")
            return
        }

        // Parse based on selected base
        let parsedValue: BigUInt?

        switch base {
        case .decimal:
            // Validate decimal format
            guard trimmed.allSatisfy({ $0.isNumber }) else {
                validationError = "Invalid decimal number"
                return
            }
            parsedValue = BigUInt(trimmed, radix: 10)

        case .hexadecimal:
            // Remove 0x prefix if present
            let hexString = trimmed.hasPrefix("0x") ? String(trimmed.dropFirst(2)) : trimmed

            // Validate hex format
            let hexCharacters = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
            guard hexString.unicodeScalars.allSatisfy({ hexCharacters.contains($0) }) else {
                validationError = "Invalid hexadecimal number"
                return
            }

            parsedValue = BigUInt(hexString, radix: 16)
        }

        guard let value = parsedValue else {
            validationError = "Invalid number format"
            return
        }

        // Check range for bit size
        let maxValue = BigUInt(2).power(bitSize) - 1
        if value > maxValue {
            validationError = "Value exceeds uint\(bitSize) maximum"
            return
        }

        // Valid input
        validationError = nil
        parameter.value = AnyCodable(value.description)
    }

    // MARK: - Base Conversion

    private func convertBase(from oldBase: NumberBase, to newBase: NumberBase) {
        guard !inputValue.isEmpty else { return }

        // Parse current value
        let trimmed = inputValue.trimmingCharacters(in: .whitespaces)
        let parsedValue: BigUInt?

        switch oldBase {
        case .decimal:
            parsedValue = BigUInt(trimmed, radix: 10)
        case .hexadecimal:
            let hexString = trimmed.hasPrefix("0x") ? String(trimmed.dropFirst(2)) : trimmed
            parsedValue = BigUInt(hexString, radix: 16)
        }

        guard let value = parsedValue else { return }

        // Convert to new base
        switch newBase {
        case .decimal:
            inputValue = value.description
        case .hexadecimal:
            inputValue = "0x" + String(value, radix: 16)
        }

        validateAndUpdate(inputValue)
    }

    // MARK: - Value Loading

    private func loadValue() {
        if let string = parameter.value.value as? String {
            // Try to parse as decimal first
            if let _ = BigUInt(string, radix: 10) {
                base = .decimal
                inputValue = string
            } else if string.hasPrefix("0x"), let value = BigUInt(String(string.dropFirst(2)), radix: 16) {
                base = .hexadecimal
                inputValue = string
            } else {
                inputValue = "0"
            }
        } else if let number = parameter.value.value as? Int {
            base = .decimal
            inputValue = String(number)
        } else {
            inputValue = "0"
        }
        validateAndUpdate(inputValue)
    }
}

// MARK: - Number Base Enum

enum NumberBase {
    case decimal
    case hexadecimal
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        UintInputView(
            parameter: .constant(
                TransactionParameter(
                    name: "amount",
                    type: .uint(256),
                    value: .init("1000000000000000000")
                )
            )
        )

        UintInputView(
            parameter: .constant(
                TransactionParameter(
                    name: "tokenId",
                    type: .uint(128),
                    value: .init("0x1234")
                )
            )
        )

        UintInputView(
            parameter: .constant(
                TransactionParameter(
                    name: "count",
                    type: .uint(8),
                    value: .init("255")
                )
            )
        )
    }
    .padding()
    .frame(width: 500)
}
