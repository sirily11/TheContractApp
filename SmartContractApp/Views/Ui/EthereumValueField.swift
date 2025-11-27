//
//  EthereumValueField.swift
//  SmartContractApp
//
//  Created by Claude Code
//

import SwiftUI

/// A reusable component for inputting Ethereum values with unit selection
struct EthereumValueField: View {
    // MARK: - Properties

    @Binding var amount: String
    @Binding var selectedUnit: EthereumValueUnit

    let showLabel: Bool
    let isRequired: Bool

    // MARK: - Initialization

    init(
        amount: Binding<String>,
        selectedUnit: Binding<EthereumValueUnit>,
        showLabel: Bool = true,
        isRequired: Bool = false
    ) {
        self._amount = amount
        self._selectedUnit = selectedUnit
        self.showLabel = showLabel
        self.isRequired = isRequired
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showLabel {
                HStack {
                    Text("Value")
                        .font(.headline)
                    if isRequired {
                        Text("*")
                            .foregroundColor(.red)
                    }
                    Spacer()
                }
            }

            HStack(spacing: 12) {
                // Amount input field
                TextField("0.0", text: $amount)
                    .textFieldStyle(.roundedBorder)
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif
                    .font(.body)
                    .frame(minWidth: 100)
                    .accessibilityIdentifier("transaction-value")

                // Unit picker
                Picker("Unit", selection: $selectedUnit) {
                    ForEach(EthereumValueUnit.allCases) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
            }

            // Helper text
            Text("Enter the amount of \(selectedUnit.rawValue) to send with this transaction")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Previews

#Preview("Default") {
    @Previewable @State var amount = "0.1"
    @Previewable @State var unit = EthereumValueUnit.ether

    return VStack(spacing: 20) {
        EthereumValueField(
            amount: $amount,
            selectedUnit: $unit
        )

        Text("Current: \(amount) \(unit.rawValue)")
            .font(.caption)
    }
    .padding()
}

#Preview("Without Label") {
    @Previewable @State var amount = "100"
    @Previewable @State var unit = EthereumValueUnit.gwei

    return EthereumValueField(
        amount: $amount,
        selectedUnit: $unit,
        showLabel: false
    )
    .padding()
}

#Preview("Required") {
    @Previewable @State var amount = ""
    @Previewable @State var unit = EthereumValueUnit.wei

    return EthereumValueField(
        amount: $amount,
        selectedUnit: $unit,
        isRequired: true
    )
    .padding()
}
