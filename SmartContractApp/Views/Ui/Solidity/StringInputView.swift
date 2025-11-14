//
//  StringInputView.swift
//  SmartContractApp
//
//  Created by Claude on 11/13/25.
//

import EvmCore
import SwiftUI

/// Input view for string type parameters
struct StringInputView: View {
    @Binding var parameter: TransactionParameter
    @State private var stringValue: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Text input
            TextField("Enter string value", text: $stringValue, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .lineLimit(3...6)
                .onChange(of: stringValue) { _, newValue in
                    parameter.value = AnyCodable(newValue)
                }

            // Character count
            HStack {
                Spacer()
                Text("\(stringValue.count) characters")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            loadValue()
        }
    }

    // MARK: - Value Loading

    private func loadValue() {
        if let string = parameter.value.value as? String {
            stringValue = string
        } else {
            // Convert other types to string
            stringValue = "\(parameter.value.value)"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        StringInputView(
            parameter: .constant(
                TransactionParameter(
                    name: "message",
                    type: .string,
                    value: .init("Hello, World!")
                )
            )
        )

        StringInputView(
            parameter: .constant(
                TransactionParameter(
                    name: "longText",
                    type: .string,
                    value: .init("This is a longer text that might span multiple lines to demonstrate how the text field handles multi-line input.")
                )
            )
        )
    }
    .padding()
    .frame(width: 400)
}
