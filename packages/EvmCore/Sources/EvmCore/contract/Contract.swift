import BigInt
import Solidity

/// Result of a contract function call
public struct ContractCallResult: Codable {
    /// The decoded result value from the function
    public let result: AnyCodable
    /// The transaction hash if a transaction was sent (nil for read-only calls)
    public let transactionHash: String?

    public init(result: AnyCodable, transactionHash: String? = nil) {
        self.result = result
        self.transactionHash = transactionHash
    }
}

public protocol Contract {
    /**
    The address of the contract
    */
    var address: Address { get }

    /**
    The ABI of the contract
    */
    var abi: [AbiItem] { get }

    /**
    The functions of the contract
    */
    var functions: [AbiFunction] { get }

    /**
    The events of the contract
    */
    var events: [AbiEvent] { get }

    /**
    The signer to use for the contract
    */
    var signer: Signer { get }

    /**
    The EVM client with signer for contract interactions
    */
    var evmSigner: EvmClientWithSigner { get }

    /**
    Calls a function on the contract
    - Parameter name: The name of the function to call
    - Parameter args: The arguments to pass to the function
    - Parameter value: The value to send with the function
    - Parameter gasLimit: The gas limit to use for the function call
    - Parameter gasPrice: The gas price to use for the function call (in gwei)
    - Returns: The result of the function call with optional transaction hash
    */
    func callFunction(
        name: String, args: [AnyCodable], value: TransactionValue, gasLimit: GasLimit?, gasPrice: Gwei?
    ) async throws -> ContractCallResult
}

/// Re-export Solidity module's import types for convenience
/// Represents the result of an import callback.
public typealias ImportResult = Solidity.ImportResult

/// A function that resolves import statements by URL and returns the file contents or an error.
public typealias ImportCallback = Solidity.ImportCallback

public protocol DeployableContract {
    /**
    The source code of the contract. Should either provide the bytecode or the source code.
    */
    var sourceCode: String? { get }

    /**
    The bytecode of the contract. Should either provide the bytecode or the source code.
    */
    var bytecode: String? { get }

    /**
    The ABI of the contract
    */
    var abi: [AbiItem] { get }
    
    var evmSigner: EvmClientWithSigner { get }

    /**
    Deploys the contract
    - Parameter constructorArgs: The arguments to pass to the constructor
    - Parameter importCallback: A callback to resolve import statements
    - Parameter value: The value to send with the deployment
    - Parameter gasLimit: The gas limit to use for the deployment
    - Parameter gasPrice: The gas price to use for the deployment (in gwei)
    - Returns: The deployed contract and transaction hash
    */
    func deploy(
        constructorArgs: [AnyCodable], importCallback: ImportCallback?, value: TransactionValue,
        gasLimit: GasLimit?, gasPrice: Gwei?
    )
        async throws -> (Contract, String)
}
