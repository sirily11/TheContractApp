# Quick Start Guide

## 🚀 TL;DR

Replace 35+ lines of test boilerplate with 6 lines using `SwiftUITestWrapper`.

## Basic Usage

### For Tests

```swift
@Test @MainActor func testMyView() async throws {
    let wrapper = try SwiftUITestWrapper.withDefaults {
        MyView()
    }

    // Your test code here
}
```

### For Previews

```swift
#Preview {
    try! PreviewHelper.wrap {
        MyView()
    }
}
```

## Common Patterns

### 1. Default Configuration (Most Common)
```swift
try SwiftUITestWrapper.withDefaults {
    MyView()
}
```
Includes: Anvil endpoint + test wallet

### 2. Empty Configuration
```swift
try SwiftUITestWrapper.withEmpty {
    MyView()
}
```
Includes: Nothing (clean slate)

### 3. Custom Configuration
```swift
let endpoint = Endpoint(name: "Mainnet", url: "...", chainId: "1")
let config = TestEnvironmentConfiguration(endpoints: [endpoint])

try SwiftUITestWrapper(configuration: config) {
    MyView()
}
```

## What You Get

Every wrapper provides:
- ✅ In-memory SwiftData ModelContainer
- ✅ WalletSignerViewModel environment
- ✅ WindowStateManager environment
- ✅ Test data (endpoints, wallets, contracts, ABIs)

## Files

| File | Purpose |
|------|---------|
| [SwiftUITestWrapper.swift](SwiftUITestWrapper.swift) | Test wrapper (use in tests) |
| [../../SmartContractApp/Helpers/PreviewHelper.swift](../../SmartContractApp/Helpers/PreviewHelper.swift) | Preview helper (use in main app) |
| [README.md](README.md) | Full documentation |
| [EXAMPLES.md](EXAMPLES.md) | Practical examples |
| [COMPARISON.md](COMPARISON.md) | Before/after comparison |
| [QUICK_START.md](QUICK_START.md) | This file |

## Configuration Options

```swift
TestEnvironmentConfiguration(
    endpoints: [Endpoint],    // RPC endpoints
    wallets: [EVMWallet],     // EVM wallets
    contracts: [EVMContract], // Deployed contracts
    abis: [EvmAbi],          // Contract ABIs
    currentWallet: EVMWallet? // Active wallet
)
```

## Real Example

```swift
@Test @MainActor func testDeploymentSheet() async throws {
    let wrapper = try SwiftUITestWrapper.withDefaults {
        SolidityDeploymentSheet(
            sourceCode: .constant("contract Test {}"),
            contractName: .constant("Test")
        )
    }

    #expect(wrapper.modelContainer != nil)
    #expect(wrapper.walletSigner != nil)
    #expect(wrapper.configuration.endpoints.count == 1)
}
```

## Next Steps

1. ✅ Read [README.md](README.md) for full API
2. ✅ Check [EXAMPLES.md](EXAMPLES.md) for patterns
3. ✅ See [COMPARISON.md](COMPARISON.md) for benefits
4. ✅ Start using it in your tests!

## Questions?

Check the documentation files or look at [SolidityDeploymentTests.swift](../Contract/Solidity/SolidityDeploymentTests.swift) for working examples.
