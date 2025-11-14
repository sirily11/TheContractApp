//
//  BoolInputView.swift
//  SmartContractApp
//
//  Created by Claude on 11/13/25.
//

import EvmCore
import SwiftUI

/// Input view for boolean type parameters
struct BoolInputView: View {
    @Binding var parameter: TransactionParameter
    @State private var boolValue: Bool = false

    var body: some View {
        Toggle(isOn: $boolValue) {
            Text("Value")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .toggleStyle(.switch)
        .onChange(of: boolValue) { _, newValue in
            parameter.value = AnyCodable(newValue)
        }
        .onAppear {
            loadValue()
        }
    }

    // MARK: - Value Loading

    private func loadValue() {
        // Try to extract boolean value from AnyCodable
        if let bool = parameter.value.value as? Bool {
            boolValue = bool
        } else if let string = parameter.value.value as? String {
            // Try parsing from string
            boolValue = string.lowercased() == "true" || string == "1"
        } else if let number = parameter.value.value as? Int {
            boolValue = number != 0
        } else {
            boolValue = false
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        BoolInputView(
            parameter: .constant(
                TransactionParameter(
                    name: "enabled",
                    type: .bool,
                    value: .init(true)
                )
            )
        )

        BoolInputView(
            parameter: .constant(
                TransactionParameter(
                    name: "disabled",
                    type: .bool,
                    value: .init(false)
                )
            )
        )
    }
    .padding()
    .frame(width: 300)
}
