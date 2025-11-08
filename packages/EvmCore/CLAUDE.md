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

The library is organized into five main modules:

### 1. EvmCore (`Sources/EvmCore/`)
The core EVM interaction module with the following components:

#### ABI Parser (`abi/`)
- **Purpose**: Parse and manipulate Ethereum contract ABIs (Application Binary Interfaces)
- **Key Types**: `AbiParser`, `AbiItem`, `AbiParameter`, `AbiItemType`, `StateMutability`
- **Capabilities**:
  - Parse ABI from JSON strings, files, or Data
  - Query functions, events, errors, and constructors by name
  - Support for complex types including tuples and nested structs
  - Round-trip serialization (parse → modify → write back)
- **Usage Pattern**: Create parser from JSON, query items by name or type, access structured metadata

#### Transport Layer (`transport/`)
- **Purpose**: Abstract RPC communication with Ethereum nodes
- **Key Types**: `Transport` protocol, `RpcRequest`, `RpcResponse`
- **Pattern**: Protocol-based design for pluggable transport implementations
- **Note**: Uses `AnyCodable` for flexible parameter and result handling

#### Signer Interface (`signer/`)
- **Purpose**: Abstract cryptographic signing operations
- **Key Types**: `Signer` protocol, `PrivateKeySigner`
- **Methods**: `sign(message:)`, `verify(address:message:signature:)`
- **Pattern**: Protocol-based design allowing different signing strategies (private key, hardware wallet, etc.)
- **Note**: All methods are async/throws for flexibility with different signing backends

#### Core Types (`types/`)
- **Purpose**: Common utility types used across the library
- **Key Types**: `AnyCodable`
- **AnyCodable**: Type-erased Codable wrapper supporting dynamic JSON encoding/decoding, essential for RPC communication where parameter/return types vary

### 2. BIP39 (`Sources/BIP39/`)
BIP39 mnemonic phrase and BIP32 hierarchical deterministic key derivation implementation for Ethereum wallets.

#### Key Components
- **Mnemonic** (`Implementation/Mnemonic.swift`): BIP39 mnemonic phrase generation and validation
  - Generate random mnemonics (12, 15, 18, 21, or 24 words)
  - Validate existing mnemonics with checksum verification
  - Convert mnemonics to seeds using PBKDF2
  - Derive private keys using BIP32 derivation paths

- **BIP32** (`Implementation/BIP32.swift`): Hierarchical deterministic key derivation
  - Derive master keys from seeds
  - Child key derivation (both hardened and non-hardened)
  - Full derivation path support (e.g., "m/44'/60'/0'/0/0")

- **DerivationPath** (`Implementation/DerivationPath.swift`): Path parsing and management
  - Predefined paths (`.ethereum` = "m/44'/60'/0'/0/0")
  - Custom path support
  - Path validation and parsing

- **Wordlist** (`Implementation/Wordlist.swift`): BIP39 wordlists
  - English wordlist (2048 words)
  - Extensible for other languages

#### Usage Example
```swift
// Generate a new mnemonic
let mnemonic = try Mnemonic.generate(wordCount: .twelve)

// Or use existing mnemonic
let mnemonic = try Mnemonic(phrase: "your twelve word mnemonic phrase here...")

// Derive Ethereum private key
let privateKey = try mnemonic.privateKey(derivePath: .ethereum)

// Derive with custom path
let customKey = try mnemonic.privateKey(derivePath: .custom("m/44'/60'/0'/0/1"))

// Create a signer from the private key
let signer = try PrivateKeySigner(hexPrivateKey: privateKey)
let address = signer.address
```

#### Testing
- Test vectors in `Tests/BIP39Tests/words.json` contain 500+ validated mnemonic → private key → address mappings
- Run BIP39 tests: `swift test --filter BIP39Tests`
- Tests validate:
  - Mnemonic generation and validation
  - Seed derivation (PBKDF2 with 2048 iterations)
  - BIP32 key derivation
  - Address derivation from private keys
  - Deterministic key generation
  - Multiple derivation path support

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
