//
//  ArrayInputView.swift
//  SmartContractApp
//
//  Created by Claude on 11/13/25.
//

import EvmCore
import SwiftUI

/// Input view for array type parameters with recursive element rendering
struct ArrayInputView: View {
    @Binding var parameter: TransactionParameter
    @State private var elements: [TransactionParameter] = []

    private var elementType: SolidityType {
        if case .array(let type, _) = parameter.type {
            return type
        }
        return .string // Fallback
    }

    private var fixedSize: Int? {
        if case .array(_, let size) = parameter.type {
            return size
        }
        return nil
    }

    private var isDynamicArray: Bool {
        fixedSize == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Array header
            HStack {
                Text("Array Elements")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if let size = fixedSize {
                    Text("Fixed size: \(size)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                } else {
                    Text("\(elements.count) items")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Array elements
            if elements.isEmpty {
                emptyArrayView
            } else {
                ForEach(Array(elements.enumerated()), id: \.element.id) { index, element in
                    arrayElementView(at: index)
                }
            }

            // Add button for dynamic arrays or if under fixed size
            if shouldShowAddButton {
                addElementButton
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            loadValue()
        }
        .onChange(of: elements) { _, _ in
            saveValue()
        }
    }

    // MARK: - Empty Array View

    private var emptyArrayView: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("No elements")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Array Element View

    @ViewBuilder
    private func arrayElementView(at index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Element header with index and remove button
            HStack {
                Text("[\(index)]")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)

                Spacer()

                if isDynamicArray || elements.count > (fixedSize ?? 0) {
                    Button(action: { removeElement(at: index) }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("Remove element")
                }
            }

            // Recursive element input
            if index < elements.count {
                elementInputView(for: $elements[index])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Element Input Routing

    @ViewBuilder
    private func elementInputView(for element: Binding<TransactionParameter>) -> some View {
        switch element.wrappedValue.type {
        case .address:
            AddressInputView(parameter: element)

        case .uint:
            UintInputView(parameter: element)

        case .int:
            IntInputView(parameter: element)

        case .bool:
            BoolInputView(parameter: element)

        case .string:
            StringInputView(parameter: element)

        case .bytes, .bytesN:
            BytesInputView(parameter: element)

        case .array:
            // Nested array
            ArrayInputView(parameter: element)

        case .tuple:
            // Nested tuple
            TupleInputView(parameter: element)
        }
    }

    // MARK: - Add Button

    private var shouldShowAddButton: Bool {
        if isDynamicArray {
            return true
        }
        if let size = fixedSize {
            return elements.count < size
        }
        return false
    }

    private var addElementButton: some View {
        Button(action: addElement) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Element")
                    .font(.caption)
            }
            .foregroundColor(.blue)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Array Manipulation

    private func addElement() {
        let newElement = TransactionParameter(
            name: "\(elements.count)",
            type: elementType,
            value: defaultValue(for: elementType)
        )
        elements.append(newElement)
    }

    private func removeElement(at index: Int) {
        guard index < elements.count else { return }
        elements.remove(at: index)
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
        // Try to load array from parameter value
        if let array = parameter.value.value as? [Any] {
            elements = array.enumerated().map { index, value in
                TransactionParameter(
                    name: "\(index)",
                    type: elementType,
                    value: AnyCodable(value)
                )
            }
        } else {
            // Initialize with fixed size if needed
            if let size = fixedSize {
                elements = (0..<size).map { index in
                    TransactionParameter(
                        name: "\(index)",
                        type: elementType,
                        value: defaultValue(for: elementType)
                    )
                }
            } else {
                elements = []
            }
        }
    }

    private func saveValue() {
        // Convert elements to array and save
        let arrayValues = elements.map { $0.value.value }
        parameter.value = AnyCodable(arrayValues)
    }
}

// MARK: - Preview

#Preview("Address Array") {
    ArrayInputView(
        parameter: .constant(
            TransactionParameter(
                name: "recipients",
                type: .array(elementType: .address, fixedSize: nil),
                value: .init([
                    "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
                    "0x1234567890abcdef1234567890abcdef12345678"
                ])
            )
        )
    )
    .padding()
    .frame(width: 600)
}

#Preview("Uint256 Fixed Array") {
    ArrayInputView(
        parameter: .constant(
            TransactionParameter(
                name: "amounts",
                type: .array(elementType: .uint(256), fixedSize: 3),
                value: .init(["100", "200", "300"])
            )
        )
    )
    .padding()
    .frame(width: 600)
}

#Preview("Bool Dynamic Array") {
    ArrayInputView(
        parameter: .constant(
            TransactionParameter(
                name: "flags",
                type: .array(elementType: .bool, fixedSize: nil),
                value: .init([true, false, true])
            )
        )
    )
    .padding()
    .frame(width: 600)
}

#Preview("Empty Array") {
    ArrayInputView(
        parameter: .constant(
            TransactionParameter(
                name: "empty",
                type: .array(elementType: .string, fixedSize: nil),
                value: .init([])
            )
        )
    )
    .padding()
    .frame(width: 600)
}
