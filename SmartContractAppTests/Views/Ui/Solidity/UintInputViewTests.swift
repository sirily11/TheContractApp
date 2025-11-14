//
//  UintInputViewTests.swift
//  SmartContractAppTests
//
//  Created by Claude on 11/14/25.
//

@testable import SmartContractApp
import BigInt
import EvmCore
import SwiftUI
import Testing
import ViewInspector

/// Tests for UintInputView to verify proper value type handling and validation
struct UintInputViewTests {
    // MARK: - Value Type Tests

    @Test("UintInputView stores values as String, not BigInt")
    @MainActor func testValueTypeIsString() async throws {
        @Previewable @State var parameter = TransactionParameter(
            name: "amount",
            type: .uint(256),
            value: .init("0")
        )

        let wrapper = try SwiftUITestWrapper.withEmpty {
            UintInputView(parameter: $parameter)
        }

        _ = try wrapper.inspect()

        // Verify the value is stored as a String, not BigInt
        #expect(parameter.value.value is String)
        #expect(parameter.value.value as? String == "0")
    }

    @Test("UintInputView with decimal string value stores as String")
    @MainActor func testDecimalStringValueType() async throws {
        @Previewable @State var parameter = TransactionParameter(
            name: "amount",
            type: .uint(256),
            value: .init("1000000000000000000")
        )

        let wrapper = try SwiftUITestWrapper.withEmpty {
            UintInputView(parameter: $parameter)
        }

        _ = try wrapper.inspect()

        // Verify value is String and can be parsed as BigInt
        #expect(parameter.value.value is String)
        let stringValue = parameter.value.value as? String
        #expect(stringValue == "1000000000000000000")

        // Verify it's a valid BigInt string
        let bigIntValue = BigUInt(stringValue ?? "")
        #expect(bigIntValue != nil)
        #expect(bigIntValue?.description == "1000000000000000000")
    }

    @Test("UintInputView with hex string value stores as String")
    @MainActor func testHexStringValueType() async throws {
        @Previewable @State var parameter = TransactionParameter(
            name: "tokenId",
            type: .uint(256),
            value: .init("0x1234")
        )

        let wrapper = try SwiftUITestWrapper.withEmpty {
            UintInputView(parameter: $parameter)
        }

        _ = try wrapper.inspect()

        // Verify value is stored as String (hex format is preserved initially)
        #expect(parameter.value.value is String)
        let stringValue = parameter.value.value as? String
        #expect(stringValue == "0x1234")
    }

    // MARK: - Bit Size Value Type Tests

    @Test("UintInputView uint8 with max value stores as String")
    @MainActor func testUint8MaxValueAsString() async throws {
        @Previewable @State var parameter = TransactionParameter(
            name: "count",
            type: .uint(8),
            value: .init("255")
        )

        let wrapper = try SwiftUITestWrapper.withEmpty {
            UintInputView(parameter: $parameter)
        }

        _ = try wrapper.inspect()

        // Verify max uint8 value is stored as String
        #expect(parameter.value.value is String)
        #expect(parameter.value.value as? String == "255")
    }

    @Test("UintInputView uint128 with large value stores as String")
    @MainActor func testUint128LargeValueAsString() async throws {
        @Previewable @State var parameter = TransactionParameter(
            name: "tokenId",
            type: .uint(128),
            value: .init("340282366920938463463374607431768211455")  // 2^128 - 1
        )

        let wrapper = try SwiftUITestWrapper.withEmpty {
            UintInputView(parameter: $parameter)
        }

        _ = try wrapper.inspect()

        // Verify large uint128 value is stored as String
        #expect(parameter.value.value is String)
        let stringValue = parameter.value.value as? String
        #expect(stringValue == "340282366920938463463374607431768211455")

        // Verify it's a valid BigInt string
        let bigIntValue = BigUInt(stringValue ?? "")
        #expect(bigIntValue != nil)
    }

    @Test("UintInputView uint256 with max value stores as String")
    @MainActor func testUint256MaxValueAsString() async throws {
        @Previewable @State var parameter = TransactionParameter(
            name: "amount",
            type: .uint(256),
            value: .init("115792089237316195423570985008687907853269984665640564039457584007913129639935")
        )

        let wrapper = try SwiftUITestWrapper.withEmpty {
            UintInputView(parameter: $parameter)
        }

        _ = try wrapper.inspect()

        // Verify max uint256 value is stored as String
        #expect(parameter.value.value is String)
        let stringValue = parameter.value.value as? String

        // Verify it's a valid BigInt string
        let bigIntValue = BigUInt(stringValue ?? "")
        #expect(bigIntValue != nil)
    }

    // MARK: - Value Loading Tests

    @Test("UintInputView loads existing decimal string value")
    @MainActor func testLoadsExistingDecimalValue() async throws {
        @Previewable @State var parameter = TransactionParameter(
            name: "amount",
            type: .uint(256),
            value: .init("1000000000000000000")
        )

        let wrapper = try SwiftUITestWrapper.withEmpty {
            UintInputView(parameter: $parameter)
        }

        _ = try wrapper.inspect()

        // Value should be loaded as-is
        #expect(parameter.value.value is String)
        #expect(parameter.value.value as? String == "1000000000000000000")
    }

    @Test("UintInputView loads existing hex string value")
    @MainActor func testLoadsExistingHexValue() async throws {
        @Previewable @State var parameter = TransactionParameter(
            name: "tokenId",
            type: .uint(128),
            value: .init("0x1234")
        )

        let wrapper = try SwiftUITestWrapper.withEmpty {
            UintInputView(parameter: $parameter)
        }

        _ = try wrapper.inspect()

        // Initial value should be preserved
        #expect(parameter.value.value is String)
        #expect(parameter.value.value as? String == "0x1234")
    }

    // MARK: - BigInt Compatibility Tests

    @Test("UintInputView string values are compatible with BigInt parsing")
    @MainActor func testStringValuesCompatibleWithBigInt() async throws {
        let testValues: [(String, SolidityType)] = [
            ("0", SolidityType.uint(256)),
            ("1", SolidityType.uint(256)),
            ("255", SolidityType.uint(8)),
            ("1000000", SolidityType.uint(256)),
            ("1000000000000000000", SolidityType.uint(256)),
            ("115792089237316195423570985008687907853269984665640564039457584007913129639935", SolidityType.uint(256))  // 2^256 - 1
        ]

        for (testValue, uintType) in testValues {
            @Previewable @State var parameter = TransactionParameter(
                name: "test",
                type: uintType,
                value: .init(testValue)
            )

            let wrapper = try SwiftUITestWrapper.withEmpty {
                UintInputView(parameter: $parameter)
            }

            _ = try wrapper.inspect()

            // Verify it's stored as String
            #expect(parameter.value.value is String)
            let stringValue = parameter.value.value as? String

            // Verify it can be parsed as BigInt
            let bigIntValue = BigUInt(stringValue ?? "")
            #expect(bigIntValue != nil, "Failed to parse '\(stringValue ?? "")' as BigInt")
            #expect(bigIntValue?.description == testValue, "BigInt parse mismatch for '\(testValue)'")
        }
    }

    @Test("UintInputView hex string values are String type")
    @MainActor func testHexStringValuesAreStringType() async throws {
        let testHexValues = [
            "0x0",
            "0x1234",
            "0xabcdef",
            "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
        ]

        for hexValue in testHexValues {
            @Previewable @State var parameter = TransactionParameter(
                name: "test",
                type: .uint(256),
                value: .init(hexValue)
            )

            let wrapper = try SwiftUITestWrapper.withEmpty {
                UintInputView(parameter: $parameter)
            }

            _ = try wrapper.inspect()

            // Verify hex values are stored as String
            #expect(parameter.value.value is String)
            #expect(parameter.value.value as? String == hexValue)
        }
    }

    // MARK: - Value Type Verification with Different Input Values

    @Test("UintInputView outputs String type for various decimal values")
    @MainActor func testOutputsStringTypeForVariousDecimals() async throws {
        let testValues = ["0", "1", "10", "100", "1000", "10000", "1000000000000000000"]

        for testValue in testValues {
            @Previewable @State var parameter = TransactionParameter(
                name: "amount",
                type: .uint(256),
                value: .init(testValue)
            )

            let wrapper = try SwiftUITestWrapper.withEmpty {
                UintInputView(parameter: $parameter)
            }

            _ = try wrapper.inspect()

            // Verify String type and BigInt compatibility
            #expect(parameter.value.value is String, "Should be String for '\(testValue)'")
            #expect(parameter.value.value as? String == testValue)
            #expect((parameter.value.value is Int) == false)
            #expect((parameter.value.value is BigUInt) == false)

            // Verify BigInt parsing works
            let bigInt = BigUInt(testValue)
            #expect(bigInt != nil, "Should be valid BigInt string: '\(testValue)'")
        }
    }

    @Test("UintInputView outputs String type for different bit sizes")
    @MainActor func testOutputsStringTypeForDifferentBitSizes() async throws {
        let testCases: [(SolidityType, String)] = [
            (SolidityType.uint(8), "255"),
            (SolidityType.uint(16), "65535"),
            (SolidityType.uint(32), "4294967295"),
            (SolidityType.uint(64), "18446744073709551615"),
            (SolidityType.uint(128), "340282366920938463463374607431768211455"),
            (SolidityType.uint(256), "115792089237316195423570985008687907853269984665640564039457584007913129639935")
        ]

        for (uintType, maxValue) in testCases {
            @Previewable @State var parameter = TransactionParameter(
                name: "test",
                type: uintType,
                value: .init(maxValue)
            )

            let wrapper = try SwiftUITestWrapper.withEmpty {
                UintInputView(parameter: $parameter)
            }

            _ = try wrapper.inspect()

            // Verify String type
            #expect(parameter.value.value is String, "Should be String for \(uintType)")
            #expect(parameter.value.value as? String == maxValue)

            // Verify BigInt compatibility
            let bigInt = BigUInt(maxValue)
            #expect(bigInt != nil, "Should parse as BigInt: '\(maxValue)'")
        }
    }

    @Test("UintInputView outputs String type for hex and decimal formats")
    @MainActor func testOutputsStringTypeForHexAndDecimal() async throws {
        let testCases = [
            ("0x0", "hex"),
            ("0", "decimal"),
            ("0x100", "hex"),
            ("256", "decimal"),
            ("0xFFFF", "hex"),
            ("65535", "decimal")
        ]

        for (value, format) in testCases {
            @Previewable @State var parameter = TransactionParameter(
                name: "test",
                type: .uint(256),
                value: .init(value)
            )

            let wrapper = try SwiftUITestWrapper.withEmpty {
                UintInputView(parameter: $parameter)
            }

            _ = try wrapper.inspect()

            // Both hex and decimal should be stored as String
            #expect(parameter.value.value is String, "Should be String for \(format) value '\(value)'")
            #expect(parameter.value.value as? String == value)
        }
    }

    @Test("UintInputView never outputs numeric types")
    @MainActor func testNeverOutputsNumericTypes() async throws {
        // Test values that could be confused with native numeric types
        let testValues = [
            ("0", "zero"),
            ("1", "one"),
            ("255", "UInt8 max"),
            ("65535", "UInt16 max"),
            ("4294967295", "UInt32 max")
        ]

        for (testValue, description) in testValues {
            @Previewable @State var parameter = TransactionParameter(
                name: "test",
                type: .uint(256),
                value: .init(testValue)
            )

            let wrapper = try SwiftUITestWrapper.withEmpty {
                UintInputView(parameter: $parameter)
            }

            _ = try wrapper.inspect()

            // Must be String, never native numeric types
            #expect(parameter.value.value is String, "Should be String for \(description)")
            #expect((parameter.value.value is Int) == false, "Should not be Int for \(description)")
            #expect((parameter.value.value is UInt) == false, "Should not be UInt for \(description)")
            #expect((parameter.value.value is UInt8) == false, "Should not be UInt8 for \(description)")
            #expect((parameter.value.value is UInt16) == false, "Should not be UInt16 for \(description)")
            #expect((parameter.value.value is UInt32) == false, "Should not be UInt32 for \(description)")
            #expect((parameter.value.value is UInt64) == false, "Should not be UInt64 for \(description)")
        }
    }

    @Test("UintInputView validates String output format")
    @MainActor func testValidatesStringOutputFormat() async throws {
        let testCases = [
            "0",
            "1",
            "42",
            "1000000000000000000",
            "115792089237316195423570985008687907853269984665640564039457584007913129639935"
        ]

        for testValue in testCases {
            @Previewable @State var parameter = TransactionParameter(
                name: "test",
                type: .uint(256),
                value: .init(testValue)
            )

            let wrapper = try SwiftUITestWrapper.withEmpty {
                UintInputView(parameter: $parameter)
            }

            _ = try wrapper.inspect()

            // Verify String type and value
            #expect(parameter.value.value is String)
            let stringValue = parameter.value.value as? String
            #expect(stringValue == testValue)

            // Verify the string can be used to create BigUInt
            let bigInt = BigUInt(stringValue ?? "")
            #expect(bigInt != nil, "String output must be valid for BigUInt")
            #expect(bigInt?.description == testValue, "BigUInt round-trip must match")
        }
    }
}
