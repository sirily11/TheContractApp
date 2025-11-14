# SwiftUI Test Wrapper - Examples

This document provides practical examples of using the `SwiftUITestWrapper` and `PreviewHelper` for testing and previewing SwiftUI views.

## Table of Contents
1. [Basic Usage](#basic-usage)
2. [Custom Configurations](#custom-configurations)
3. [Testing Patterns](#testing-patterns)
4. [Preview Integration](#preview-integration)
5. [Before & After Comparison](#before--after-comparison)

---

## Basic Usage

### Simple Test with Default Configuration

```swift
@Test @MainActor func testMyView() async throws {
    let wrapper = try SwiftUITestWrapper.withDefaults {
        MyView()
    }

    // Access environment objects
    #expect(wrapper.modelContainer != nil)
    #expect(wrapper.walletSigner != nil)
    #expect(wrapper.windowStateManager != nil)
}
```

### Empty Configuration (No Pre-populated Data)

```swift
@Test @MainActor func testViewWithNoData() async throws {
    let wrapper = try SwiftUITestWrapper.withEmpty {
        MyView()
    }

    #expect(wrapper.configuration.endpoints.isEmpty)
    #expect(wrapper.configuration.wallets.isEmpty)
}
```

---

## Custom Configurations

### Single Custom Endpoint

```swift
@Test @MainActor func testWithSepoliaEndpoint() async throws {
    let sepoliaEndpoint = Endpoint(
        name: "Sepolia Testnet",
        url: "https://sepolia.infura.io/v3/YOUR-PROJECT-ID",
        chainId: "11155111"
    )

    let config = TestEnvironmentConfiguration(
        endpoints: [sepoliaEndpoint]
    )

    let wrapper = try SwiftUITestWrapper(configuration: config) {
        EndpointListView()
    }

    #expect(wrapper.configuration.endpoints.count == 1)
    #expect(wrapper.configuration.endpoints.first?.chainId == "11155111")
}
```

### Multiple Endpoints and Wallets

```swift
@Test @MainActor func testWithMultipleData() async throws {
    let mainnet = Endpoint(name: "Mainnet", url: "https://...", chainId: "1")
    let sepolia = Endpoint(name: "Sepolia", url: "https://...", chainId: "11155111")

    let wallet1 = EVMWallet(alias: "Main", address: "0x123...", keychainPath: "main")
    let wallet2 = EVMWallet(alias: "Test", address: "0x456...", keychainPath: "test")

    let config = TestEnvironmentConfiguration(
        endpoints: [mainnet, sepolia],
        wallets: [wallet1, wallet2],
        currentWallet: wallet1  // Set active wallet
    )

    let wrapper = try SwiftUITestWrapper(configuration: config) {
        WalletListView()
    }

    #expect(wrapper.configuration.endpoints.count == 2)
    #expect(wrapper.configuration.wallets.count == 2)
    #expect(wrapper.configuration.currentWallet?.alias == "Main")
}
```

### With Contracts and ABIs

```swift
@Test @MainActor func testWithContractData() async throws {
    let endpoint = Endpoint(name: "Local", url: "http://127.0.0.1:8545", chainId: "31337")

    let abi = EvmAbi(
        name: "ERC20",
        abi: "[{\"type\":\"function\",\"name\":\"balanceOf\"...}]"
    )

    let contract = EVMContract(
        address: "0x123...",
        name: "USDC",
        endpoint: endpoint,
        abi: abi
    )

    let config = TestEnvironmentConfiguration(
        endpoints: [endpoint],
        contracts: [contract],
        abis: [abi]
    )

    let wrapper = try SwiftUITestWrapper(configuration: config) {
        ContractDetailView(contract: contract)
    }

    #expect(wrapper.configuration.contracts.count == 1)
    #expect(wrapper.configuration.abis.count == 1)
}
```

---

## Testing Patterns

### Testing View Creation

```swift
@Test @MainActor func testViewCanBeCreated() async throws {
    // Simply creating the wrapper verifies the view can be initialized
    // with all required dependencies
    let _ = try SwiftUITestWrapper.withDefaults {
        SolidityDeploymentSheet(
            sourceCode: .constant("contract Test {}"),
            contractName: .constant("Test")
        )
    }
}
```

### Testing Configuration Propagation

```swift
@Test @MainActor func testConfigurationPropagates() async throws {
    let customWallet = EVMWallet(
        alias: "Custom",
        address: "0xabc...",
        keychainPath: "custom"
    )

    let config = TestEnvironmentConfiguration(
        wallets: [customWallet],
        currentWallet: customWallet
    )

    let wrapper = try SwiftUITestWrapper(configuration: config) {
        WalletFormView()
    }

    // Verify configuration was properly applied
    #expect(wrapper.walletSigner.currentWallet?.alias == "Custom")
}
```

### Testing Different Scenarios

```swift
struct MyViewTests {
    @Test @MainActor func testWithNoWallets() async throws {
        let wrapper = try SwiftUITestWrapper.withEmpty {
            WalletListView()
        }
        #expect(wrapper.configuration.wallets.isEmpty)
    }

    @Test @MainActor func testWithOneWallet() async throws {
        let wallet = EVMWallet(alias: "Test", address: "0x...", keychainPath: "test")
        let config = TestEnvironmentConfiguration(wallets: [wallet])

        let wrapper = try SwiftUITestWrapper(configuration: config) {
            WalletListView()
        }
        #expect(wrapper.configuration.wallets.count == 1)
    }

    @Test @MainActor func testWithMultipleWallets() async throws {
        let wallets = [
            EVMWallet(alias: "Wallet 1", address: "0x111...", keychainPath: "w1"),
            EVMWallet(alias: "Wallet 2", address: "0x222...", keychainPath: "w2"),
            EVMWallet(alias: "Wallet 3", address: "0x333...", keychainPath: "w3")
        ]
        let config = TestEnvironmentConfiguration(wallets: wallets)

        let wrapper = try SwiftUITestWrapper(configuration: config) {
            WalletListView()
        }
        #expect(wrapper.configuration.wallets.count == 3)
    }
}
```

---

## Preview Integration

### Basic Preview

```swift
#Preview {
    try! PreviewHelper.wrap {
        MyView()
    }
}
```

### Preview with State

```swift
#Preview {
    @Previewable @State var text = "Hello"

    try! PreviewHelper.wrap {
        MyView(text: $text)
    }
}
```

### Preview with Custom Configuration

```swift
#Preview("With Custom Data") {
    let customEndpoint = Endpoint(
        name: "Mainnet",
        url: "https://mainnet.infura.io/v3/YOUR-PROJECT-ID",
        chainId: "1"
    )

    let config = PreviewHelper.Configuration(
        endpoints: [customEndpoint]
    )

    return try! PreviewHelper.wrap(configuration: config) {
        EndpointDetailView(endpoint: customEndpoint)
    }
}
```

### Multiple Previews

```swift
#Preview("Empty State") {
    try! PreviewHelper.wrap(configuration: .empty) {
        WalletListView()
    }
}

#Preview("With Data") {
    try! PreviewHelper.wrap(configuration: .default) {
        WalletListView()
    }
}

#Preview("Multiple Wallets") {
    let wallets = [
        EVMWallet(alias: "Main", address: "0x111...", keychainPath: "main"),
        EVMWallet(alias: "Test", address: "0x222...", keychainPath: "test")
    ]

    let config = PreviewHelper.Configuration(wallets: wallets)

    return try! PreviewHelper.wrap(configuration: config) {
        WalletListView()
    }
}
```

---

## Before & After Comparison

### Before: Manual Setup (35 lines)

```swift
@Test @MainActor func testDeploymentSheet() async throws {
    // Set up in-memory model container
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Endpoint.self, EVMContract.self, EvmAbi.self, EVMWallet.self,
        configurations: config
    )

    // Add sample endpoint
    let endpoint = Endpoint(
        name: "Anvil Local",
        url: "http://127.0.0.1:8545",
        chainId: "31337"
    )
    container.mainContext.insert(endpoint)

    // Create mock wallet
    let mockWallet = EVMWallet(
        alias: "Test Wallet",
        address: "0x1234567890123456789012345678901234567890",
        keychainPath: "test_wallet"
    )
    container.mainContext.insert(mockWallet)

    // Create wallet signer view model
    let walletSigner = WalletSignerViewModel(
        modelContext: container.mainContext,
        currentWallet: mockWallet
    )

    // Create window state manager
    let windowStateManager = WindowStateManager()

    // Create the view with all required environment objects
    let view = SolidityDeploymentSheet(
        sourceCode: .constant(""),
        contractName: .constant("Test Contract")
    )
    .modelContainer(container)
    .environment(walletSigner)
    .environment(windowStateManager)

    // Test...
}
```

### After: Using Wrapper (6 lines)

```swift
@Test @MainActor func testDeploymentSheet() async throws {
    let wrapper = try SwiftUITestWrapper.withDefaults {
        SolidityDeploymentSheet(
            sourceCode: .constant(""),
            contractName: .constant("Test Contract")
        )
    }

    // Test...
}
```

### Improvement: 83% reduction in boilerplate code!

---

## Key Benefits

1. **Consistency**: Tests and previews use the same setup
2. **Maintainability**: Changes to environment setup happen in one place
3. **Readability**: Tests focus on what's being tested, not setup
4. **Reusability**: Share configurations across multiple tests
5. **Type Safety**: Strongly typed with sensible defaults
6. **Flexibility**: Easy to customize for specific scenarios

---

## Best Practices

1. **Use `.withDefaults` for most tests**: It includes typical test data (Anvil endpoint + test wallet)

2. **Use `.withEmpty` when testing empty states**: Ensures no pre-populated data interferes

3. **Create custom configurations for specific scenarios**: Only include the data you need

4. **Share configurations**: Extract common configurations to static properties

   ```swift
   extension TestEnvironmentConfiguration {
       static var mainnetConfig: Self {
           let endpoint = Endpoint(name: "Mainnet", url: "...", chainId: "1")
           return TestEnvironmentConfiguration(endpoints: [endpoint])
       }
   }
   ```

5. **Keep previews in sync**: Use `PreviewHelper` for previews to match test behavior

6. **Test the configuration**: Verify your custom configuration is set up correctly

   ```swift
   #expect(wrapper.configuration.endpoints.count == expectedCount)
   ```
