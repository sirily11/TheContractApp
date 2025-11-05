import Foundation
import Testing

@testable import EvmCore

// MARK: - Test Data

let sampleFunctionAbi = """
  {
    "type": "function",
    "name": "transfer",
    "inputs": [
      {
        "name": "recipient",
        "type": "address"
      },
      {
        "name": "amount",
        "type": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool"
      }
    ],
    "stateMutability": "nonpayable"
  }
  """

let sampleEventAbi = """
  {
    "type": "event",
    "name": "Transfer",
    "inputs": [
      {
        "name": "from",
        "type": "address",
        "indexed": true
      },
      {
        "name": "to",
        "type": "address",
        "indexed": true
      },
      {
        "name": "value",
        "type": "uint256",
        "indexed": false
      }
    ],
    "anonymous": false
  }
  """

let sampleAbiArray = """
  [
    {
      "type": "constructor",
      "inputs": [
        {
          "name": "initialSupply",
          "type": "uint256"
        }
      ],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "balanceOf",
      "inputs": [
        {
          "name": "account",
          "type": "address"
        }
      ],
      "outputs": [
        {
          "name": "",
          "type": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "transfer",
      "inputs": [
        {
          "name": "recipient",
          "type": "address"
        },
        {
          "name": "amount",
          "type": "uint256"
        }
      ],
      "outputs": [
        {
          "name": "",
          "type": "bool"
        }
      ],
      "stateMutability": "nonpayable"
    },
    {
      "type": "event",
      "name": "Transfer",
      "inputs": [
        {
          "name": "from",
          "type": "address",
          "indexed": true
        },
        {
          "name": "to",
          "type": "address",
          "indexed": true
        },
        {
          "name": "value",
          "type": "uint256",
          "indexed": false
        }
      ],
      "anonymous": false
    },
    {
      "type": "error",
      "name": "InsufficientBalance",
      "inputs": [
        {
          "name": "available",
          "type": "uint256"
        },
        {
          "name": "required",
          "type": "uint256"
        }
      ]
    }
  ]
  """

let complexAbiWithStructs = """
  [
    {
      "type": "function",
      "name": "createOrder",
      "inputs": [
        {
          "name": "order",
          "type": "tuple",
          "components": [
            {
              "name": "id",
              "type": "uint256"
            },
            {
              "name": "buyer",
              "type": "address"
            },
            {
              "name": "items",
              "type": "tuple[]",
              "components": [
                {
                  "name": "productId",
                  "type": "uint256"
                },
                {
                  "name": "quantity",
                  "type": "uint256"
                }
              ]
            }
          ]
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    }
  ]
  """

// MARK: - Basic Parsing Tests

@Test("Parse single function ABI object from string")
func testParseSingleFunctionObject() throws {
  let parser = try AbiParser(fromObjectString: sampleFunctionAbi)

  #expect(parser.items.count == 1)
  #expect(parser.functions.count == 1)

  let function = parser.functions[0]
  #expect(function.name == "transfer")
  #expect(function.inputs?.count == 2)
  #expect(function.inputs?[0].name == "recipient")
  #expect(function.inputs?[0].type == "address")
  #expect(function.inputs?[1].name == "amount")
  #expect(function.inputs?[1].type == "uint256")
  #expect(function.outputs?.count == 1)
  #expect(function.outputs?[0].type == "bool")
  #expect(function.stateMutability == .nonpayable)
}

@Test("Parse single event ABI object from string")
func testParseSingleEventObject() throws {
  let parser = try AbiParser(fromObjectString: sampleEventAbi)

  #expect(parser.items.count == 1)
  #expect(parser.events.count == 1)

  let event = parser.events[0]
  #expect(event.name == "Transfer")
  #expect(event.inputs?.count == 3)
  #expect(event.inputs?[0].indexed == true)
  #expect(event.inputs?[1].indexed == true)
  #expect(event.inputs?[2].indexed == false)
  #expect(event.anonymous == false)
}

@Test("Parse ABI array from string")
func testParseAbiArray() throws {
  let parser = try AbiParser(fromJsonString: sampleAbiArray)

  #expect(parser.items.count == 5)
  #expect(parser.functions.count == 2)
  #expect(parser.events.count == 1)
  #expect(parser.errors.count == 1)
  #expect(parser.constructor != nil)
}

@Test("Parse complex ABI with nested structs")
func testParseComplexAbiWithStructs() throws {
  let parser = try AbiParser(fromJsonString: complexAbiWithStructs)

  #expect(parser.items.count == 1)
  #expect(parser.functions.count == 1)

  let function = parser.functions[0]
  #expect(function.name == "createOrder")
  #expect(function.inputs?.count == 1)
  #expect(function.inputs?[0].type == "tuple")
  #expect(function.inputs?[0].components?.count == 3)

  // Check nested components
  let orderComponents = function.inputs![0].components!
  #expect(orderComponents[0].name == "id")
  #expect(orderComponents[2].name == "items")
  #expect(orderComponents[2].type == "tuple[]")
  #expect(orderComponents[2].components?.count == 2)
}

// MARK: - Constructor Tests

@Test("Initialize parser from JSON data")
func testInitFromData() throws {
  guard let data = sampleAbiArray.data(using: .utf8) else {
    Issue.record("Failed to convert string to data")
    return
  }

  let parser = try AbiParser(fromData: data)
  #expect(parser.items.count == 5)
}

@Test("Initialize parser from items array")
func testInitFromItems() {
  let items = [
    AbiItem(
      type: .function,
      name: "test",
      inputs: [],
      outputs: [],
      stateMutability: .view
    )
  ]

  let parser = AbiParser(items: items)
  #expect(parser.items.count == 1)
  #expect(parser.functions.count == 1)
}

// MARK: - File I/O Tests

@Test("Parse ABI from file and write back")
func testFileIO() throws {
  let tempDir = FileManager.default.temporaryDirectory
  let inputFile = tempDir.appendingPathComponent("test_abi_input.json")
  let outputFile = tempDir.appendingPathComponent("test_abi_output.json")

  // Write test data to file
  try sampleAbiArray.write(to: inputFile, atomically: true, encoding: .utf8)

  // Parse from file using file path
  let parser1 = try AbiParser(fromFile: inputFile.path)
  #expect(parser1.items.count == 5)

  // Parse from file using URL
  let parser2 = try AbiParser(fromFileURL: inputFile)
  #expect(parser2.items.count == 5)

  // Write back to file
  try parser1.write(toFile: outputFile.path, prettyPrinted: true)

  // Verify written file can be parsed
  let parser3 = try AbiParser(fromFile: outputFile.path)
  #expect(parser3.items.count == 5)

  // Clean up
  try? FileManager.default.removeItem(at: inputFile)
  try? FileManager.default.removeItem(at: outputFile)
}

// MARK: - Query Method Tests

@Test("Query functions by name")
func testQueryFunctionsByName() throws {
  let parser = try AbiParser(fromJsonString: sampleAbiArray)

  let transferFunctions = parser.function(named: "transfer")
  #expect(transferFunctions.count == 1)
  #expect(transferFunctions[0].name == "transfer")

  let balanceOfFunctions = parser.function(named: "balanceOf")
  #expect(balanceOfFunctions.count == 1)
  #expect(balanceOfFunctions[0].name == "balanceOf")

  let nonExistent = parser.function(named: "nonExistent")
  #expect(nonExistent.isEmpty)
}

@Test("Query events by name")
func testQueryEventsByName() throws {
  let parser = try AbiParser(fromJsonString: sampleAbiArray)

  let transferEvents = parser.event(named: "Transfer")
  #expect(transferEvents.count == 1)
  #expect(transferEvents[0].name == "Transfer")

  let nonExistent = parser.event(named: "Approval")
  #expect(nonExistent.isEmpty)
}

@Test("Get constructor")
func testGetConstructor() throws {
  let parser = try AbiParser(fromJsonString: sampleAbiArray)

  let constructor = parser.constructor
  #expect(constructor != nil)
  #expect(constructor?.type == .constructor)
  #expect(constructor?.inputs?.count == 1)
  #expect(constructor?.inputs?[0].name == "initialSupply")
}

@Test("Get all functions, events, and errors")
func testGetAllItemTypes() throws {
  let parser = try AbiParser(fromJsonString: sampleAbiArray)

  #expect(parser.functions.count == 2)
  #expect(parser.events.count == 1)
  #expect(parser.errors.count == 1)

  // Verify all functions are actually functions
  for function in parser.functions {
    #expect(function.type == .function)
  }

  // Verify all events are actually events
  for event in parser.events {
    #expect(event.type == .event)
  }

  // Verify all errors are actually errors
  for error in parser.errors {
    #expect(error.type == .error)
  }
}

// MARK: - Error Handling Tests

@Test("Handle invalid JSON string")
func testInvalidJsonString() {
  let invalidJson = "{ this is not valid json }"

  #expect(throws: Error.self) {
    try AbiParser(fromJsonString: invalidJson)
  }
}

@Test("Handle invalid ABI format")
func testInvalidAbiFormat() {
  let invalidAbi = """
    {
      "notAnAbi": "value"
    }
    """

  #expect(throws: AbiParserError.self) {
    try AbiParser(fromJsonString: invalidAbi)
  }
}

@Test("Handle non-existent file")
func testNonExistentFile() {
  let nonExistentPath = "/tmp/non_existent_abi_file_12345.json"

  #expect(throws: Error.self) {
    try AbiParser(fromFile: nonExistentPath)
  }
}

// MARK: - Round-trip Tests

@Test("Round-trip conversion maintains data")
func testRoundTrip() throws {
  let parser1 = try AbiParser(fromJsonString: sampleAbiArray)

  // Convert back to JSON
  let jsonString = try parser1.toJsonString(prettyPrinted: false)

  // Parse again
  let parser2 = try AbiParser(fromJsonString: jsonString)

  // Verify same number of items
  #expect(parser1.items.count == parser2.items.count)
  #expect(parser1.functions.count == parser2.functions.count)
  #expect(parser1.events.count == parser2.events.count)
  #expect(parser1.errors.count == parser2.errors.count)
}

@Test("Pretty printed JSON format")
func testPrettyPrintedJson() throws {
  let parser = try AbiParser(fromJsonString: sampleAbiArray)

  let prettyJson = try parser.toJsonString(prettyPrinted: true)

  // Pretty printed JSON should contain newlines
  #expect(prettyJson.contains("\n"))

  // Should be parseable
  let parser2 = try AbiParser(fromJsonString: prettyJson)
  #expect(parser2.items.count == parser.items.count)
}

// MARK: - Description Tests

@Test("Parser description")
func testParserDescription() throws {
  let parser = try AbiParser(fromJsonString: sampleAbiArray)

  let description = parser.description
  #expect(description.contains("Functions: 2"))
  #expect(description.contains("Events: 1"))
  #expect(description.contains("Errors: 1"))
  #expect(description.contains("Constructor: Yes"))
}

// MARK: - Edge Cases

@Test("Parse empty ABI array")
func testEmptyAbiArray() throws {
  let emptyAbi = "[]"
  let parser = try AbiParser(fromJsonString: emptyAbi)

  #expect(parser.items.isEmpty)
  #expect(parser.functions.isEmpty)
  #expect(parser.events.isEmpty)
  #expect(parser.errors.isEmpty)
  #expect(parser.constructor == nil)
}

@Test("Parse ABI with all optional fields")
func testOptionalFields() throws {
  let minimalFunction = """
    {
      "type": "function",
      "name": "minimal",
      "inputs": [],
      "outputs": []
    }
    """

  let parser = try AbiParser(fromObjectString: minimalFunction)
  let function = parser.functions[0]

  #expect(function.name == "minimal")
  #expect(function.inputs?.isEmpty == true)
  #expect(function.outputs?.isEmpty == true)
  #expect(function.stateMutability == nil)
}

@Test("Parse receive and fallback functions")
func testReceiveAndFallback() throws {
  let specialFunctions = """
    [
      {
        "type": "receive",
        "stateMutability": "payable"
      },
      {
        "type": "fallback",
        "stateMutability": "payable"
      }
    ]
    """

  let parser = try AbiParser(fromJsonString: specialFunctions)

  #expect(parser.items.count == 2)
  #expect(parser.items[0].type == .receive)
  #expect(parser.items[1].type == .fallback)
}

@Test("Multiple overloaded functions")
func testOverloadedFunctions() throws {
  let overloadedAbi = """
    [
      {
        "type": "function",
        "name": "transfer",
        "inputs": [
          {
            "name": "to",
            "type": "address"
          },
          {
            "name": "amount",
            "type": "uint256"
          }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
      },
      {
        "type": "function",
        "name": "transfer",
        "inputs": [
          {
            "name": "to",
            "type": "address"
          },
          {
            "name": "amount",
            "type": "uint256"
          },
          {
            "name": "data",
            "type": "bytes"
          }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
      }
    ]
    """

  let parser = try AbiParser(fromJsonString: overloadedAbi)

  let transferFunctions = parser.function(named: "transfer")
  #expect(transferFunctions.count == 2)
  #expect(transferFunctions[0].inputs?.count == 2)
  #expect(transferFunctions[1].inputs?.count == 3)
}
