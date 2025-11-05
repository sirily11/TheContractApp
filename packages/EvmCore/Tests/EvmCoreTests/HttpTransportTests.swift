import Testing
import Foundation
@testable import EvmCore

@Suite("HttpTransport Tests", .serialized)
struct HttpTransportTests {

    // MARK: - Mock URL Protocol

    class MockURLProtocol: URLProtocol {
        nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

        override class func canInit(with request: URLRequest) -> Bool {
            return true
        }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            return request
        }

        override func startLoading() {
            guard let handler = MockURLProtocol.requestHandler else {
                fatalError("Handler not set")
            }

            do {
                let (response, data) = try handler(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }

        override func stopLoading() {}
    }

    // MARK: - Helper Functions

    private func createMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    private func extractBody(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }

        if let bodyStream = request.httpBodyStream {
            bodyStream.open()
            defer { bodyStream.close() }

            let bufferSize = 4096
            var data = Data()
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { buffer.deallocate() }

            while bodyStream.hasBytesAvailable {
                let bytesRead = bodyStream.read(buffer, maxLength: bufferSize)
                if bytesRead > 0 {
                    data.append(buffer, count: bytesRead)
                } else if bytesRead < 0 {
                    return nil
                }
            }

            return data
        }

        return nil
    }

    private func createSuccessResponse(result: Any) -> (HTTPURLResponse, Data) {
        let responseDict: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "result": result
        ]
        let data = try! JSONSerialization.data(withJSONObject: responseDict)
        let response = HTTPURLResponse(
            url: URL(string: "http://localhost:8545")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response, data)
    }

    private func createErrorResponse(code: Int, message: String) -> (HTTPURLResponse, Data) {
        let responseDict: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "error": [
                "code": code,
                "message": message
            ]
        ]
        let data = try! JSONSerialization.data(withJSONObject: responseDict)
        let response = HTTPURLResponse(
            url: URL(string: "http://localhost:8545")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response, data)
    }

    private func createHttpErrorResponse(statusCode: Int) -> (HTTPURLResponse, Data) {
        let data = "HTTP Error".data(using: .utf8)!
        let response = HTTPURLResponse(
            url: URL(string: "http://localhost:8545")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (response, data)
    }

    // MARK: - Tests

    @Test("HttpTransport sends successful RPC request")
    func testSuccessfulRequest() async throws {
        let session = createMockSession()
        MockURLProtocol.requestHandler = { request in
            // Verify request format
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

            // Parse request body
            guard let httpBody = self.extractBody(from: request) else {
                Issue.record("Request body should not be nil")
                return self.createSuccessResponse(result: ["error": "no body"])
            }

            let body = try JSONSerialization.jsonObject(with: httpBody) as! [String: Any]
            let method = body["method"] as! String

            return self.createSuccessResponse(result: [
                "method": method,
                "received": true
            ])
        }

        let transport = HttpTransport(url: URL(string: "http://localhost:8545")!, session: session)

        let request = RpcRequest(
            method: "eth_blockNumber",
            params: []
        )

        let response = try await transport.send(request: request)

        guard let result = response.result.value as? [String: Any],
              let method = result["method"] as? String,
              let received = result["received"] as? Bool else {
            Issue.record("Response should contain method and received fields")
            return
        }

        #expect(method == "eth_blockNumber")
        #expect(received == true)
    }

    @Test("HttpTransport handles string results")
    func testStringResult() async throws {
        let session = createMockSession()
        MockURLProtocol.requestHandler = { _ in
            return self.createSuccessResponse(result: "0x1234")
        }

        let transport = HttpTransport(url: URL(string: "http://localhost:8545")!, session: session)

        let request = RpcRequest(method: "eth_blockNumber", params: [])
        let response = try await transport.send(request: request)

        guard let result = response.result.value as? String else {
            Issue.record("Result should be a string")
            return
        }

        #expect(result == "0x1234")
    }

    @Test("HttpTransport handles number results")
    func testNumberResult() async throws {
        let session = createMockSession()
        MockURLProtocol.requestHandler = { _ in
            return self.createSuccessResponse(result: 12345)
        }

        let transport = HttpTransport(url: URL(string: "http://localhost:8545")!, session: session)

        let request = RpcRequest(method: "eth_blockNumber", params: [])
        let response = try await transport.send(request: request)

        guard let result = response.result.value as? Int else {
            Issue.record("Result should be a number")
            return
        }

        #expect(result == 12345)
    }

    @Test("HttpTransport handles boolean results")
    func testBooleanResult() async throws {
        let session = createMockSession()
        MockURLProtocol.requestHandler = { _ in
            return self.createSuccessResponse(result: true)
        }

        let transport = HttpTransport(url: URL(string: "http://localhost:8545")!, session: session)

        let request = RpcRequest(method: "net_listening", params: [])
        let response = try await transport.send(request: request)

        guard let result = response.result.value as? Bool else {
            Issue.record("Result should be a boolean")
            return
        }

        #expect(result == true)
    }

    @Test("HttpTransport handles object results")
    func testObjectResult() async throws {
        let session = createMockSession()
        MockURLProtocol.requestHandler = { _ in
            let expectedObject: [String: Any] = [
                "blockNumber": "0x1234",
                "transactionHash": "0xabcd"
            ]
            return self.createSuccessResponse(result: expectedObject)
        }

        let transport = HttpTransport(url: URL(string: "http://localhost:8545")!, session: session)

        let request = RpcRequest(method: "eth_getTransaction", params: [])
        let response = try await transport.send(request: request)

        guard let result = response.result.value as? [String: Any] else {
            Issue.record("Result should be an object")
            return
        }

        #expect(result["blockNumber"] as? String == "0x1234")
        #expect(result["transactionHash"] as? String == "0xabcd")
    }

    @Test("HttpTransport handles array results")
    func testArrayResult() async throws {
        let session = createMockSession()
        MockURLProtocol.requestHandler = { _ in
            return self.createSuccessResponse(result: ["0x1", "0x2", "0x3"])
        }

        let transport = HttpTransport(url: URL(string: "http://localhost:8545")!, session: session)

        let request = RpcRequest(method: "eth_accounts", params: [])
        let response = try await transport.send(request: request)

        guard let result = response.result.value as? [Any] else {
            Issue.record("Result should be an array")
            return
        }

        #expect(result.count == 3)
        #expect((result[0] as? String) == "0x1")
        #expect((result[1] as? String) == "0x2")
        #expect((result[2] as? String) == "0x3")
    }

    @Test("HttpTransport handles RPC errors")
    func testRpcError() async throws {
        let session = createMockSession()
        MockURLProtocol.requestHandler = { _ in
            return self.createErrorResponse(code: -32601, message: "Method not found")
        }

        let transport = HttpTransport(url: URL(string: "http://localhost:8545")!, session: session)

        let request = RpcRequest(method: "invalid_method", params: [])

        do {
            _ = try await transport.send(request: request)
            Issue.record("Should have thrown an error")
        } catch let error as HttpTransport.TransportError {
            if case .httpError(let statusCode, let message) = error {
                #expect(statusCode == -1)
                #expect(message.contains("Method not found"))
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    @Test("HttpTransport handles HTTP errors")
    func testHttpError() async throws {
        let session = createMockSession()
        MockURLProtocol.requestHandler = { _ in
            return self.createHttpErrorResponse(statusCode: 500)
        }

        let transport = HttpTransport(url: URL(string: "http://localhost:8545")!, session: session)

        let request = RpcRequest(method: "eth_blockNumber", params: [])

        do {
            _ = try await transport.send(request: request)
            Issue.record("Should have thrown an error")
        } catch let error as HttpTransport.TransportError {
            if case .httpError(let statusCode, _) = error {
                #expect(statusCode == 500)
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    @Test("HttpTransport handles parameters")
    func testWithParameters() async throws {
        let session = createMockSession()
        MockURLProtocol.requestHandler = { request in
            // Parse request body
            guard let httpBody = self.extractBody(from: request) else {
                Issue.record("Request body should not be nil")
                return self.createSuccessResponse(result: ["error": "no body"])
            }

            let body = try JSONSerialization.jsonObject(with: httpBody) as! [String: Any]
            let params = body["params"] as! [Any]

            #expect(params.count == 2)
            #expect((params[0] as? String) == "0x1234567890123456789012345678901234567890")
            #expect((params[1] as? String) == "latest")

            return self.createSuccessResponse(result: ["balance": "0x1000"])
        }

        let transport = HttpTransport(url: URL(string: "http://localhost:8545")!, session: session)

        let request = RpcRequest(
            method: "eth_getBalance",
            params: [
                AnyCodable("0x1234567890123456789012345678901234567890"),
                AnyCodable("latest")
            ]
        )

        let response = try await transport.send(request: request)

        guard let result = response.result.value as? [String: Any],
              let balance = result["balance"] as? String else {
            Issue.record("Response should contain balance")
            return
        }

        #expect(balance == "0x1000")
    }

    @Test("HttpTransport handles null results")
    func testNullResult() async throws {
        let session = createMockSession()
        MockURLProtocol.requestHandler = { _ in
            return self.createSuccessResponse(result: NSNull())
        }

        let transport = HttpTransport(url: URL(string: "http://localhost:8545")!, session: session)

        let request = RpcRequest(method: "eth_getTransactionReceipt", params: [])
        let response = try await transport.send(request: request)

        #expect(response.result.value is NSNull)
    }

    @Test("HttpTransport convenience initializer with valid URL")
    func testValidUrl() async throws {
        _ = try HttpTransport(urlString: "http://localhost:8545")
        // If we reach here without throwing, the test passes
    }

    @Test("HttpTransport convenience initializer with invalid URL")
    func testInvalidUrl() async throws {
        // URL(string:) returns nil for strings with unescaped spaces
        // However, macOS may handle some malformed URLs, so let's use a clearly invalid one
        let result = try? HttpTransport(urlString: "ht!tp://invalid url with spaces")
        #expect(result == nil)
    }

    @Test("HttpTransport sends correct JSON-RPC format")
    func testJsonRpcFormat() async throws {
        let session = createMockSession()
        var capturedRequest: URLRequest?

        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            return self.createSuccessResponse(result: "0x1")
        }

        let transport = HttpTransport(url: URL(string: "http://localhost:8545")!, session: session)

        let request = RpcRequest(
            method: "eth_chainId",
            params: []
        )

        _ = try await transport.send(request: request)

        guard let capturedRequest = capturedRequest else {
            Issue.record("Request should have been captured")
            return
        }

        guard let body = extractBody(from: capturedRequest) else {
            Issue.record("Request body should not be nil")
            return
        }

        let json = try JSONSerialization.jsonObject(with: body) as! [String: Any]

        #expect(json["jsonrpc"] as? String == "2.0")
        #expect(json["id"] as? Int == 1)
        #expect(json["method"] as? String == "eth_chainId")
        #expect((json["params"] as? [Any])?.count == 0)
    }
}
