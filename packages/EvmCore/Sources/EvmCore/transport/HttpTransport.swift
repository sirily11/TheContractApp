import Foundation

/// HTTP-based transport implementation for JSON-RPC communication
public class HttpTransport: Transport {
    private let url: URL
    private let session: URLSession

    public enum TransportError: Error {
        case invalidResponse
        case httpError(statusCode: Int, message: String)
        case decodingError(Error)
    }

    /// Creates a new HTTP transport
    /// - Parameters:
    ///   - url: The RPC endpoint URL
    ///   - session: URLSession to use for requests (defaults to .shared)
    public init(url: URL, session: URLSession = .shared) {
        self.url = url
        self.session = session
    }

    /// Creates a new HTTP transport from a URL string
    /// - Parameters:
    ///   - urlString: The RPC endpoint URL as a string
    ///   - session: URLSession to use for requests (defaults to .shared)
    /// - Throws: If the URL string is invalid
    public convenience init(urlString: String, session: URLSession = .shared) throws {
        guard let url = URL(string: urlString) else {
            throw TransportError.invalidResponse
        }
        self.init(url: url, session: session)
    }

    public func send(request: RpcRequest) async throws -> RpcResponse {
        // Create JSON-RPC 2.0 request using Codable
        struct JsonRpcRequest: Encodable {
            let jsonrpc: String
            let id: Int
            let method: String
            let params: [AnyCodable]
        }

        let rpcRequest = JsonRpcRequest(
            jsonrpc: "2.0",
            id: 1,
            method: request.method,
            params: request.params
        )

        // Serialize to JSON using JSONEncoder
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(rpcRequest)

        // Create HTTP request
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = jsonData

        // Send request
        let (data, response) = try await session.data(for: urlRequest)

        // Check HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TransportError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TransportError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        // Parse JSON-RPC response using Codable
        // Note: JSON-RPC 2.0 responses have either "result" or "error", not both
        struct JsonRpcResponse: Decodable {
            let jsonrpc: String
            let id: Int
            let result: AnyCodable?
            let error: JsonRpcError?

            struct JsonRpcError: Decodable {
                let code: Int
                let message: String
            }
        }

        do {
            let decoder = JSONDecoder()
            let rpcResponse = try decoder.decode(JsonRpcResponse.self, from: data)

            // Check for JSON-RPC error first
            if let error = rpcResponse.error {
                throw TransportError.httpError(statusCode: -1, message: error.message)
            }

            // Extract result (may be nil/NSNull for null results, which is valid)
            // If there's no error and no result at all, that's an invalid response
            guard let result = rpcResponse.result else {
                // Check if the response actually has a "result" key set to null
                // by attempting to decode the raw JSON
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                if json?["result"] != nil {
                    // Result key exists but is null, which decodes as nil - that's ok
                    return RpcResponse(result: AnyCodable(NSNull()))
                }
                throw TransportError.invalidResponse
            }

            return RpcResponse(result: result)
        } catch let error as TransportError {
            throw error
        } catch {
            throw TransportError.decodingError(error)
        }
    }
}
