# SwiftUI Test Infrastructure

This directory contains reusable testing utilities for SwiftUI views in SmartContractApp.

## SwiftUITestWrapper

A powerful wrapper that eliminates boilerplate when testing SwiftUI views that depend on:
- SwiftData ModelContainer
- WalletSignerViewModel environment object
- WindowStateManager environment object

### Basic Usage

```swift
// Use default configuration (Anvil endpoint + test wallet)
let view = try SwiftUITestWrapper.withDefaults {
    YourView()
}

// Test the view
let button = try view.inspect().find(button: "Submit")
```

### Custom Configuration

```swift
// Create custom endpoints and wallets
let endpoint = Endpoint(
    name: "Sepolia",
    url: "https://sepolia.infura.io/v3/YOUR-PROJECT-ID",
    chainId: "11155111"
)

let wallet = EVMWallet(
    alias: "Test Wallet",
    address: "0x1234...",
    keychainPath: "test"
)

let config = TestEnvironmentConfiguration(
    endpoints: [endpoint],
    wallets: [wallet],
    currentWallet: wallet
)

let view = try SwiftUITestWrapper(configuration: config) {
    YourView()
}
```

### Available Configurations

1. **`.default`** - Includes Anvil local endpoint and a test wallet
   ```swift
   SwiftUITestWrapper.withDefaults { YourView() }
   ```

2. **`.empty`** - No pre-populated data
   ```swift
   SwiftUITestWrapper.withEmpty { YourView() }
   ```

3. **Custom** - Define your own test data
   ```swift
   let config = TestEnvironmentConfiguration(
       endpoints: [...],
       wallets: [...],
       contracts: [...],
       abis: [...],
       currentWallet: wallet
   )
   SwiftUITestWrapper(configuration: config) { YourView() }
   ```

### Using in Previews

The same infrastructure can be used in SwiftUI previews for consistency:

```swift
#Preview {
    try! SwiftUITestWrapper.withDefaults {
        YourView()
    }
}
```

### Benefits

1. **Eliminates Duplication**: No need to repeat ModelContainer setup in every test
2. **Type Safety**: Configuration is strongly typed with sensible defaults
3. **Consistency**: Same setup between tests and previews
4. **Flexibility**: Easy to customize for specific test scenarios
5. **Maintainability**: Changes to environment setup only need to happen in one place

### TestEnvironmentConfiguration Properties

```swift
struct TestEnvironmentConfiguration {
    var endpoints: [Endpoint]       // RPC endpoints
    var wallets: [EVMWallet]        // Wallet data
    var contracts: [EVMContract]    // Contract instances
    var abis: [EvmAbi]              // ABI definitions
    var currentWallet: EVMWallet?   // Active wallet for WalletSignerViewModel
}
```

## Example Test

```swift
@Test @MainActor func testDeploymentSheet() async throws {
    let view = try SwiftUITestWrapper.withDefaults {
        SolidityDeploymentSheet(
            sourceCode: .constant("contract Test {}"),
            contractName: .constant("Test")
        )
    }

    let navigationStack = try view.inspect().navigationStack()
    #expect(navigationStack != nil)
}
```

## Migration Guide

**Before:**
```swift
@Test @MainActor func testView() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Endpoint.self, EVMContract.self, EvmAbi.self, EVMWallet.self,
        configurations: config
    )

    let endpoint = Endpoint(name: "Test", url: "http://...", chainId: "1")
    container.mainContext.insert(endpoint)

    let wallet = EVMWallet(alias: "Test", address: "0x...", keychainPath: "test")
    container.mainContext.insert(wallet)

    let walletSigner = WalletSignerViewModel(
        modelContext: container.mainContext,
        currentWallet: wallet
    )

    let windowStateManager = WindowStateManager()

    let view = YourView()
        .modelContainer(container)
        .environment(walletSigner)
        .environment(windowStateManager)

    // test...
}
```

**After:**
```swift
@Test @MainActor func testView() async throws {
    let view = try SwiftUITestWrapper.withDefaults {
        YourView()
    }

    // test...
}
```

From ~35 lines to ~3 lines per test!
