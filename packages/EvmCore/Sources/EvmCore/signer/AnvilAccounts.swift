import Foundation

/// Anvil's default test accounts with known addresses and private keys
/// These accounts are automatically funded with 10000 ETH when Anvil starts
public struct AnvilAccounts {
    /// First Anvil test account (has 10000 ETH by default)
    public static let account0 = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

    /// Second Anvil test account
    public static let account1 = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"

    /// Third Anvil test account
    public static let account2 = "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"

    /// Private key for account0
    public static let privateKey0 =
        "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

    /// Private key for account1
    public static let privateKey1 =
        "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"

    /// Private key for account2
    public static let privateKey2 =
        "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"

    /// All default Anvil test accounts
    public static let allAccounts = [
        account0, account1, account2,
        "0x90F79bf6EB2c4f870365E785982E1f101E93b906",
        "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65",
        "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc",
        "0x976EA74026E726554dB657fA54763abd0C3a0aa9",
        "0x14dC79964da2C08b23698B3D3cc7Ca32193d9955",
        "0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f",
        "0xa0Ee7A142d267C1f36714E4a8F75612F20a79720",
    ]
}
