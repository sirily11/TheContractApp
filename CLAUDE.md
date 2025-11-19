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

# EvmCore package test coverage
cd packages/EvmCore && make coverage          # Run tests with coverage and show summary
cd packages/EvmCore && make coverage-html     # Generate interactive HTML coverage report
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

**ViewModels** (`@Observable`):
- `WalletSignerViewModel`: Manages wallet signing and transaction queuing
- `ContractInteractionViewModel`: Handles contract function execution
- `ContractDeploymentViewModel`: Manages contract deployment

### ViewModel Pattern

The app uses `@Observable` view models (Swift's Observation framework) for managing app state and business logic. ViewModels are injected into the SwiftUI environment and require dependencies to be set via property injection.

#### Creating a ViewModel

ViewModels should:
1. Be marked with `@Observable`
2. Use simple `init()` with no parameters
3. Expose dependencies as non-private properties for injection
4. Be thread-safe for async operations

Example:
```swift
import Observation
import SwiftData

@Observable
final class MyViewModel {
    // MARK: - Dependencies
    var modelContext: ModelContext!
    var someOtherDependency: SomeDependency!

    // MARK: - State
    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Initialization
    init() {}

    // MARK: - Methods
    func performAction() async throws {
        isLoading = true
        defer { isLoading = false }
        // Use modelContext and dependencies here
    }
}
```

#### Using ViewModels in the App

**1. Create and inject in App entry point** (`SmartContractAppApp.swift`):
```swift
@main
struct SmartContractAppApp: App {
    @State private var myViewModel = MyViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(myViewModel)
        }
        .modelContainer(sharedModelContainer)
    }
}
```

**2. Inject dependencies in wrapper views**:
```swift
private struct ContentViewWrapper: View {
    @Environment(\.modelContext) var modelContext
    @Environment(MyViewModel.self) var myViewModel

    var body: some View {
        ContentView()
            .onAppear {
                myViewModel.modelContext = modelContext
            }
    }
}
```

**3. Access in child views**:
```swift
struct MyView: View {
    @Environment(MyViewModel.self) var viewModel

    var body: some View {
        Button("Perform Action") {
            Task {
                try? await viewModel.performAction()
            }
        }
    }
}
```

**4. Setup in Previews**:
```swift
#Preview {
    let container = try! ModelContainer(for: MyModel.self)
    let viewModel = MyViewModel()
    viewModel.modelContext = container.mainContext

    return MyView()
        .modelContainer(container)
        .environment(viewModel)
}
```

**Important Notes**:
- Dependencies like `modelContext` must NOT be `private` if they need to be injected from outside the ViewModel
- Always use `return` before the final View in previews when you have setup statements
- ViewModels are shared across the app, so be mindful of state management
- Use `@State` in the App struct to create the ViewModel instance
- Inject the ViewModel into the environment using `.environment(viewModel)`

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

### UI Tests

UI tests use XCTest's XCUITest framework with type-safe accessibility identifiers.

#### Running UI Tests
```bash
# Run all UI tests
xcodebuild test -scheme SmartContractApp -destination 'platform=macOS' -only-testing:SmartContractAppUITests

# Run specific UI test
xcodebuild test -scheme SmartContractApp -destination 'platform=macOS' -only-testing:SmartContractAppUITests/SmartContractAppUITests/testSetupEndpoint
```

#### Type-Safe Accessibility Identifiers

The app uses a centralized accessibility identifier system located in [Types/AccessibilityIdentifier.swift](SmartContractApp/Types/AccessibilityIdentifier.swift).

**Key Features:**
- **Type-safe**: Compile-time checking prevents typos
- **Clean dot syntax**: `.accessibilityIdentifier(.endpoint.cancelButton)`
- **Autocomplete-friendly**: IDE suggests available identifiers
- **Organized by feature**: Separate namespaces for Sidebar, Endpoint, ABI, Wallet, Contract
- **Shared**: Same identifiers used in app code and test code

**Adding Identifiers to Views:**
```swift
import SwiftUI

struct MyFormView: View {
    var body: some View {
        Form {
            TextField("Name", text: $name)
                .accessibilityIdentifier(.endpoint.nameTextField)

            Button("Create") { }
                .accessibilityIdentifier(.endpoint.createButton)

            Toggle("Auto-detect", isOn: $autoDetect)
                .accessibilityIdentifier(.endpoint.autoDetectToggle)
        }
    }
}
```

**Using Identifiers in UI Tests:**
```swift
func testCreateEndpoint() {
    let app = XCUIApplication()
    app.launch()

    // Navigate using sidebar
    app.buttons["sidebar-endpoints"].firstMatch.click()

    // Click add button
    app.buttons["endpoint-add-button"].click()

    // Fill form fields
    app.textFields["endpoint-name-textfield"].typeText("Test")
    app.textFields["endpoint-url-textfield"].typeText("http://localhost:8545")
    app.switches["endpoint-auto-detect-toggle"].click()

    // Submit
    app.buttons["endpoint-create-button"].click()
}
```

**Extending the Identifier System:**

To add identifiers for a new feature:

1. Open [Types/AccessibilityIdentifier.swift](SmartContractApp/Types/AccessibilityIdentifier.swift)
2. Add a new namespace struct within `A11yID`:

```swift
// MARK: - MyFeature Namespace
struct MyFeature {
    static let addButton = A11yID(rawValue: "myfeature-add-button")
    static let nameTextField = A11yID(rawValue: "myfeature-name-textfield")
    static let submitButton = A11yID(rawValue: "myfeature-submit-button")
}
```

3. Add a namespace accessor:

```swift
// MARK: - Namespace Accessors
/// Access MyFeature identifiers with dot syntax: .myFeature.addButton
static let myFeature = MyFeature.self
```

4. Use in views: `.accessibilityIdentifier(.myFeature.addButton)`

**Identifier Naming Convention:**
- Format: `{feature}-{element-type}-{purpose}`
- Examples:
  - `endpoint-add-button`
  - `wallet-name-textfield`
  - `contract-auto-detect-toggle`
  - `sidebar-endpoints`

**Known Limitations:**

1. **Context Menus**: macOS UI tests have unreliable support for context menu accessibility identifiers. Use text-based selectors or skip context menu testing:
   ```swift
   // Instead of .accessibilityIdentifier on menu items, use text:
   app.menuItems["Edit"].click()
   app.menuItems["Delete"].click()
   ```

2. **Row Identifiers**: Don't add unique IDs to each list row. Use position-based selection instead:
   ```swift
   // Good: Position-based selection
   app.outlines.cells.firstMatch.click()
   app.outlines.cells.element(boundBy: 1).click()

   // Avoid: UUID-based identifiers for rows
   // .accessibilityIdentifier(.endpoint.row(endpoint.id.uuidString))
   ```

**Best Practices:**
- Add accessibility identifiers to all interactive elements (buttons, text fields, toggles, etc.)
- Use descriptive names that indicate the element's purpose
- Keep identifiers consistent across similar views
- Document complex test flows with `// MARK:` comments
- Group related test actions together

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

## Code Organization Guidelines

### SwiftUI View File Structure

To maintain readability and maintainability, follow these guidelines when creating SwiftUI views:

#### File Size Limits
- **Maximum file size**: ~200 lines per file
- **Recommended**: Split files larger than 150-200 lines into multiple files using extensions
- Large views should be decomposed into smaller, focused components

#### Extension-Based Organization

When a view file grows large, split it using Swift extensions with clear responsibilities:

**Main View File** (`ViewName.swift`):
- View struct definition
- `@State`, `@Binding`, `@Environment` properties
- Main `body` property
- Initializers
- Preview providers

**Sections Extension** (`ViewName+Sections.swift`):
- View section computed properties
- Sub-view builders marked with `@ViewBuilder`
- Reusable UI components specific to this view
- Example: `editModeSection`, `createModeSection`, `detailSection`

**Validation Extension** (`ViewName+Validation.swift`):
- Form validation logic
- Input sanitization
- Computed validation state properties
- Example: `isFormValid`, `validateInput()`, `deriveAddress()`

**Data Management Extension** (`ViewName+DataManagement.swift`):
- SwiftData/CoreData operations
- Network calls
- Business logic for creating/updating/deleting data
- Example: `loadData()`, `saveItem()`, `updateItem()`, `deleteItem()`

**Example Structure**:
```
Views/
  Wallet/
    WalletFormView.swift              // Main view (100 lines)
    WalletFormView+Sections.swift     // UI sections (150 lines)
    WalletFormView+Validation.swift   // Validation logic (80 lines)
    WalletFormView+DataManagement.swift // Data operations (120 lines)
```

#### MARK Comments

Use `// MARK: -` comments to organize code sections:
```swift
// MARK: - Properties
// MARK: - Initialization
// MARK: - Body
// MARK: - View Sections
// MARK: - Validation
// MARK: - Data Management
// MARK: - Helper Methods
// MARK: - Previews
```

#### Access Control
- Use `private` for view-specific computed properties and methods
- Use `internal` (default) only when the property/method needs to be accessed from extensions
- Properties referenced in extensions should not be `private`

#### Documentation
- Add doc comments (`///`) for complex validation logic
- Document parameters and return values for reusable methods
- Add inline comments for non-obvious business logic

### View Decomposition Strategy

When splitting views, consider these responsibilities:

1. **Presentation**: UI layout and styling (main view + sections)
2. **Validation**: Input validation and derived state
3. **Business Logic**: Data operations and transformations
4. **Navigation**: Routing and presentation logic

### Best Practices

- **Single Responsibility**: Each extension should have one clear purpose
- **No Duplication**: Extract common patterns into reusable components
- **Testability**: Keep business logic separate from UI code
- **Readability**: Prefer clarity over cleverness
- **Consistency**: Follow the same patterns across similar views

## Platform Requirements

- **macOS**: 12.0+
- **iOS**: 15.0+
- **Swift**: 6.2+
- **Xcode**: Latest stable version recommended
