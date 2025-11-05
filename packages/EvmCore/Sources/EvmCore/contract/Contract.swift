import BigInt

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
