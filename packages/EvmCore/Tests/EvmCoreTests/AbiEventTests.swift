import Testing
import Foundation
@testable import EvmCore

/// Tests for AbiEvent type
@Suite("AbiEvent Tests")
struct AbiEventTests {

    // MARK: - Initialization Tests

    @Test("Initialize AbiEvent with all parameters")
    func testInitialization() {
        let inputs = [
            AbiParameter(name: "from", type: "address", indexed: true),
            AbiParameter(name: "to", type: "address", indexed: true),
            AbiParameter(name: "value", type: "uint256", indexed: false)
        ]

        let event = AbiEvent(
            name: "Transfer",
            inputs: inputs,
            anonymous: false
        )

        #expect(event.name == "Transfer")
        #expect(event.inputs.count == 3)
        #expect(event.anonymous == false)
    }

    @Test("Initialize AbiEvent with default parameters")
    func testInitializationWithDefaults() {
        let event = AbiEvent(name: "MyEvent")

        #expect(event.name == "MyEvent")
        #expect(event.inputs.isEmpty)
        #expect(event.anonymous == false)
    }

    @Test("Initialize anonymous event")
    func testAnonymousEvent() {
        let event = AbiEvent(name: "Anonymous", inputs: [], anonymous: true)

        #expect(event.anonymous == true)
    }

    // MARK: - toAbiItem Conversion Tests

    @Test("Convert AbiEvent to AbiItem")
    func testToAbiItem() {
        let inputs = [
            AbiParameter(name: "value", type: "uint256", indexed: false)
        ]
        let event = AbiEvent(name: "ValueChanged", inputs: inputs, anonymous: false)

        let item = event.toAbiItem()

        #expect(item.type == .event)
        #expect(item.name == "ValueChanged")
        #expect(item.inputs?.count == 1)
        #expect(item.anonymous == false)
        #expect(item.outputs == nil)
        #expect(item.stateMutability == nil)
    }

    @Test("Convert anonymous AbiEvent to AbiItem")
    func testToAbiItemAnonymous() {
        let event = AbiEvent(name: "AnonymousEvent", inputs: [], anonymous: true)
        let item = event.toAbiItem()

        #expect(item.anonymous == true)
    }

    // MARK: - from AbiItem Conversion Tests

    @Test("Create AbiEvent from valid AbiItem")
    func testFromValidAbiItem() throws {
        let item = AbiItem(
            type: .event,
            name: "Transfer",
            inputs: [
                AbiParameter(name: "from", type: "address", indexed: true),
                AbiParameter(name: "to", type: "address", indexed: true)
            ],
            outputs: nil,
            stateMutability: nil,
            anonymous: false,
            constant: nil,
            payable: nil
        )

        let event = try AbiEvent.from(item: item)

        #expect(event.name == "Transfer")
        #expect(event.inputs.count == 2)
        #expect(event.anonymous == false)
    }

    @Test("Create AbiEvent from AbiItem with no inputs")
    func testFromAbiItemNoInputs() throws {
        let item = AbiItem(
            type: .event,
            name: "SimpleEvent",
            inputs: nil,
            outputs: nil,
            stateMutability: nil,
            anonymous: nil,
            constant: nil,
            payable: nil
        )

        let event = try AbiEvent.from(item: item)

        #expect(event.name == "SimpleEvent")
        #expect(event.inputs.isEmpty)
        #expect(event.anonymous == false)
    }

    @Test("Create AbiEvent from anonymous AbiItem")
    func testFromAnonymousAbiItem() throws {
        let item = AbiItem(
            type: .event,
            name: "AnonymousEvent",
            inputs: [],
            outputs: nil,
            stateMutability: nil,
            anonymous: true,
            constant: nil,
            payable: nil
        )

        let event = try AbiEvent.from(item: item)

        #expect(event.anonymous == true)
    }

    @Test("Throw error when creating AbiEvent from non-event AbiItem")
    func testFromNonEventAbiItem() {
        let functionItem = AbiItem(
            type: .function,
            name: "transfer",
            inputs: [],
            outputs: [],
            stateMutability: .nonpayable,
            anonymous: nil,
            constant: nil,
            payable: nil
        )

        #expect(throws: AbiParserError.self) {
            try AbiEvent.from(item: functionItem)
        }
    }

    @Test("Throw error when AbiItem is missing name")
    func testFromAbiItemMissingName() {
        let item = AbiItem(
            type: .event,
            name: nil,
            inputs: [],
            outputs: nil,
            stateMutability: nil,
            anonymous: nil,
            constant: nil,
            payable: nil
        )

        #expect(throws: AbiParserError.self) {
            try AbiEvent.from(item: item)
        }
    }

    // MARK: - Codable Tests

    @Test("Encode AbiEvent to JSON")
    func testEncodable() throws {
        let event = AbiEvent(
            name: "Transfer",
            inputs: [
                AbiParameter(name: "from", type: "address", indexed: true)
            ],
            anonymous: false
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(event)

        #expect(data.count > 0)

        // Decode to verify structure
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AbiEvent.self, from: data)
        #expect(decoded.name == "Transfer")
    }

    @Test("Decode AbiEvent from JSON")
    func testDecodable() throws {
        let json = """
        {
            "name": "Approval",
            "inputs": [
                {"name": "owner", "type": "address", "indexed": true},
                {"name": "spender", "type": "address", "indexed": true},
                {"name": "value", "type": "uint256", "indexed": false}
            ],
            "anonymous": false
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let event = try decoder.decode(AbiEvent.self, from: data)

        #expect(event.name == "Approval")
        #expect(event.inputs.count == 3)
        #expect(event.anonymous == false)
    }

    @Test("Round-trip encode and decode AbiEvent")
    func testRoundTripCoding() throws {
        let original = AbiEvent(
            name: "ValueChanged",
            inputs: [
                AbiParameter(name: "oldValue", type: "uint256", indexed: false),
                AbiParameter(name: "newValue", type: "uint256", indexed: false)
            ],
            anonymous: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AbiEvent.self, from: data)

        #expect(decoded == original)
    }

    // MARK: - Equatable Tests

    @Test("Equal AbiEvents are equal")
    func testEquality() {
        let event1 = AbiEvent(
            name: "Transfer",
            inputs: [AbiParameter(name: "value", type: "uint256", indexed: false)],
            anonymous: false
        )

        let event2 = AbiEvent(
            name: "Transfer",
            inputs: [AbiParameter(name: "value", type: "uint256", indexed: false)],
            anonymous: false
        )

        #expect(event1 == event2)
    }

    @Test("Different names make AbiEvents not equal")
    func testInequalityDifferentNames() {
        let event1 = AbiEvent(name: "Event1")
        let event2 = AbiEvent(name: "Event2")

        #expect(event1 != event2)
    }

    @Test("Different inputs make AbiEvents not equal")
    func testInequalityDifferentInputs() {
        let event1 = AbiEvent(
            name: "Event",
            inputs: [AbiParameter(name: "a", type: "uint256", indexed: false)]
        )
        let event2 = AbiEvent(
            name: "Event",
            inputs: [AbiParameter(name: "b", type: "uint256", indexed: false)]
        )

        #expect(event1 != event2)
    }

    @Test("Different anonymous flag makes AbiEvents not equal")
    func testInequalityDifferentAnonymous() {
        let event1 = AbiEvent(name: "Event", anonymous: false)
        let event2 = AbiEvent(name: "Event", anonymous: true)

        #expect(event1 != event2)
    }

    // MARK: - Integration Tests

    @Test("Full round-trip: AbiEvent -> AbiItem -> AbiEvent")
    func testFullRoundTrip() throws {
        let original = AbiEvent(
            name: "MyEvent",
            inputs: [
                AbiParameter(name: "param1", type: "address", indexed: true),
                AbiParameter(name: "param2", type: "uint256", indexed: false)
            ],
            anonymous: false
        )

        // Convert to AbiItem
        let item = original.toAbiItem()

        // Convert back to AbiEvent
        let roundTripped = try AbiEvent.from(item: item)

        #expect(roundTripped == original)
    }
}
