# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

EvmCore is a Swift Package Manager (SPM) library that provides core Ethereum/EVM functionality for iOS/macOS applications. It's part of the larger SmartContractApp project and handles low-level blockchain interactions.

## Development Commands

### Building
```bash
make build           # Build the package
swift build          # Direct SPM build
```

### Testing
```bash
make test            # Run all tests (starts Anvil network automatically)
swift test           # Run tests directly without network setup
```

**Important**: Tests depend on Anvil (Ethereum local test node). The `make test` command handles starting/stopping Anvil automatically. If you run `swift test` directly, ensure Anvil is running separately with `make e2e-network`.

### Formatting and Linting
```bash
make fmt             # Format code using swift format
make lint            # Lint code using swiftformat
```

## Architecture

The library is organized into four main modules:

### 1. ABI Parser (`abi/`)
- **Purpose**: Parse and manipulate Ethereum contract ABIs (Application Binary Interfaces)
- **Key Types**: `AbiParser`, `AbiItem`, `AbiParameter`, `AbiItemType`, `StateMutability`
- **Capabilities**:
  - Parse ABI from JSON strings, files, or Data
  - Query functions, events, errors, and constructors by name
  - Support for complex types including tuples and nested structs
  - Round-trip serialization (parse → modify → write back)
- **Usage Pattern**: Create parser from JSON, query items by name or type, access structured metadata

### 2. Transport Layer (`transport/`)
- **Purpose**: Abstract RPC communication with Ethereum nodes
- **Key Types**: `Transport` protocol, `RpcRequest`, `RpcResponse`
- **Pattern**: Protocol-based design for pluggable transport implementations
- **Note**: Uses `AnyCodable` for flexible parameter and result handling

### 3. Signer Interface (`signer/`)
- **Purpose**: Abstract cryptographic signing operations
- **Key Types**: `Signer` protocol, `Address`
- **Methods**: `sign(message:)`, `verify(address:message:signature:)`
- **Pattern**: Protocol-based design allowing different signing strategies (private key, hardware wallet, etc.)
- **Note**: All methods are async/throws for flexibility with different signing backends

### 4. Core Types (`types/`)
- **Purpose**: Common utility types used across the library
- **Key Types**: `AnyCodable`
- **AnyCodable**: Type-erased Codable wrapper supporting dynamic JSON encoding/decoding, essential for RPC communication where parameter/return types vary

## Testing Approach

- Uses **Swift Testing framework** (not XCTest) - all tests use `@Test` macro syntax
- Test files use `@testable import EvmCore` to access internal APIs
- Comprehensive test coverage for ABI parsing including:
  - Basic parsing (functions, events, errors, constructors)
  - Complex types (nested tuples/structs)
  - File I/O operations
  - Error handling
  - Edge cases (empty arrays, overloaded functions, optional fields)

### Running Individual Tests
```bash
swift test --filter testParseSingleFunctionObject
```

## Key Design Principles

1. **Protocol-First Design**: Core abstractions (Transport, Signer) are defined as protocols to allow multiple implementations
2. **Type Safety**: Strong typing for ABI items, parameters, and types rather than stringly-typed APIs
3. **Async/Await**: Modern Swift concurrency for all I/O and signing operations
4. **Flexibility**: AnyCodable pattern enables working with dynamic JSON structures common in blockchain RPC
5. **Composability**: Small, focused modules that can be used independently or together

## Swift Version

Requires Swift 6.2+ (specified in Package.swift)
