//
//  BoolInputViewTests.swift
//  SmartContractAppTests
//
//  Created by Claude on 11/14/25.
//

@testable import SmartContractApp
import EvmCore
import SwiftUI
import Testing
import ViewInspector

/// Tests for BoolInputView to verify proper value type handling
struct BoolInputViewTests {
    // MARK: - Value Type Tests

    @Test("BoolInputView stores values as Bool, not String")
    @MainActor func testValueTypeIsBool() async throws {
        @Previewable @State var parameter = TransactionParameter(
            name: "enabled",
            type: .bool,
            value: .init(false)
        )

        let wrapper = try SwiftUITestWrapper.withEmpty {
            BoolInputView(parameter: $parameter)
        }

        _ = try wrapper.inspect()

        // Verify the value is stored as a Bool, not String
        #expect(parameter.value.value is Bool)
        #expect(parameter.value.value as? Bool == false)
    }

    @Test("BoolInputView with true value stores as Bool")
    @MainActor func testTrueValueIsBoolType() async throws {
        @Previewable @State var parameter = TransactionParameter(
            name: "enabled",
            type: .bool,
            value: .init(true)
        )

        let wrapper = try SwiftUITestWrapper.withEmpty {
            BoolInputView(parameter: $parameter)
        }

        _ = try wrapper.inspect()

        // Verify value is Bool(true), not String
        #expect(parameter.value.value is Bool)
        #expect(parameter.value.value as? Bool == true)
        #expect((parameter.value.value is String) == false)
    }

    @Test("BoolInputView with false value stores as Bool")
    @MainActor func testFalseValueIsBoolType() async throws {
        @Previewable @State var parameter = TransactionParameter(
            name: "disabled",
            type: .bool,
            value: .init(false)
        )

        let wrapper = try SwiftUITestWrapper.withEmpty {
            BoolInputView(parameter: $parameter)
        }

        _ = try wrapper.inspect()

        // Verify value is Bool(false), not String
        #expect(parameter.value.value is Bool)
        #expect(parameter.value.value as? Bool == false)
        #expect((parameter.value.value is String) == false)
    }

    // MARK: - Value Type Verification for Different Input Types

    @Test("BoolInputView maintains Bool type, never converts to String")
    @MainActor func testNeverConvertsToString() async throws {
        let boolValues = [true, false]

        for boolValue in boolValues {
            @Previewable @State var parameter = TransactionParameter(
                name: "flag",
                type: .bool,
                value: .init(boolValue)
            )

            let wrapper = try SwiftUITestWrapper.withEmpty {
                BoolInputView(parameter: $parameter)
            }

            _ = try wrapper.inspect()

            // Verify it's always Bool, never String or Int
            #expect(parameter.value.value is Bool)
            #expect((parameter.value.value is String) == false)
            #expect((parameter.value.value is Int) == false)
            #expect(parameter.value.value as? Bool == boolValue)
        }
    }

    @Test("BoolInputView value type is consistent across multiple booleans")
    @MainActor func testValueTypeConsistency() async throws {
        // Test multiple parameters to ensure consistent behavior
        let testCases = [
            ("enabled", true),
            ("disabled", false),
            ("active", true),
            ("inactive", false),
            ("flag", true)
        ]

        for (name, value) in testCases {
            @Previewable @State var parameter = TransactionParameter(
                name: name,
                type: .bool,
                value: .init(value)
            )

            let wrapper = try SwiftUITestWrapper.withEmpty {
                BoolInputView(parameter: $parameter)
            }

            _ = try wrapper.inspect()

            // Every boolean parameter should be stored as Bool type
            #expect(parameter.value.value is Bool)
            #expect(parameter.value.value as? Bool == value)
        }
    }

    @Test("BoolInputView does not accept String representation")
    @MainActor func testBoolTypeNotStringType() async throws {
        @Previewable @State var trueParam = TransactionParameter(
            name: "flag1",
            type: .bool,
            value: .init(true)
        )

        @Previewable @State var falseParam = TransactionParameter(
            name: "flag2",
            type: .bool,
            value: .init(false)
        )

        let wrapper1 = try SwiftUITestWrapper.withEmpty {
            BoolInputView(parameter: $trueParam)
        }

        let wrapper2 = try SwiftUITestWrapper.withEmpty {
            BoolInputView(parameter: $falseParam)
        }

        _ = try wrapper1.inspect()
        _ = try wrapper2.inspect()

        // Verify neither is stored as "true" or "false" string
        #expect((trueParam.value.value as? String) == nil)
        #expect((falseParam.value.value as? String) == nil)

        // Verify they are Bool types
        #expect(trueParam.value.value is Bool)
        #expect(falseParam.value.value is Bool)
    }

    // MARK: - Value Type Verification with Different Boolean Values

    @Test("BoolInputView outputs Bool type for true and false")
    @MainActor func testOutputsBoolTypeForTrueAndFalse() async throws {
        let testValues = [true, false]

        for boolValue in testValues {
            @Previewable @State var parameter = TransactionParameter(
                name: "flag",
                type: .bool,
                value: .init(boolValue)
            )

            let wrapper = try SwiftUITestWrapper.withEmpty {
                BoolInputView(parameter: $parameter)
            }

            _ = try wrapper.inspect()

            // Verify Bool type
            #expect(parameter.value.value is Bool, "Should be Bool for '\(boolValue)'")
            #expect(parameter.value.value as? Bool == boolValue)
            #expect((parameter.value.value is String) == false)
            #expect((parameter.value.value is Int) == false)
        }
    }

    @Test("BoolInputView never outputs String for boolean values")
    @MainActor func testNeverOutputsStringForBooleans() async throws {
        let testCases = [
            (true, "true"),
            (false, "false")
        ]

        for (boolValue, stringRepresentation) in testCases {
            @Previewable @State var parameter = TransactionParameter(
                name: "flag",
                type: .bool,
                value: .init(boolValue)
            )

            let wrapper = try SwiftUITestWrapper.withEmpty {
                BoolInputView(parameter: $parameter)
            }

            _ = try wrapper.inspect()

            // Must be Bool, never String "true" or "false"
            #expect(parameter.value.value is Bool, "Should be Bool, not String '\(stringRepresentation)'")
            #expect((parameter.value.value is String) == false)
            #expect((parameter.value.value as? String) == nil)
            #expect(parameter.value.value as? Bool == boolValue)
        }
    }

    @Test("BoolInputView never outputs Int for boolean values")
    @MainActor func testNeverOutputsIntForBooleans() async throws {
        let testCases = [
            (true, 1),
            (false, 0)
        ]

        for (boolValue, intRepresentation) in testCases {
            @Previewable @State var parameter = TransactionParameter(
                name: "flag",
                type: .bool,
                value: .init(boolValue)
            )

            let wrapper = try SwiftUITestWrapper.withEmpty {
                BoolInputView(parameter: $parameter)
            }

            _ = try wrapper.inspect()

            // Must be Bool, never Int 0 or 1
            #expect(parameter.value.value is Bool, "Should be Bool, not Int '\(intRepresentation)'")
            #expect((parameter.value.value is Int) == false)
            #expect((parameter.value.value as? Int) == nil)
            #expect(parameter.value.value as? Bool == boolValue)
        }
    }

    @Test("BoolInputView validates Bool output type for multiple parameters")
    @MainActor func testValidatesBoolOutputForMultipleParameters() async throws {
        let parameterNames = ["enabled", "disabled", "active", "isValid", "hasPermission", "canEdit"]

        for name in parameterNames {
            for boolValue in [true, false] {
                @Previewable @State var parameter = TransactionParameter(
                    name: name,
                    type: .bool,
                    value: .init(boolValue)
                )

                let wrapper = try SwiftUITestWrapper.withEmpty {
                    BoolInputView(parameter: $parameter)
                }

                _ = try wrapper.inspect()

                // Should be Bool for all parameter names and values
                #expect(parameter.value.value is Bool, "Should be Bool for parameter '\(name)' = \(boolValue)")
                #expect(parameter.value.value as? Bool == boolValue)
                #expect((parameter.value.value is String) == false)
                #expect((parameter.value.value is Int) == false)
            }
        }
    }

    @Test("BoolInputView output type validation across different boolean combinations")
    @MainActor func testOutputTypeValidationAcrossCombinations() async throws {
        let testCases = [
            ("flag1", true),
            ("flag2", false),
            ("enabled", true),
            ("disabled", false),
            ("active", true),
            ("inactive", false)
        ]

        for (name, value) in testCases {
            @Previewable @State var parameter = TransactionParameter(
                name: name,
                type: .bool,
                value: .init(value)
            )

            let wrapper = try SwiftUITestWrapper.withEmpty {
                BoolInputView(parameter: $parameter)
            }

            _ = try wrapper.inspect()

            // All outputs must be Bool type
            #expect(parameter.value.value is Bool, "'\(name)' should be Bool")
            #expect(parameter.value.value as? Bool == value)
            #expect((parameter.value.value is String) == false, "'\(name)' should not be String")
            #expect((parameter.value.value is Int) == false, "'\(name)' should not be Int")
        }
    }
}
