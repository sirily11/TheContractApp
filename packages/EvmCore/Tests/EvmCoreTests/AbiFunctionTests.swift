import Testing
import Foundation
import BigInt
@testable import EvmCore

/// Tests for AbiFunction and related types
@Suite("AbiFunction Tests")
struct AbiFunctionTests {

    // MARK: - AbiParameter Tests

    @Test("Initialize AbiParameter with all fields")
    func testAbiParameterInit() {
        let param = AbiParameter(
            name: "amount",
            type: "uint256",
            indexed: false,
            components: nil,
            internalType: "uint256"
        )

        #expect(param.name == "amount")
        #expect(param.type == "uint256")
        #expect(param.indexed == false)
        #expect(param.components == nil)
        #expect(param.internalType == "uint256")
    }

    @Test("Initialize AbiParameter with defaults")
    func testAbiParameterDefaultInit() {
        let param = AbiParameter(name: "value", type: "uint256")

        #expect(param.name == "value")
        #expect(param.type == "uint256")
        #expect(param.indexed == nil)
        #expect(param.components == nil)
        #expect(param.internalType == nil)
    }

    @Test("AbiParameter with components (tuple)")
    func testAbiParameterWithComponents() {
        let components = [
            AbiParameter(name: "x", type: "uint256"),
            AbiParameter(name: "y", type: "uint256")
        ]
        let param = AbiParameter(name: "point", type: "tuple", components: components)

        #expect(param.components?.count == 2)
        #expect(param.components?[0].name == "x")
    }

    @Test("AbiParameter Codable round-trip")
    func testAbiParameterCodable() throws {
        let original = AbiParameter(
            name: "token",
            type: "address",
            indexed: true,
            internalType: "address"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AbiParameter.self, from: data)

        #expect(decoded == original)
    }

    // MARK: - StateMutability Tests

    @Test("StateMutability enum cases")
    func testStateMutabilityCases() {
        #expect(StateMutability.pure.rawValue == "pure")
        #expect(StateMutability.view.rawValue == "view")
        #expect(StateMutability.nonpayable.rawValue == "nonpayable")
        #expect(StateMutability.payable.rawValue == "payable")
    }

    @Test("StateMutability Codable")
    func testStateMutabilityCodable() throws {
        let mutability = StateMutability.view
        let encoder = JSONEncoder()
        let data = try encoder.encode(mutability)
        let json = String(data: data, encoding: .utf8)!

        #expect(json == "\"view\"")

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(StateMutability.self, from: data)

        #expect(decoded == mutability)
    }

    // MARK: - AbiFunction Initialization Tests

    @Test("Initialize AbiFunction with all parameters")
    func testAbiFunctionInit() {
        let inputs = [AbiParameter(name: "to", type: "address")]
        let outputs = [AbiParameter(name: "", type: "bool")]

        let function = AbiFunction(
            name: "transfer",
            inputs: inputs,
            outputs: outputs,
            stateMutability: .nonpayable,
            constant: false,
            payable: false
        )

        #expect(function.name == "transfer")
        #expect(function.inputs.count == 1)
        #expect(function.outputs.count == 1)
        #expect(function.stateMutability == .nonpayable)
        #expect(function.constant == false)
        #expect(function.payable == false)
    }

    @Test("Initialize AbiFunction with defaults")
    func testAbiFunctionDefaultInit() {
        let function = AbiFunction(
            name: "getValue",
            stateMutability: .view
        )

        #expect(function.inputs.isEmpty)
        #expect(function.outputs.isEmpty)
        #expect(function.constant == nil)
        #expect(function.payable == nil)
    }

    @Test("Initialize payable function")
    func testPayableFunction() {
        let function = AbiFunction(
            name: "deposit",
            stateMutability: .payable,
            payable: true
        )

        #expect(function.stateMutability == .payable)
        #expect(function.payable == true)
    }

    @Test("Initialize view function")
    func testViewFunction() {
        let function = AbiFunction(
            name: "balanceOf",
            inputs: [AbiParameter(name: "account", type: "address")],
            outputs: [AbiParameter(name: "balance", type: "uint256")],
            stateMutability: .view,
            constant: true
        )

        #expect(function.stateMutability == .view)
        #expect(function.constant == true)
    }

    // MARK: - toAbiItem Tests

    @Test("Convert AbiFunction to AbiItem")
    func testToAbiItem() {
        let function = AbiFunction(
            name: "transfer",
            inputs: [
                AbiParameter(name: "to", type: "address"),
                AbiParameter(name: "amount", type: "uint256")
            ],
            outputs: [AbiParameter(name: "success", type: "bool")],
            stateMutability: .nonpayable
        )

        let item = function.toAbiItem()

        #expect(item.type == .function)
        #expect(item.name == "transfer")
        #expect(item.inputs?.count == 2)
        #expect(item.outputs?.count == 1)
        #expect(item.stateMutability == .nonpayable)
    }

    // MARK: - from AbiItem Tests

    @Test("Create AbiFunction from valid AbiItem")
    func testFromValidAbiItem() throws {
        let item = AbiItem(
            type: .function,
            name: "approve",
            inputs: [AbiParameter(name: "spender", type: "address")],
            outputs: [AbiParameter(name: "success", type: "bool")],
            stateMutability: .nonpayable,
            anonymous: nil,
            constant: nil,
            payable: nil
        )

        let function = try AbiFunction.from(item: item)

        #expect(function.name == "approve")
        #expect(function.inputs.count == 1)
        #expect(function.stateMutability == .nonpayable)
    }

    @Test("Throw error when creating from non-function AbiItem")
    func testFromNonFunctionAbiItem() {
        let item = AbiItem(
            type: .event,
            name: "Transfer",
            inputs: [],
            outputs: nil,
            stateMutability: nil,
            anonymous: nil,
            constant: nil,
            payable: nil
        )

        #expect(throws: AbiParserError.self) {
            _ = try AbiFunction.from(item: item)
        }
    }

    @Test("Throw error when AbiItem missing name")
    func testFromAbiItemMissingName() {
        let item = AbiItem(
            type: .function,
            name: nil,
            inputs: [],
            outputs: [],
            stateMutability: .view,
            anonymous: nil,
            constant: nil,
            payable: nil
        )

        #expect(throws: AbiParserError.self) {
            _ = try AbiFunction.from(item: item)
        }
    }

    @Test("Throw error when AbiItem missing stateMutability")
    func testFromAbiItemMissingStateMutability() {
        let item = AbiItem(
            type: .function,
            name: "test",
            inputs: [],
            outputs: [],
            stateMutability: nil,
            anonymous: nil,
            constant: nil,
            payable: nil
        )

        #expect(throws: AbiParserError.self) {
            _ = try AbiFunction.from(item: item)
        }
    }

    // MARK: - Signature Tests

    @Test("Generate function signature with no parameters")
    func testSignatureNoParams() {
        let function = AbiFunction(name: "decimals", stateMutability: .view)
        let signature = function.signature()

        #expect(signature == "decimals()")
    }

    @Test("Generate function signature with one parameter")
    func testSignatureOneParam() {
        let function = AbiFunction(
            name: "balanceOf",
            inputs: [AbiParameter(name: "account", type: "address")],
            stateMutability: .view
        )
        let signature = function.signature()

        #expect(signature == "balanceOf(address)")
    }

    @Test("Generate function signature with multiple parameters")
    func testSignatureMultipleParams() {
        let function = AbiFunction(
            name: "transfer",
            inputs: [
                AbiParameter(name: "to", type: "address"),
                AbiParameter(name: "amount", type: "uint256")
            ],
            stateMutability: .nonpayable
        )
        let signature = function.signature()

        #expect(signature == "transfer(address,uint256)")
    }

    @Test("Generate function signature with tuple parameter")
    func testSignatureWithTuple() {
        let components = [
            AbiParameter(name: "x", type: "uint256"),
            AbiParameter(name: "y", type: "uint256")
        ]
        let function = AbiFunction(
            name: "setPoint",
            inputs: [AbiParameter(name: "point", type: "tuple", components: components)],
            stateMutability: .nonpayable
        )
        let signature = function.signature()

        #expect(signature == "setPoint((uint256,uint256))")
    }

    // MARK: - Selector Tests

    @Test("Generate function selector")
    func testSelector() throws {
        let function = AbiFunction(
            name: "transfer",
            inputs: [
                AbiParameter(name: "to", type: "address"),
                AbiParameter(name: "amount", type: "uint256")
            ],
            stateMutability: .nonpayable
        )

        let selector = try function.selector()

        // Known selector for transfer(address,uint256) is 0xa9059cbb
        #expect(selector == "0xa9059cbb")
    }

    @Test("Generate selector for balanceOf")
    func testSelectorBalanceOf() throws {
        let function = AbiFunction(
            name: "balanceOf",
            inputs: [AbiParameter(name: "account", type: "address")],
            stateMutability: .view
        )

        let selector = try function.selector()

        // Known selector for balanceOf(address) is 0x70a08231
        #expect(selector == "0x70a08231")
    }

    @Test("Generate selector for approve")
    func testSelectorApprove() throws {
        let function = AbiFunction(
            name: "approve",
            inputs: [
                AbiParameter(name: "spender", type: "address"),
                AbiParameter(name: "amount", type: "uint256")
            ],
            stateMutability: .nonpayable
        )

        let selector = try function.selector()

        // Known selector for approve(address,uint256) is 0x095ea7b3
        #expect(selector == "0x095ea7b3")
    }

    // MARK: - encodeCall Tests

    @Test("Encode function call with no arguments")
    func testEncodeCallNoArgs() throws {
        let function = AbiFunction(name: "decimals", stateMutability: .view)

        let encoded = try function.encodeCall(args: [])

        // Should just be the selector
        #expect(encoded.hasPrefix("0x"))
        #expect(encoded.count == 10) // 0x + 8 hex chars
    }

    @Test("Encode call throws error for argument count mismatch")
    func testEncodeCallArgumentMismatch() {
        let function = AbiFunction(
            name: "transfer",
            inputs: [
                AbiParameter(name: "to", type: "address"),
                AbiParameter(name: "amount", type: "uint256")
            ],
            stateMutability: .nonpayable
        )

        #expect(throws: AbiEncodingError.self) {
            _ = try function.encodeCall(args: ["0x1234567890123456789012345678901234567890"])
        }
    }

    // MARK: - Codable Tests

    @Test("AbiFunction Codable round-trip")
    func testAbiFunctionCodable() throws {
        let original = AbiFunction(
            name: "transfer",
            inputs: [
                AbiParameter(name: "to", type: "address"),
                AbiParameter(name: "amount", type: "uint256")
            ],
            outputs: [AbiParameter(name: "success", type: "bool")],
            stateMutability: .nonpayable,
            constant: false,
            payable: false
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AbiFunction.self, from: data)

        #expect(decoded == original)
    }

    // MARK: - Equatable Tests

    @Test("Equal AbiFunctions are equal")
    func testEquality() {
        let function1 = AbiFunction(
            name: "transfer",
            inputs: [AbiParameter(name: "to", type: "address")],
            stateMutability: .nonpayable
        )

        let function2 = AbiFunction(
            name: "transfer",
            inputs: [AbiParameter(name: "to", type: "address")],
            stateMutability: .nonpayable
        )

        #expect(function1 == function2)
    }

    @Test("Different names make functions not equal")
    func testInequalityDifferentNames() {
        let function1 = AbiFunction(name: "transfer", stateMutability: .nonpayable)
        let function2 = AbiFunction(name: "approve", stateMutability: .nonpayable)

        #expect(function1 != function2)
    }

    @Test("Different state mutability makes functions not equal")
    func testInequalityDifferentStateMutability() {
        let function1 = AbiFunction(name: "getValue", stateMutability: .view)
        let function2 = AbiFunction(name: "getValue", stateMutability: .pure)

        #expect(function1 != function2)
    }

    // MARK: - Full Round-trip Test

    @Test("Full round-trip: AbiFunction -> AbiItem -> AbiFunction")
    func testFullRoundTrip() throws {
        let original = AbiFunction(
            name: "transferFrom",
            inputs: [
                AbiParameter(name: "from", type: "address"),
                AbiParameter(name: "to", type: "address"),
                AbiParameter(name: "amount", type: "uint256")
            ],
            outputs: [AbiParameter(name: "success", type: "bool")],
            stateMutability: .nonpayable
        )

        // Convert to AbiItem
        let item = original.toAbiItem()

        // Convert back to AbiFunction
        let roundTripped = try AbiFunction.from(item: item)

        #expect(roundTripped == original)
    }

    // MARK: - Encoding Tests for Different Types

    @Test("Encode function call with address parameter")
    func testEncodeWithAddressParam() throws {
        let function = AbiFunction(
            name: "balanceOf",
            inputs: [AbiParameter(name: "account", type: "address")],
            stateMutability: .view
        )

        let address = "0x1234567890123456789012345678901234567890"
        let encoded = try function.encodeCall(args: [address])

        #expect(encoded.hasPrefix("0x70a08231")) // balanceOf selector
        #expect(encoded.count > 10) // selector + encoded address
    }

    @Test("Encode function call with uint256 parameter")
    func testEncodeWithUint256Param() throws {
        let function = AbiFunction(
            name: "setValue",
            inputs: [AbiParameter(name: "value", type: "uint256")],
            stateMutability: .nonpayable
        )

        let value = BigInt(12345)
        let encoded = try function.encodeCall(args: [value])

        #expect(encoded.count == 74) // 10 chars selector + 64 chars data
    }

    @Test("Encode function call with bool parameter")
    func testEncodeWithBoolParam() throws {
        let function = AbiFunction(
            name: "setActive",
            inputs: [AbiParameter(name: "active", type: "bool")],
            stateMutability: .nonpayable
        )

        let encoded = try function.encodeCall(args: [true])

        #expect(encoded.count == 74) // selector + 64 hex chars for bool
        #expect(encoded.hasSuffix("1")) // true encodes to 1
    }

    @Test("Encode function call with false bool parameter")
    func testEncodeWithFalseBool() throws {
        let function = AbiFunction(
            name: "setActive",
            inputs: [AbiParameter(name: "active", type: "bool")],
            stateMutability: .nonpayable
        )

        let encoded = try function.encodeCall(args: [false])

        #expect(encoded.hasSuffix("0")) // false encodes to 0
    }

    @Test("Encode function with multiple parameters")
    func testEncodeMultipleParams() throws {
        let function = AbiFunction(
            name: "transfer",
            inputs: [
                AbiParameter(name: "to", type: "address"),
                AbiParameter(name: "amount", type: "uint256")
            ],
            stateMutability: .nonpayable
        )

        let encoded = try function.encodeCall(args: [
            "0x1234567890123456789012345678901234567890",
            BigInt(1000)
        ])

        // Selector (10 chars) + address (64 chars) + uint (64 chars) = 138 chars
        #expect(encoded.count == 138)
    }

    @Test("Encode with bytes32 parameter")
    func testEncodeBytes32() throws {
        let function = AbiFunction(
            name: "setHash",
            inputs: [AbiParameter(name: "hash", type: "bytes32")],
            stateMutability: .nonpayable
        )

        let hash = "0x" + String(repeating: "a", count: 64)
        let encoded = try function.encodeCall(args: [hash])

        #expect(encoded.count == 74) // selector + 64 chars
    }

    @Test("Encode with int256 parameter")
    func testEncodeInt256() throws {
        let function = AbiFunction(
            name: "setInt",
            inputs: [AbiParameter(name: "value", type: "int256")],
            stateMutability: .nonpayable
        )

        let value = BigInt(-100)
        let encoded = try function.encodeCall(args: [value])

        #expect(encoded.count == 74)
    }

    @Test("Encode with uint8 parameter")
    func testEncodeUint8() throws {
        let function = AbiFunction(
            name: "setSmallValue",
            inputs: [AbiParameter(name: "value", type: "uint8")],
            stateMutability: .nonpayable
        )

        let encoded = try function.encodeCall(args: [255])

        #expect(encoded.count == 74)
    }

    @Test("Encode with uint value as String")
    func testEncodeUintAsString() throws {
        let function = AbiFunction(
            name: "setValue",
            inputs: [AbiParameter(name: "value", type: "uint256")],
            stateMutability: .nonpayable
        )

        let encoded = try function.encodeCall(args: ["12345"])

        #expect(encoded.count == 74)
    }

    @Test("Encode with bool as integer")
    func testEncodeBoolAsInt() throws {
        let function = AbiFunction(
            name: "setActive",
            inputs: [AbiParameter(name: "active", type: "bool")],
            stateMutability: .nonpayable
        )

        let encoded = try function.encodeCall(args: [1])

        #expect(encoded.hasSuffix("1"))
    }

    @Test("Encode with Address type instead of string")
    func testEncodeWithAddressType() throws {
        let function = AbiFunction(
            name: "setOwner",
            inputs: [AbiParameter(name: "owner", type: "address")],
            stateMutability: .nonpayable
        )

        let address = try Address(fromHexString: "0x1234567890123456789012345678901234567890")
        let encoded = try function.encodeCall(args: [address])

        #expect(encoded.count == 74)
    }

    // MARK: - Encoding Error Tests

    @Test("Throw error for invalid address length")
    func testInvalidAddressLength() {
        let function = AbiFunction(
            name: "test",
            inputs: [AbiParameter(name: "addr", type: "address")],
            stateMutability: .view
        )

        #expect(throws: AbiEncodingError.self) {
            _ = try function.encodeCall(args: ["0x1234"]) // Too short
        }
    }

    @Test("Throw error for invalid address type")
    func testInvalidAddressType() {
        let function = AbiFunction(
            name: "test",
            inputs: [AbiParameter(name: "addr", type: "address")],
            stateMutability: .view
        )

        #expect(throws: AbiEncodingError.self) {
            _ = try function.encodeCall(args: [12345]) // Wrong type
        }
    }

    @Test("Throw error for invalid uint string")
    func testInvalidUintString() {
        let function = AbiFunction(
            name: "test",
            inputs: [AbiParameter(name: "value", type: "uint256")],
            stateMutability: .view
        )

        #expect(throws: AbiEncodingError.self) {
            _ = try function.encodeCall(args: ["notanumber"])
        }
    }

    @Test("Throw error for invalid bool type")
    func testInvalidBoolType() {
        let function = AbiFunction(
            name: "test",
            inputs: [AbiParameter(name: "flag", type: "bool")],
            stateMutability: .view
        )

        #expect(throws: AbiEncodingError.self) {
            _ = try function.encodeCall(args: ["notabool"])
        }
    }

    @Test("Throw error for unsupported type")
    func testUnsupportedType() {
        let function = AbiFunction(
            name: "test",
            inputs: [AbiParameter(name: "data", type: "unsupported")],
            stateMutability: .view
        )

        #expect(throws: AbiEncodingError.self) {
            _ = try function.encodeCall(args: ["data"])
        }
    }

    @Test("Throw error for bytes too large for fixed bytes")
    func testBytesTooLarge() {
        let function = AbiFunction(
            name: "test",
            inputs: [AbiParameter(name: "data", type: "bytes4")],
            stateMutability: .view
        )

        #expect(throws: AbiEncodingError.self) {
            let largeData = Data(repeating: 0xff, count: 10)
            _ = try function.encodeCall(args: [largeData])
        }
    }

    // MARK: - Decoding Tests

    @Test("Decode result with no outputs throws error")
    func testDecodeNoOutputs() {
        let function = AbiFunction(
            name: "test",
            outputs: [],
            stateMutability: .view
        )

        #expect(throws: AbiEncodingError.self) {
            let _: String = try function.decodeResult(data: "0x0000000000000000000000000000000000000000000000000000000000000001")
        }
    }

    @Test("Decode insufficient data throws error")
    func testDecodeInsufficientData() {
        let function = AbiFunction(
            name: "test",
            outputs: [AbiParameter(name: "result", type: "uint256")],
            stateMutability: .view
        )

        #expect(throws: AbiEncodingError.self) {
            let _: UInt64 = try function.decodeResult(data: "0x1234") // Too short
        }
    }

    @Test("Decode uint result")
    func testDecodeUintResult() throws {
        let function = AbiFunction(
            name: "getValue",
            outputs: [AbiParameter(name: "value", type: "uint256")],
            stateMutability: .view
        )

        // Encode 100 as 32-byte hex
        let data = "0x" + String(repeating: "0", count: 62) + "64" // 100 in hex
        let result: BigInt = try function.decodeResult(data: data)

        #expect(result == BigInt(100))
    }

    @Test("Decode bool result")
    func testDecodeBoolResult() throws {
        let function = AbiFunction(
            name: "isActive",
            outputs: [AbiParameter(name: "active", type: "bool")],
            stateMutability: .view
        )

        let data = "0x" + String(repeating: "0", count: 63) + "1"
        let result: Bool = try function.decodeResult(data: data)

        #expect(result == true)
    }

    @Test("Decode address result")
    func testDecodeAddressResult() throws {
        let function = AbiFunction(
            name: "getOwner",
            outputs: [AbiParameter(name: "owner", type: "address")],
            stateMutability: .view
        )

        let address = "1234567890123456789012345678901234567890"
        let data = "0x" + String(repeating: "0", count: 24) + address
        let result: String = try function.decodeResult(data: data)

        #expect(result.lowercased().contains(address.lowercased()))
    }

    @Test("Decode dynamic string throws unsupported error")
    func testDecodeDynamicString() {
        let function = AbiFunction(
            name: "getName",
            outputs: [AbiParameter(name: "name", type: "string")],
            stateMutability: .view
        )

        #expect(throws: AbiEncodingError.self) {
            let _: String = try function.decodeResult(data: "0x0000000000000000000000000000000000000000000000000000000000000020")
        }
    }

    @Test("Decode dynamic bytes throws unsupported error")
    func testDecodeDynamicBytes() {
        let function = AbiFunction(
            name: "getData",
            outputs: [AbiParameter(name: "data", type: "bytes")],
            stateMutability: .view
        )

        #expect(throws: AbiEncodingError.self) {
            let _: Data = try function.decodeResult(data: "0x0000000000000000000000000000000000000000000000000000000000000020")
        }
    }

    // MARK: - AbiEncodingError Tests

    @Test("AbiEncodingError invalidSignature")
    func testAbiEncodingErrorInvalidSignature() {
        let error = AbiEncodingError.invalidSignature
        #expect(error.errorDescription != nil)
    }

    @Test("AbiEncodingError argumentCountMismatch")
    func testAbiEncodingErrorArgumentMismatch() {
        let error = AbiEncodingError.argumentCountMismatch(expected: 2, got: 1)
        let description = error.errorDescription ?? ""
        #expect(description.contains("2"))
        #expect(description.contains("1"))
    }

    @Test("AbiEncodingError unsupportedType")
    func testAbiEncodingErrorUnsupportedType() {
        let error = AbiEncodingError.unsupportedType("array")
        let description = error.errorDescription ?? ""
        #expect(description.contains("array"))
    }

    @Test("AbiEncodingError invalidValue")
    func testAbiEncodingErrorInvalidValue() {
        let error = AbiEncodingError.invalidValue(expected: "address", got: "123")
        let description = error.errorDescription ?? ""
        #expect(description.contains("address"))
        #expect(description.contains("123"))
    }

    @Test("AbiEncodingError invalidAddressLength")
    func testAbiEncodingErrorInvalidAddressLength() {
        let error = AbiEncodingError.invalidAddressLength
        #expect(error.errorDescription != nil)
    }

    @Test("AbiEncodingError invalidHexString")
    func testAbiEncodingErrorInvalidHexString() {
        let error = AbiEncodingError.invalidHexString
        #expect(error.errorDescription != nil)
    }

    @Test("AbiEncodingError insufficientData")
    func testAbiEncodingErrorInsufficientData() {
        let error = AbiEncodingError.insufficientData
        #expect(error.errorDescription != nil)
    }

    @Test("AbiEncodingError noOutputs")
    func testAbiEncodingErrorNoOutputs() {
        let error = AbiEncodingError.noOutputs
        #expect(error.errorDescription != nil)
    }

    @Test("AbiEncodingError decodingFailed")
    func testAbiEncodingErrorDecodingFailed() {
        let error = AbiEncodingError.decodingFailed("test error")
        let description = error.errorDescription ?? ""
        #expect(description.contains("test error"))
    }
}
