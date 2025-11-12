import Testing
import Foundation
@testable import EvmCore

/// Tests for SignerError type
@Suite("SignerError Tests")
struct SignerErrorTests {

    // MARK: - Error Description Tests

    @Test("SignerError.unsupportedOperation error description")
    func testUnsupportedOperationError() {
        let error = SignerError.unsupportedOperation("Hardware wallet signing not implemented")
        #expect(error.errorDescription == "Unsupported operation: Hardware wallet signing not implemented")
    }

    @Test("SignerError.invalidPrivateKey error description")
    func testInvalidPrivateKeyError() {
        let error = SignerError.invalidPrivateKey
        #expect(error.errorDescription == "Invalid private key")
    }

    @Test("SignerError.signingFailed error description")
    func testSigningFailedError() {
        struct DummyError: Error, LocalizedError {
            var errorDescription: String? { "Dummy error" }
        }

        let underlyingError = DummyError()
        let error = SignerError.signingFailed(underlyingError)

        #expect(error.errorDescription?.contains("Signing failed") == true)
        #expect(error.errorDescription?.contains("Dummy error") == true)
    }

    // MARK: - Error Protocol Conformance Tests

    @Test("SignerError conforms to Error protocol")
    func testErrorProtocolConformance() {
        let error: Error = SignerError.invalidPrivateKey
        #expect(error is SignerError)
    }

    @Test("SignerError conforms to LocalizedError protocol")
    func testLocalizedErrorProtocolConformance() {
        let error: LocalizedError = SignerError.invalidPrivateKey
        #expect(error.errorDescription != nil)
    }

    // MARK: - Error Throwing Tests

    @Test("Throwing SignerError.unsupportedOperation")
    func testThrowingUnsupportedOperation() {
        func throwError() throws {
            throw SignerError.unsupportedOperation("test operation")
        }

        #expect(throws: SignerError.self) {
            try throwError()
        }
    }

    @Test("Throwing SignerError.invalidPrivateKey")
    func testThrowingInvalidPrivateKey() {
        func throwError() throws {
            throw SignerError.invalidPrivateKey
        }

        #expect(throws: SignerError.self) {
            try throwError()
        }
    }

    @Test("Throwing SignerError.signingFailed")
    func testThrowingSigningFailed() {
        struct TestError: Error {}

        func throwError() throws {
            throw SignerError.signingFailed(TestError())
        }

        #expect(throws: SignerError.self) {
            try throwError()
        }
    }

    // MARK: - Error Matching Tests

    @Test("Catch specific SignerError case")
    func testCatchSpecificError() {
        func throwInvalidPrivateKey() throws {
            throw SignerError.invalidPrivateKey
        }

        do {
            try throwInvalidPrivateKey()
            Issue.record("Should have thrown an error")
        } catch SignerError.invalidPrivateKey {
            // Expected error caught
            #expect(true)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("Catch unsupportedOperation error and extract message")
    func testCatchUnsupportedOperation() {
        func throwUnsupported() throws {
            throw SignerError.unsupportedOperation("EIP-712 signing")
        }

        do {
            try throwUnsupported()
            Issue.record("Should have thrown an error")
        } catch let SignerError.unsupportedOperation(message) {
            #expect(message == "EIP-712 signing")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("Catch signingFailed error and extract underlying error")
    func testCatchSigningFailed() {
        struct SpecificError: Error {
            let code: Int
        }

        func throwSigningFailed() throws {
            throw SignerError.signingFailed(SpecificError(code: 42))
        }

        do {
            try throwSigningFailed()
            Issue.record("Should have thrown an error")
        } catch let SignerError.signingFailed(underlyingError) {
            #expect(underlyingError is SpecificError)
            if let specificError = underlyingError as? SpecificError {
                #expect(specificError.code == 42)
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - Edge Cases

    @Test("SignerError.unsupportedOperation with empty message")
    func testUnsupportedOperationEmptyMessage() {
        let error = SignerError.unsupportedOperation("")
        #expect(error.errorDescription == "Unsupported operation: ")
    }

    @Test("SignerError.unsupportedOperation with long message")
    func testUnsupportedOperationLongMessage() {
        let longMessage = String(repeating: "A", count: 1000)
        let error = SignerError.unsupportedOperation(longMessage)
        #expect(error.errorDescription?.contains(longMessage) == true)
    }

    @Test("SignerError.signingFailed with NSError")
    func testSigningFailedWithNSError() {
        let nsError = NSError(domain: "TestDomain", code: 123, userInfo: [
            NSLocalizedDescriptionKey: "Test NSError"
        ])

        let error = SignerError.signingFailed(nsError)
        let description = error.errorDescription ?? ""

        #expect(description.contains("Signing failed") == true)
        #expect(description.contains("Test NSError") == true)
    }

    // MARK: - Integration Tests

    @Test("Wrap and rethrow SignerError")
    func testWrapAndRethrow() {
        func innerFunction() throws {
            throw SignerError.invalidPrivateKey
        }

        func outerFunction() throws {
            do {
                try innerFunction()
            } catch let error {
                throw SignerError.signingFailed(error)
            }
        }

        do {
            try outerFunction()
            Issue.record("Should have thrown an error")
        } catch let SignerError.signingFailed(underlyingError) {
            #expect(underlyingError is SignerError)
            if let signerError = underlyingError as? SignerError {
                switch signerError {
                case .invalidPrivateKey:
                    #expect(true)
                default:
                    Issue.record("Unexpected underlying error: \(signerError)")
                }
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("Multiple SignerError types in error chain")
    func testMultipleErrorsInChain() {
        struct BottomError: Error, LocalizedError {
            var errorDescription: String? { "Bottom error" }
        }

        let error1 = SignerError.signingFailed(BottomError())
        let error2 = SignerError.signingFailed(error1)

        let description = error2.errorDescription ?? ""
        #expect(description.contains("Signing failed") == true)
    }
}
