//
//  TupleInputView.swift
//  SmartContractApp
//
//  Created by Claude on 11/13/25.
//

import EvmCore
import SwiftUI

/// Input view for tuple (struct) type parameters with recursive component rendering
struct TupleInputView: View {
    @Binding var parameter: TransactionParameter
    @State private var components: [TransactionParameter] = []

    private var tupleComponents: [SolidityType.TupleComponent] {
        if case .tuple(let comps) = parameter.type {
            return comps
        }
        return []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Tuple header
            HStack {
                Text("Struct/Tuple")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(tupleComponents.count) fields")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Tuple components
            if components.isEmpty {
                emptyTupleView
            } else {
                ForEach($components) { $component in
                    tupleComponentView(for: $component)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            loadValue()
        }
        .onChange(of: components) { _, _ in
            saveValue()
        }
    }

    // MARK: - Empty Tuple View

    private var emptyTupleView: some View {
        VStack(spacing: 8) {
            Image(systemName: "cube.transparent")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("No components defined")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Tuple Component View

    @ViewBuilder
    private func tupleComponentView(for component: Binding<TransactionParameter>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Component header
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(component.wrappedValue.name.isEmpty ? "(unnamed)" : component.wrappedValue.name)
                    .font(.caption)
                    .fontWeight(.medium)

                Text(component.wrappedValue.type.displayString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(3)

                Spacer()
            }

            // Recursive component input
            componentInputView(for: component)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Component Input Routing

    @ViewBuilder
    private func componentInputView(for component: Binding<TransactionParameter>) -> some View {
        switch component.wrappedValue.type {
        case .address:
            AddressInputView(parameter: component)

        case .uint:
            UintInputView(parameter: component)

        case .int:
            IntInputView(parameter: component)

        case .bool:
            BoolInputView(parameter: component)

        case .string:
            StringInputView(parameter: component)

        case .bytes, .bytesN:
            BytesInputView(parameter: component)

        case .array:
            // Nested array
            ArrayInputView(parameter: component)

        case .tuple:
            // Nested tuple
            TupleInputView(parameter: component)
        }
    }

    // MARK: - Default Value Helper

    private func defaultValue(for type: SolidityType) -> AnyCodable {
        switch type {
        case .address:
            return AnyCodable("0x0000000000000000000000000000000000000000")
        case .bool:
            return AnyCodable(false)
        case .string:
            return AnyCodable("")
        case .bytes, .bytesN:
            return AnyCodable("0x")
        case .uint, .int:
            return AnyCodable("0")
        case .array:
            return AnyCodable([])
        case .tuple:
            return AnyCodable([:])
        }
    }

    // MARK: - Value Loading/Saving

    private func loadValue() {
        // Try to load from dictionary or array
        if let dict = parameter.value.value as? [String: Any] {
            // Dictionary format (named components)
            components = tupleComponents.map { component in
                let value = dict[component.name] ?? defaultValue(for: component.type).value
                return TransactionParameter(
                    id: component.id,
                    name: component.name,
                    type: component.type,
                    value: AnyCodable(value)
                )
            }
        } else if let array = parameter.value.value as? [Any] {
            // Array format (positional components)
            components = tupleComponents.enumerated().map { index, component in
                let value = index < array.count ? array[index] : defaultValue(for: component.type).value
                return TransactionParameter(
                    id: component.id,
                    name: component.name,
                    type: component.type,
                    value: AnyCodable(value)
                )
            }
        } else {
            // Initialize with defaults
            components = tupleComponents.map { component in
                TransactionParameter(
                    id: component.id,
                    name: component.name,
                    type: component.type,
                    value: defaultValue(for: component.type)
                )
            }
        }
    }

    private func saveValue() {
        // Save as dictionary (preserving component names)
        var dict: [String: Any] = [:]
        for component in components {
            dict[component.name] = component.value.value
        }
        parameter.value = AnyCodable(dict)
    }
}

// MARK: - Preview

#Preview("Simple Struct") {
    TupleInputView(
        parameter: .constant(
            TransactionParameter(
                name: "person",
                type: .tuple(components: [
                    .init(name: "name", type: .string),
                    .init(name: "age", type: .uint(8)),
                    .init(name: "isActive", type: .bool)
                ]),
                value: .init([
                    "name": "Alice",
                    "age": 30,
                    "isActive": true
                ])
            )
        )
    )
    .padding()
    .frame(width: 600)
}

#Preview("Complex Struct") {
    TupleInputView(
        parameter: .constant(
            TransactionParameter(
                name: "transaction",
                type: .tuple(components: [
                    .init(name: "from", type: .address),
                    .init(name: "to", type: .address),
                    .init(name: "value", type: .uint(256)),
                    .init(name: "data", type: .bytes),
                    .init(name: "executed", type: .bool)
                ]),
                value: .init([
                    "from": "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
                    "to": "0x1234567890abcdef1234567890abcdef12345678",
                    "value": "1000000000000000000",
                    "data": "0x",
                    "executed": false
                ])
            )
        )
    )
    .padding()
    .frame(width: 600)
}

#Preview("Nested Struct") {
    TupleInputView(
        parameter: .constant(
            TransactionParameter(
                name: "order",
                type: .tuple(components: [
                    .init(name: "orderId", type: .uint(256)),
                    .init(name: "items", type: .array(elementType: .string, fixedSize: nil)),
                    .init(name: "buyer", type: .address)
                ]),
                value: .init([
                    "orderId": "12345",
                    "items": ["Item1", "Item2"],
                    "buyer": "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
                ])
            )
        )
    )
    .padding()
    .frame(width: 600)
}

#Preview("Empty Struct") {
    TupleInputView(
        parameter: .constant(
            TransactionParameter(
                name: "empty",
                type: .tuple(components: []),
                value: .init([:])
            )
        )
    )
    .padding()
    .frame(width: 600)
}
