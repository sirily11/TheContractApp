import Testing
import Foundation
@testable import EvmCore

/// Tests for AbiParserError type
@Suite("AbiParserError Tests")
struct AbiParserErrorTests {

    // MARK: - Error Description Tests

    @Test("AbiParserError.invalidString error description")
    func testInvalidStringError() {
        let error = AbiParserError.invalidString
        #expect(error.errorDescription == "Invalid string encoding")
    }

    @Test("AbiParserError.invalidFormat error description")
    func testInvalidFormatError() {
        let error = AbiParserError.invalidFormat
        #expect(error.errorDescription == "Invalid ABI format - must be a JSON array or object")
    }

    @Test("AbiParserError.encodingFailed error description")
    func testEncodingFailedError() {
        let error = AbiParserError.encodingFailed
        #expect(error.errorDescription == "Failed to encode ABI to JSON")
    }

    @Test("AbiParserError.fileNotFound error description")
    func testFileNotFoundError() {
        let error = AbiParserError.fileNotFound
        #expect(error.errorDescription == "ABI file not found")
    }

    @Test("AbiParserError.invalidItemType error description")
    func testInvalidItemTypeError() {
        let error = AbiParserError.invalidItemType(expected: .function, got: .event)
        #expect(error.errorDescription == "Invalid ABI item type - expected function, got event")
    }

    @Test("AbiParserError.missingRequiredField error description")
    func testMissingRequiredFieldError() {
        let error = AbiParserError.missingRequiredField("name")
        #expect(error.errorDescription == "Missing required field: name")
    }

    // MARK: - Error Protocol Conformance Tests

    @Test("AbiParserError conforms to Error protocol")
    func testErrorProtocolConformance() {
        let error: Error = AbiParserError.invalidString
        #expect(error is AbiParserError)
    }

    @Test("AbiParserError conforms to LocalizedError protocol")
    func testLocalizedErrorProtocolConformance() {
        let error: LocalizedError = AbiParserError.invalidFormat
        #expect(error.errorDescription != nil)
    }

    // MARK: - Error Throwing Tests

    @Test("Throwing AbiParserError.invalidString")
    func testThrowingInvalidString() {
        func throwError() throws {
            throw AbiParserError.invalidString
        }

        #expect(throws: AbiParserError.self) {
            try throwError()
        }
    }

    @Test("Throwing AbiParserError.invalidFormat")
    func testThrowingInvalidFormat() {
        func throwError() throws {
            throw AbiParserError.invalidFormat
        }

        #expect(throws: AbiParserError.self) {
            try throwError()
        }
    }

    @Test("Throwing AbiParserError.encodingFailed")
    func testThrowingEncodingFailed() {
        func throwError() throws {
            throw AbiParserError.encodingFailed
        }

        #expect(throws: AbiParserError.self) {
            try throwError()
        }
    }

    @Test("Throwing AbiParserError.fileNotFound")
    func testThrowingFileNotFound() {
        func throwError() throws {
            throw AbiParserError.fileNotFound
        }

        #expect(throws: AbiParserError.self) {
            try throwError()
        }
    }

    @Test("Throwing AbiParserError.invalidItemType")
    func testThrowingInvalidItemType() {
        func throwError() throws {
            throw AbiParserError.invalidItemType(expected: .constructor, got: .function)
        }

        #expect(throws: AbiParserError.self) {
            try throwError()
        }
    }

    @Test("Throwing AbiParserError.missingRequiredField")
    func testThrowingMissingRequiredField() {
        func throwError() throws {
            throw AbiParserError.missingRequiredField("inputs")
        }

        #expect(throws: AbiParserError.self) {
            try throwError()
        }
    }

    // MARK: - Error Matching Tests

    @Test("Catch specific AbiParserError case")
    func testCatchSpecificError() {
        func throwInvalidFormat() throws {
            throw AbiParserError.invalidFormat
        }

        do {
            try throwInvalidFormat()
            Issue.record("Should have thrown an error")
        } catch AbiParserError.invalidFormat {
            // Expected error caught
            #expect(true)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("Catch AbiParserError with associated values")
    func testCatchErrorWithAssociatedValues() {
        func throwInvalidItemType() throws {
            throw AbiParserError.invalidItemType(expected: .function, got: .event)
        }

        do {
            try throwInvalidItemType()
            Issue.record("Should have thrown an error")
        } catch let AbiParserError.invalidItemType(expected, got) {
            #expect(expected == .function)
            #expect(got == .event)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("Catch missingRequiredField error and extract field name")
    func testCatchMissingFieldError() {
        func throwMissingField() throws {
            throw AbiParserError.missingRequiredField("outputs")
        }

        do {
            try throwMissingField()
            Issue.record("Should have thrown an error")
        } catch let AbiParserError.missingRequiredField(fieldName) {
            #expect(fieldName == "outputs")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - Multiple Error Types Tests

    @Test("Test all AbiItemType combinations for invalidItemType error")
    func testAllItemTypeCombinations() {
        let allTypes: [AbiItemType] = [.function, .constructor, .event, .fallback, .receive, .error]

        for expectedType in allTypes {
            for gotType in allTypes where gotType != expectedType {
                let error = AbiParserError.invalidItemType(expected: expectedType, got: gotType)
                let description = error.errorDescription ?? ""
                #expect(description.contains(expectedType.rawValue))
                #expect(description.contains(gotType.rawValue))
            }
        }
    }

    @Test("Test various field names in missingRequiredField error")
    func testVariousFieldNames() {
        let fieldNames = ["name", "type", "inputs", "outputs", "stateMutability"]

        for fieldName in fieldNames {
            let error = AbiParserError.missingRequiredField(fieldName)
            let description = error.errorDescription ?? ""
            #expect(description.contains(fieldName))
        }
    }
}
