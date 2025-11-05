import BigInt
import Solidity

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
    The transport to use for the contract
    */
    var transport: Transport { get }

    /**
    Calls a function on the contract
    - Parameter name: The name of the function to call
    - Parameter args: The arguments to pass to the function
    - Parameter value: The value to send with the function
    - Parameter gasLimit: The gas limit to use for the function call
    - Parameter gasPrice: The gas price to use for the function call
    - Returns: The result of the function call
    */
    func callFunction<T>(
        name: String, args: [AnyCodable], value: BigInt, gasLimit: BigInt?, gasPrice: BigInt?
    ) async throws -> T
    where T: Codable
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

    var signer: Signer { get }
    var transport: Transport { get }

    /**
    Deploys the contract
    - Parameter constructorArgs: The arguments to pass to the constructor
    - Parameter importCallback: A callback to resolve import statements
    - Parameter value: The value to send with the deployment
    - Parameter gasLimit: The gas limit to use for the deployment
    - Parameter gasPrice: The gas price to use for the deployment
    - Returns: The deployed contract
    */
    func deploy(
        constructorArgs: [AnyCodable], importCallback: ImportCallback?, value: BigInt,
        gasLimit: BigInt?, gasPrice: BigInt?
    )
        async throws -> Contract
}
