# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SmartContractApp is a SwiftUI macOS/iOS application for interacting with EVM-based smart contracts. The project consists of:

1. **SmartContractApp** (main app): SwiftUI app with SwiftData persistence
2. **EvmCore** (packages/EvmCore): Local Swift package providing core EVM functionality
3. **Solidity** (packages/EvmCore/Sources/Solidity): Solidity compiler integration

## Build and Test Commands

### Building the App
```bash
# Build the Xcode project
xcodebuild -scheme SmartContractApp -configuration Debug build

# Build for running on device
xcodebuild -scheme SmartContractApp -configuration Debug -sdk iphoneos build

# Build the EvmCore package directly
swift build --package-path packages/EvmCore
```

### Running Tests
```bash
# Run all tests for the Xcode project
xcodebuild test -scheme SmartContractApp

# Run EvmCore package tests
swift test --package-path packages/EvmCore

# Run specific test
swift test --package-path packages/EvmCore --filter EvmClientE2ETests

# Run specific test method
swift test --package-path packages/EvmCore --filter EvmClientE2ETests.testBlockNumber
```

### Running the App
Open `SmartContractApp.xcodeproj` in Xcode and run the SmartContractApp scheme, or:
```bash
xcodebuild -scheme SmartContractApp -configuration Debug -destination 'platform=macOS' run
```

## Architecture

### App Structure (SwiftUI + SwiftData)

The app uses a three-column `NavigationSplitView` pattern:
- **Sidebar**: Category selection (Endpoints, ABI, Contract, Wallet)
- **Content**: List/management view for selected category
- **Detail**: Detailed view for selected item

**Data Models** (SwiftData `@Model`):
- `Endpoint`: RPC endpoint configuration (name, URL, chainId)
- `EVMContract`: Smart contract instances
- `EvmAbi`: ABI definitions
- `Wallet`: Wallet management
- `Config`: App configuration

### EvmCore Package Structure

Located in `packages/EvmCore/Sources/EvmCore/`:

- **client/**: EVM RPC client implementations
  - `EvmClient`: Read-only client for blockchain queries
  - `EvmClientWithSigner`: Client with signing capabilities for transactions
  - Provides methods for: block info, account queries, transactions, filters, gas estimation

- **contract/**: Smart contract interaction
  - `Contract`: Base contract protocol
  - `EvmContract`: Contract interaction with ABI
  - `DeployableEvmContract`: Contract deployment and interaction

- **signer/**: Transaction signing
  - `Signer`: Protocol for signing operations
  - `PrivateKeySigner`: ECDSA signing with private keys
  - `AnvilSigner`: Test signer for Anvil (local dev)

- **abi/**: ABI encoding/decoding
  - Encode function calls and parameters
  - Decode function results and event logs

- **transaction/**: Transaction building and signing
  - EIP-1559 (Type 2) transaction support
  - Transaction serialization and signing

- **transport/**: RPC communication
  - `HttpTransport`: HTTP/HTTPS JSON-RPC transport

- **types/**: Core EVM types
  - Address, Block, Transaction, Log, etc.

- **utils/**: Utility functions
  - Hex encoding/decoding
  - Keccak256 hashing

### Solidity Package

Located in `packages/EvmCore/Sources/Solidity/`:

- `JSCoreCompiler`: JavaScript-based Solidity compiler using JavaScriptCore
- `DownloadManager`: Downloads Solidity compiler binaries
- `ImportResolver`: Resolves import statements in Solidity code
- `Types`: Compilation result types

## Key Design Patterns

### Client Pattern
The `EvmClient` provides a clean separation:
- Read-only operations: Use `EvmClient` directly
- Write operations: Use `client.withSigner(signer)` to get `EvmClientWithSigner`

Example:
```swift
let client = EvmClient(transport: HttpTransport(url: "https://..."))
let blockNumber = try await client.blockNumber()

let signer = try PrivateKeySigner(privateKey: "0x...")
let signerClient = client.withSigner(signer: signer)
let hash = try await signerClient.sendTransaction(...)
```

### Contract Interaction
Contracts use ABI-driven type-safe interactions:
```swift
let contract = try EvmContract(
    address: "0x...",
    abi: abiJson,
    client: client
)
let result = try await contract.read(functionName: "balanceOf", args: [address])
```

### Transport Abstraction
All network communication goes through the `Transport` protocol, making it easy to:
- Mock for testing
- Switch between HTTP/WebSocket
- Add middleware (logging, rate limiting, etc.)

## Dependencies

External packages (managed via Swift Package Manager):
- **BigInt** (attaswift/BigInt): Large number arithmetic for EVM values
- **CryptoSwift** (krzyzanowskim/CryptoSwift): Cryptographic operations
- **secp256k1.swift** (GigaBitcoin/secp256k1.swift): ECDSA signing (P256K product)

## Testing Strategy

### E2E Tests
E2E tests (suffix `E2ETests`) require a running Anvil instance:
```bash
# Start Anvil (in separate terminal)
anvil

# Run E2E tests
swift test --package-path packages/EvmCore --filter E2E
```

### Unit Tests
Unit tests mock transport/dependencies and don't require external services:
```bash
swift test --package-path packages/EvmCore --skip E2E
```

## File Organization Conventions

### App Code
- `SmartContractApp/Models/`: SwiftData models
- `SmartContractApp/Views/`: SwiftUI views organized by feature
  - `Views/<Feature>/`: Feature-specific views (e.g., `Views/Endpoint/`)
- `SmartContractApp/SmartContractAppApp.swift`: App entry point with ModelContainer setup

### Package Code
- Follow Swift package conventions: `Sources/<TargetName>/`
- Group related functionality in subdirectories
- Test files mirror source structure: `Tests/<TargetName>Tests/`

## Common Development Tasks

### Adding a New View Category
1. Add case to `SidebarCategory` enum in [ContentView.swift](SmartContractApp/ContentView.swift)
2. Create view files in `SmartContractApp/Views/<CategoryName>/`
3. Add switch case in `ContentView` body
4. Add corresponding SwiftData model if needed

### Adding EVM Client Methods
1. Add method to `EvmRpcClientProtocol` in [client/client.swift](packages/EvmCore/Sources/EvmCore/client/client.swift)
2. Implement in `EvmClient` or `EvmClientWithSigner` in [client/evm.swift](packages/EvmCore/Sources/EvmCore/client/evm.swift)
3. Add tests in `Tests/EvmCoreTests/EvmClientE2ETests.swift`

### Working with ABIs
- ABI encoding/decoding is in `packages/EvmCore/Sources/EvmCore/abi/`
- The ABI parser handles function and event signatures
- Contract calls automatically encode arguments and decode results

### Adding a New Signer
1. Implement `Signer` protocol from [signer/signer.swift](packages/EvmCore/Sources/EvmCore/signer/signer.swift)
2. Implement required methods: `getAddress()`, `signMessage()`, `signTransaction()`
3. Add tests following pattern in `PrivateKeySignerTests.swift`

## Platform Requirements

- **macOS**: 12.0+
- **iOS**: 15.0+
- **Swift**: 6.2+
- **Xcode**: Latest stable version recommended
