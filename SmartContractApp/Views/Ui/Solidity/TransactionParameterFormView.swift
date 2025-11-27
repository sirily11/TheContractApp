//
//  TransactionParameterFormView.swift
//  SmartContractApp
//
//  Created by Claude on 11/13/25.
//

import SwiftUI

// MARK: - TransactionParameterFormView

/**
 A reusable form view for displaying and editing Solidity smart contract function parameters.

 ## Overview

 `TransactionParameterFormView` provides a type-safe, user-friendly interface for editing smart contract
 parameters of any Solidity type. It automatically routes each parameter to the appropriate specialized
 input widget based on its type, supporting all Solidity types including complex nested structures.

 ## Features

 - **Type-Safe Routing**: Uses Swift enums with pattern matching to route parameters to appropriate input views
 - **Comprehensive Type Support**: Handles all Solidity types:
   - Basic: `address`, `bool`, `string`, `bytes`, `bytesN`
   - Numeric: `uint`, `int` (with decimal/hexadecimal base selection)
   - Complex: Arrays (fixed and dynamic), Tuples/Structs (nested support)
 - **Inline Validation**: Real-time validation with visual feedback for each parameter
 - **Recursive Rendering**: Fully supports nested arrays and tuples
 - **Two-Way Binding**: Changes are immediately reflected in the bound parameter array

 ## Usage

 ### Basic Example

 ```swift
 struct ContractCallView: View {
     @State private var parameters: [TransactionParameter] = [
         TransactionParameter(name: "recipient", type: .address, value: .init("")),
         TransactionParameter(name: "amount", type: .uint(256), value: .init("0"))
     ]

     var body: some View {
         VStack {
             TransactionParameterFormView(parameters: $parameters)

             Button("Submit") {
                 // Use parameters for contract call
                 submitTransaction(parameters: parameters)
             }
         }
     }
 }
 ```

 ### With ABI Integration

 ```swift
 struct FunctionCallView: View {
     let function: AbiFunction
     @State private var parameters: [TransactionParameter] = []

     var body: some View {
         TransactionParameterFormView(parameters: $parameters)
             .onAppear {
                 // Initialize from ABI function inputs
                 parameters = function.inputs.map { input in
                     TransactionParameter(
                         name: input.name,
                         type: try! SolidityType(parsing: input.type),
                         value: .init("") // Default empty value
                     )
                 }
             }
     }
 }
 ```

 ### Dynamic Parameters

 ```swift
 struct DynamicFormView: View {
     @State private var parameters: [TransactionParameter] = []

     var body: some View {
         VStack {
             TransactionParameterFormView(parameters: $parameters)

             Button("Add Parameter") {
                 parameters.append(
                     TransactionParameter(
                         name: "param\(parameters.count)",
                         type: .string,
                         value: .init("")
                     )
                 )
             }
         }
     }
 }
 ```

 ## Architecture

 The form uses a hierarchical structure:

 ```
 TransactionParameterFormView (Main Form)
   ├─ Section (per parameter)
   │   ├─ Header: Parameter name + type badge
   │   └─ Body: Type-specific input widget
   │       ├─ AddressInputView (for .address)
   │       ├─ UintInputView (for .uint with base selector)
   │       ├─ IntInputView (for .int with base selector)
   │       ├─ BoolInputView (for .bool)
   │       ├─ StringInputView (for .string)
   │       ├─ BytesInputView (for .bytes, .bytesN)
   │       ├─ ArrayInputView (for .array - recursive)
   │       └─ TupleInputView (for .tuple - recursive)
 ```

 ## Input Widgets

 Each specialized input widget provides:
 - Type-specific validation rules
 - Appropriate input controls (text fields, toggles, pickers)
 - Visual validation feedback (checkmarks, error icons)
 - Help text and format hints
 - AnyCodable value encoding

 ## Validation

 Validation is performed at the widget level:
 - **Address**: Format validation (0x + 40 hex chars)
 - **Uint/Int**: Numeric format, range checking based on bit size
 - **Bytes**: Hex format, length validation for fixed-size
 - **Array**: Element count validation for fixed-size arrays
 - **All Types**: Real-time inline feedback with visual indicators

 ## Performance Considerations

 - Uses `@Binding` for efficient two-way data flow
 - Lazy rendering with `ForEach` for large parameter lists
 - Minimal re-renders through focused state management
 - Efficient recursive rendering for nested structures

 ## See Also

 - `TransactionParameter`: The model representing a single parameter
 - `SolidityType`: Type-safe enum for all Solidity types
 - Individual input views in `SmartContractApp/Views/Ui/Solidity/`
 */
struct TransactionParameterFormView: View {

    // MARK: - Properties

    /// Binding to the array of parameters to edit
    ///
    /// Changes to individual parameters are immediately reflected in this array through two-way binding.
    /// The form automatically updates when parameters are added, removed, or modified.
    @Binding var parameters: [TransactionParameter]

    // MARK: - Body

    var body: some View {
        Form {
            if parameters.isEmpty {
                emptyStateView
            } else {
                ForEach($parameters) { $parameter in
                    parameterSection(for: $parameter)
                        .accessibilityIdentifier(parameter.name)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Empty State

    /// Empty state view displayed when no parameters are provided
    ///
    /// Shows a centered message with an icon indicating that the function has no input parameters.
    /// This provides clear feedback to users rather than showing a blank form.
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No Parameters")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("This function has no input parameters")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Parameter Section

    /// Creates a form section for a single parameter
    ///
    /// Each section consists of:
    /// - **Header**: Displays the parameter name and type badge
    /// - **Body**: The appropriate input widget for the parameter's type
    ///
    /// The section uses SwiftUI's `Section` component to provide proper spacing and styling
    /// within the form. Parameter changes are propagated through the binding.
    ///
    /// - Parameter parameter: A binding to the transaction parameter to display and edit
    /// - Returns: A view representing the parameter section
    @ViewBuilder
    private func parameterSection(for parameter: Binding<TransactionParameter>) -> some View {
        Section {
            // Input widget based on type
            inputView(for: parameter)
        } header: {
            // Parameter header with name and type
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(parameter.wrappedValue.name.isEmpty ? "(unnamed)" : parameter.wrappedValue.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(parameter.wrappedValue.type.displayString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
        }
    }

    // MARK: - Type Routing

    /// Routes a parameter to the appropriate input widget based on its type
    ///
    /// This method implements type-safe routing using Swift's pattern matching on the `SolidityType` enum.
    /// Each case returns a specialized input view optimized for that particular type:
    ///
    /// **Basic Types:**
    /// - `.address` → `AddressInputView`: Ethereum address with hex validation
    /// - `.bool` → `BoolInputView`: Toggle switch
    /// - `.string` → `StringInputView`: Multi-line text input
    ///
    /// **Numeric Types:**
    /// - `.uint` → `UintInputView`: Unsigned integer with decimal/hex base selector
    /// - `.int` → `IntInputView`: Signed integer with decimal/hex base selector
    ///
    /// **Bytes Types:**
    /// - `.bytes`, `.bytesN` → `BytesInputView`: Hex input with length validation
    ///
    /// **Complex Types:**
    /// - `.array` → `ArrayInputView`: Dynamic/fixed array with add/remove functionality (recursive)
    /// - `.tuple` → `TupleInputView`: Struct with named components (recursive)
    ///
    /// ## Recursive Support
    ///
    /// The routing is fully recursive - `ArrayInputView` and `TupleInputView` can contain any type,
    /// including nested arrays and tuples, which will be routed back through this method.
    ///
    /// - Parameter parameter: A binding to the parameter to create an input view for
    /// - Returns: A type-specific input view for editing the parameter
    @ViewBuilder
    private func inputView(for parameter: Binding<TransactionParameter>) -> some View {
        switch parameter.wrappedValue.type {
        case .address:
            AddressInputView(parameter: parameter)

        case .uint:
            UintInputView(parameter: parameter)

        case .int:
            IntInputView(parameter: parameter)

        case .bool:
            BoolInputView(parameter: parameter)

        case .string:
            StringInputView(parameter: parameter)

        case .bytes, .bytesN:
            BytesInputView(parameter: parameter)

        case .array:
            ArrayInputView(parameter: parameter)

        case .tuple:
            TupleInputView(parameter: parameter)
        }
    }
}

// MARK: - Previews

/**
 Preview configurations demonstrating various use cases of `TransactionParameterFormView`.

 These previews showcase:
 - Basic types (address, uint256) for common contract interactions
 - All supported types for comprehensive testing
 - Empty state when no parameters are provided

 Use these previews to:
 - Test visual appearance and layout
 - Verify type routing is working correctly
 - Validate form behavior with different parameter configurations
 - Ensure proper rendering on different screen sizes
 */

/// Preview showing basic ERC-20 transfer parameters (address and uint256)
#Preview("Basic Types") {
    TransactionParameterFormView(
        parameters: .constant(TransactionParameter.sampleTransfer)
    )
    .padding()
    .frame(width: 500)
}

/// Preview showing all supported Solidity types for comprehensive testing
#Preview("All Types") {
    ScrollView {
        TransactionParameterFormView(
            parameters: .constant(TransactionParameter.sampleAllTypes)
        )
        .padding()
    }
    .frame(width: 500, height: 600)
}

/// Preview showing the empty state when no parameters are provided
#Preview("Empty") {
    TransactionParameterFormView(
        parameters: .constant([])
    )
    .padding()
    .frame(width: 500)
}
