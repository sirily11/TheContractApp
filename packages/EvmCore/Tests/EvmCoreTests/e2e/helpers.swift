import BigInt
import EvmCore
import Foundation

// MARK: - Test Configuration

/// Anvil local test node URL
let anvilUrl = "http://localhost:8545"

/// 1 ETH in wei (10^18)
let oneEther = BigInt(10).power(18)

/// 0.5 ETH in wei
let halfEther = BigInt(5) * BigInt(10).power(17)

// MARK: - JSON Parsing Types

/// Contract JSON structure for Uniswap contracts (bytecode as direct string)
struct ContractJSON: Decodable {
    let abi: [AbiItem]
    let bytecode: String
}

// MARK: - Error Types

/// Errors that can occur during Uniswap test operations
enum UniswapTestError: Error, CustomStringConvertible {
    case resourceNotFound(String)
    case unexpectedValue(String)

    var description: String {
        switch self {
        case .resourceNotFound(let message):
            return "Resource not found: \(message)"
        case .unexpectedValue(let message):
            return "Unexpected value: \(message)"
        }
    }
}

// MARK: - Contract Loading

/// Load contract JSON from the test bundle
/// - Parameters:
///   - filename: The name of the JSON file (without extension)
///   - type: The type to decode the JSON into
///   - subdirectory: The subdirectory within the bundle (default: "uniswap")
/// - Returns: The decoded contract JSON
func loadContractJSON<T: Decodable>(
    named filename: String,
    as type: T.Type,
    subdirectory: String = "uniswap"
) throws -> T {
    guard let url = Bundle.module.url(
        forResource: filename,
        withExtension: "json",
        subdirectory: subdirectory
    ) else {
        throw UniswapTestError.resourceNotFound("Could not find \(filename).json in bundle")
    }
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(T.self, from: data)
}

// MARK: - Contract Deployment

/// Deploy a contract using the high-level DeployableEvmContract API
/// - Parameters:
///   - bytecode: The contract bytecode
///   - abi: The contract ABI
///   - constructorArgs: Arguments for the constructor
///   - evmSigner: The EVM client with signer
///   - value: Optional value to send with deployment (default: 0)
///   - gasLimit: Gas limit for deployment (default: 5,000,000)
/// - Returns: The deployed contract instance
func deployContract(
    bytecode: String,
    abi: [AbiItem],
    constructorArgs: [AnyCodable] = [],
    evmSigner: EvmClientWithSigner,
    value: BigInt = BigInt(0),
    gasLimit: BigInt = BigInt(5_000_000)
) async throws -> any Contract {
    let deployable = DeployableEvmContract(
        bytecode: bytecode,
        abi: abi,
        evmSigner: evmSigner
    )

    let (contract, _) = try await deployable.deploy(
        constructorArgs: constructorArgs,
        importCallback: nil,
        value: TransactionValue(wei: Wei(bigInt: value)),
        gasLimit: GasLimit(bigInt: gasLimit),
        gasPrice: nil as Gwei?
    )

    return contract
}

/// Deploy a contract using low-level transaction API
/// - Parameters:
///   - bytecode: The contract bytecode
///   - transport: The HTTP transport
///   - signer: The private key signer
///   - value: Optional value to send with deployment (default: 0)
/// - Returns: Tuple of contract address and transaction hash
func deployContractLowLevel(
    bytecode: String,
    transport: HttpTransport,
    signer: PrivateKeySigner,
    value: TransactionValue = .zero
) async throws -> (contractAddress: Address, transactionHash: String) {
    let client = EvmClient(transport: transport)
    let signerClient = client.withSigner(signer: signer)

    // Ensure bytecode has 0x prefix
    let deployData = bytecode.hasPrefix("0x") ? bytecode : "0x" + bytecode

    // Send deployment transaction (to: nil indicates contract creation)
    let pendingTx = try await signerClient.signAndSendTransaction(
        params: .init(
            from: signer.address.value,
            to: nil,
            gas: nil,
            gasPrice: nil,
            maxFeePerGas: nil,
            maxPriorityFeePerGas: nil,
            value: value,
            data: deployData,
            nonce: nil
        )
    )

    // Wait for transaction receipt
    let receipt = try await pendingTx.wait()

    // Extract contract address from receipt
    guard let contractAddressHex = receipt.contractAddress else {
        throw DeploymentError.missingContractAddress("Contract address not found in receipt")
    }

    let contractAddress = try Address(fromHexString: contractAddressHex)

    return (contractAddress, receipt.transactionHash)
}

// MARK: - Contract Interaction

/// Call a read function on a contract
/// - Parameters:
///   - contract: The contract instance
///   - name: The function name
///   - args: The function arguments (default: empty)
/// - Returns: The function result value
func callReadFunction(
    contract: any Contract,
    name: String,
    args: [AnyCodable] = []
) async throws -> Any {
    let result = try await contract.callFunction(
        name: name,
        args: args,
        value: TransactionValue(wei: Wei(bigInt: BigInt(0))),
        gasLimit: nil as GasLimit?,
        gasPrice: nil as Gwei?
    )
    return result.result.value
}

/// Call a write (state-changing) function on a contract
/// - Parameters:
///   - contract: The contract instance
///   - name: The function name
///   - args: The function arguments (default: empty)
///   - value: ETH value to send (default: 0)
///   - gasLimit: Gas limit for the transaction (default: 500,000)
/// - Returns: The transaction hash
func callWriteFunction(
    contract: any Contract,
    name: String,
    args: [AnyCodable] = [],
    value: BigInt = BigInt(0),
    gasLimit: BigInt = BigInt(500_000)
) async throws -> String {
    let result = try await contract.callFunction(
        name: name,
        args: args,
        value: TransactionValue(wei: Wei(bigInt: value)),
        gasLimit: GasLimit(bigInt: gasLimit),
        gasPrice: nil as Gwei?
    )
    guard let txHash = result.transactionHash else {
        throw UniswapTestError.unexpectedValue(
            "Write function '\(name)' did not return a transaction hash"
        )
    }
    return txHash
}

// MARK: - Test Setup Helpers

/// Create an EVM client with signer for testing
/// - Parameters:
///   - privateKey: The private key to use for signing
///   - url: The RPC URL (default: anvilUrl)
/// - Returns: Tuple of (EvmClientWithSigner, PrivateKeySigner)
func createTestSigner(
    privateKey: String,
    url: String = anvilUrl
) throws -> (evmSigner: EvmClientWithSigner, signer: PrivateKeySigner) {
    let transport = try HttpTransport(urlString: url)
    let signer = try PrivateKeySigner(hexPrivateKey: privateKey)
    let client = EvmClient(transport: transport)
    let evmSigner = client.withSigner(signer: signer)
    return (evmSigner, signer)
}

// MARK: - Uniswap Contract Deployment

/// Deployed Uniswap contracts for testing
struct DeployedUniswapContracts {
    let weth9: any Contract
    let factory: any Contract
    let router: any Contract
}

/// Deploy all Uniswap contracts (WETH9, Factory, Router)
/// - Parameters:
///   - evmSigner: The EVM client with signer
///   - feeToSetter: The address to set as feeToSetter on the factory
/// - Returns: The deployed contracts
func deployUniswapContracts(
    evmSigner: EvmClientWithSigner,
    feeToSetter: String
) async throws -> DeployedUniswapContracts {
    // Deploy WETH9
    print("\n=== Deploying WETH9 ===")
    let weth9Json = try loadContractJSON(named: "WETH9", as: ContractJSON.self)
    let weth9Contract = try await deployContract(
        bytecode: weth9Json.bytecode,
        abi: weth9Json.abi,
        constructorArgs: [],
        evmSigner: evmSigner
    )
    print("WETH9 deployed at: \(weth9Contract.address.value)")

    // Deploy UniswapV2Factory
    print("\n=== Deploying UniswapV2Factory ===")
    let factoryJson = try loadContractJSON(named: "UniswapV2Factory", as: ContractJSON.self)
    let factoryContract = try await deployContract(
        bytecode: factoryJson.bytecode,
        abi: factoryJson.abi,
        constructorArgs: [AnyCodable(feeToSetter)],
        evmSigner: evmSigner
    )
    print("UniswapV2Factory deployed at: \(factoryContract.address.value)")

    // Deploy UniswapV2Router02
    print("\n=== Deploying UniswapV2Router02 ===")
    let routerJson = try loadContractJSON(named: "UniswapV2Router02", as: ContractJSON.self)
    let routerContract = try await deployContract(
        bytecode: routerJson.bytecode,
        abi: routerJson.abi,
        constructorArgs: [
            AnyCodable(factoryContract.address.value),
            AnyCodable(weth9Contract.address.value),
        ],
        evmSigner: evmSigner
    )
    print("UniswapV2Router02 deployed at: \(routerContract.address.value)")

    return DeployedUniswapContracts(
        weth9: weth9Contract,
        factory: factoryContract,
        router: routerContract
    )
}
