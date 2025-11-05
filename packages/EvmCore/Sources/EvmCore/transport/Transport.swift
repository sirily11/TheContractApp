import Foundation

public struct RpcRequest: Codable {
    public let method: String
    public let params: [AnyCodable]

    public init(method: String, params: [AnyCodable]) {
        self.method = method
        self.params = params
    }
}

public struct RpcResponse: Codable {
    public let result: AnyCodable

    public init(result: AnyCodable) {
        self.result = result
    }
}

public protocol Transport {
    // Sends a request to the transport
    // - Parameter request: The request to send
    // - Returns: The response from the transport
    func send(request: RpcRequest) async throws -> RpcResponse
}
