//
//  IntInputView.swift
//  SmartContractApp
//
//  Created by Claude on 11/13/25.
//

import EvmCore
import SwiftUI
import BigInt

/// Input view for signed integer type parameters with base selection
struct IntInputView: View {
    @Binding var parameter: TransactionParameter
    @State private var inputValue: String = ""
    @State private var base: NumberBase = .decimal
    @State private var validationError: String?
    @FocusState private var isFocused: Bool

    private var bitSize: Int {
        if case .int(let size) = parameter.type {
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
                    .keyboardType(base == .decimal ? .numbersAndPunctuation : .asciiCapable)
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
                Text("int\(bitSize) • range: \(minValueString) to \(maxValueString)")
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

    // MARK: - Range Strings

    private var minValueString: String {
        let minValue = -BigInt(2).power(bitSize - 1)
        if base == .decimal {
            return minValue.description
        } else {
            return minValue < 0 ? "-0x" + String((-minValue).magnitude, radix: 16) : "0x0"
        }
    }

    private var maxValueString: String {
        let maxValue = BigInt(2).power(bitSize - 1) - 1
        if base == .decimal {
            return maxValue.description
        } else {
            return "0x" + String(maxValue.magnitude, radix: 16)
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
        let parsedValue: BigInt?

        switch base {
        case .decimal:
            // Check for negative sign
            let isNegative = trimmed.hasPrefix("-")
            let numberString = isNegative ? String(trimmed.dropFirst()) : trimmed

            // Validate decimal format
            guard numberString.allSatisfy({ $0.isNumber }) else {
                validationError = "Invalid decimal number"
                return
            }

            if let magnitude = BigUInt(numberString, radix: 10) {
                parsedValue = isNegative ? -BigInt(magnitude) : BigInt(magnitude)
            } else {
                parsedValue = nil
            }

        case .hexadecimal:
            // Check for negative sign
            let isNegative = trimmed.hasPrefix("-")
            let hexPart = isNegative ? String(trimmed.dropFirst()) : trimmed

            // Remove 0x prefix if present
            let hexString = hexPart.hasPrefix("0x") ? String(hexPart.dropFirst(2)) : hexPart

            // Validate hex format
            let hexCharacters = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
            guard hexString.unicodeScalars.allSatisfy({ hexCharacters.contains($0) }) else {
                validationError = "Invalid hexadecimal number"
                return
            }

            if let magnitude = BigUInt(hexString, radix: 16) {
                parsedValue = isNegative ? -BigInt(magnitude) : BigInt(magnitude)
            } else {
                parsedValue = nil
            }
        }

        guard let value = parsedValue else {
            validationError = "Invalid number format"
            return
        }

        // Check range for signed integer
        let minValue = -BigInt(2).power(bitSize - 1)
        let maxValue = BigInt(2).power(bitSize - 1) - 1

        if value < minValue {
            validationError = "Value below int\(bitSize) minimum"
            return
        }

        if value > maxValue {
            validationError = "Value exceeds int\(bitSize) maximum"
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
        let parsedValue: BigInt?

        switch oldBase {
        case .decimal:
            parsedValue = BigInt(trimmed, radix: 10)
        case .hexadecimal:
            let isNegative = trimmed.hasPrefix("-")
            let hexPart = isNegative ? String(trimmed.dropFirst()) : trimmed
            let hexString = hexPart.hasPrefix("0x") ? String(hexPart.dropFirst(2)) : hexPart

            if let magnitude = BigUInt(hexString, radix: 16) {
                parsedValue = isNegative ? -BigInt(magnitude) : BigInt(magnitude)
            } else {
                parsedValue = nil
            }
        }

        guard let value = parsedValue else { return }

        // Convert to new base
        switch newBase {
        case .decimal:
            inputValue = value.description
        case .hexadecimal:
            if value < 0 {
                inputValue = "-0x" + String((-value).magnitude, radix: 16)
            } else {
                inputValue = "0x" + String(value.magnitude, radix: 16)
            }
        }

        validateAndUpdate(inputValue)
    }

    // MARK: - Value Loading

    private func loadValue() {
        if let string = parameter.value.value as? String {
            // Try to parse as decimal first
            if let _ = BigInt(string, radix: 10) {
                base = .decimal
                inputValue = string
            } else if string.hasPrefix("0x") || string.hasPrefix("-0x") {
                let isNegative = string.hasPrefix("-")
                let hexPart = isNegative ? String(string.dropFirst()) : string
                let hexString = hexPart.hasPrefix("0x") ? String(hexPart.dropFirst(2)) : hexPart
                if let _ = BigUInt(hexString, radix: 16) {
                    base = .hexadecimal
                    inputValue = string
                } else {
                    inputValue = "0"
                }
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

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        IntInputView(
            parameter: .constant(
                TransactionParameter(
                    name: "balance",
                    type: .int(256),
                    value: .init("-1000000000000000000")
                )
            )
        )

        IntInputView(
            parameter: .constant(
                TransactionParameter(
                    name: "delta",
                    type: .int(128),
                    value: .init("500")
                )
            )
        )

        IntInputView(
            parameter: .constant(
                TransactionParameter(
                    name: "offset",
                    type: .int(8),
                    value: .init("-127")
                )
            )
        )
    }
    .padding()
    .frame(width: 500)
}
