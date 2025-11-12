import Testing
import Foundation
import BigInt
@testable import EvmCore

@Suite("TransactionHelper Tests", .serialized)
struct TransactionHelperTests {

    // MARK: - Mock URL Protocol

    struct UnsafeSendableWrapper<T>: @unchecked Sendable {
        let value: T
        init(_ value: T) {
            self.value = value
        }
    }

    actor MockRequestHandler {
        var handler: (@Sendable (URLRequest) async throws -> (HTTPURLResponse, Data))?

        func setHandler(_ newHandler: @escaping @Sendable (URLRequest) async throws -> (HTTPURLResponse, Data)) {
            self.handler = newHandler
        }

        func handleRequest(_ request: URLRequest) async throws -> (HTTPURLResponse, Data) {
            guard let handler = handler else {
                fatalError("Handler not set")
            }
            return try await handler(request)
        }

        func clear() {
            self.handler = nil
        }
    }

    class MockURLProtocol: URLProtocol {
        nonisolated(unsafe) static var handlerActor = MockRequestHandler()

        override class func canInit(with request: URLRequest) -> Bool {
            return true
        }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            return request
        }

        override func startLoading() {
            let request = self.request
            let client = self.client
            let proto = UnsafeSendableWrapper(self)
            Task {
                do {
                    let (response, data) = try await MockURLProtocol.handlerActor.handleRequest(request)
                    client?.urlProtocol(proto.value, didReceive: response, cacheStoragePolicy: .notAllowed)
                    client?.urlProtocol(proto.value, didLoad: data)
                    client?.urlProtocolDidFinishLoading(proto.value)
                } catch {
                    client?.urlProtocol(proto.value, didFailWithError: error)
                }
            }
        }

        override func stopLoading() {}
    }

    // MARK: - Helper Functions

    actor ParamsCapture {
        nonisolated(unsafe) var stringParams: [String: Any]?
        nonisolated(unsafe) var arrayParams: [Any]?

        func setStringParams(_ params: [String: Any]) {
            self.stringParams = params
        }

        func setArrayParams(_ params: [Any]) {
            self.arrayParams = params
        }

        nonisolated func getStringParams() -> [String: Any]? {
            return stringParams
        }

        nonisolated func getArrayParams() -> [Any]? {
            return arrayParams
        }
    }

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

    // MARK: - sendTransaction Tests

    @Test("sendTransaction with minimal parameters")
    func testSendTransactionMinimal() async throws {
        let session = createMockSession()
        let paramsCapture = ParamsCapture()

        await MockURLProtocol.handlerActor.setHandler { request in
            guard let body = self.extractBody(from: request) else {
                Issue.record("Request body should not be nil")
                return self.createSuccessResponse(result: "0x0")
            }

            let json = try JSONSerialization.jsonObject(with: body) as! [String: Any]
            let params = json["params"] as! [Any]
            if let dictParams = params[0] as? [String: Any] {
                await paramsCapture.setStringParams(dictParams)
            }

            return self.createSuccessResponse(result: "0xabcdef1234567890")
        }

        let transport = HttpTransport(url: URL(string: "http://localhost:8545")!, session: session)
        let helper = TransactionHelper(transport: transport)

        let from = try Address("0x1234567890123456789012345678901234567890")
        let to = try Address("0x0987654321098765432109876543210987654321")
        let data = "0x12345678"

        let txHash = try await helper.sendTransaction(
            from: from,
            to: to,
            data: data
        )

        let capturedParams = paramsCapture.getStringParams()
        #expect(txHash == "0xabcdef1234567890")
        #expect(capturedParams?["from"] as? String == from.value)
        #expect(capturedParams?["to"] as? String == to.value)
        #expect(capturedParams?["data"] as? String == data)
        #expect(capturedParams?["value"] == nil) // Default value is 0, not included
    }

    @Test("sendTransaction with all parameters")
    func testSendTransactionAllParams() async throws {
        let session = createMockSession()
        let paramsCapture = ParamsCapture()

        await MockURLProtocol.handlerActor.setHandler { request in
            guard let body = self.extractBody(from: request) else {
                Issue.record("Request body should not be nil")
                return self.createSuccessResponse(result: "0x0")
            }

            let json = try JSONSerialization.jsonObject(with: body) as! [String: Any]
            let params = json["params"] as! [Any]
            if let dictParams = params[0] as? [String: Any] {
                await paramsCapture.setStringParams(dictParams)
            }

            return self.createSuccessResponse(result: "0xabcdef1234567890")
        }

        let transport = HttpTransport(url: URL(string: "http://localhost:8545")!, session: session)
        let helper = TransactionHelper(transport: transport)

        let from = try Address("0x1234567890123456789012345678901234567890")
        let to = try Address("0x0987654321098765432109876543210987654321")
        let data = "0x12345678"
        let value = BigInt(1_000_000_000_000_000_000) // 1 ETH
        let gas = BigInt(21_000)
        let gasPrice = BigInt(20_000_000_000) // 20 Gwei

        let txHash = try await helper.sendTransaction(
            from: from,
            to: to,
            data: data,
            value: value,
            gas: gas,
            gasPrice: gasPrice
        )

        let capturedParams = paramsCapture.getStringParams()
        #expect(txHash == "0xabcdef1234567890")
        #expect(capturedParams?["from"] as? String == from.value)
        #expect(capturedParams?["to"] as? String == to.value)
        #expect(capturedParams?["data"] as? String == data)
        #expect(capturedParams?["value"] as? String == "0x" + String(value, radix: 16))
        #expect(capturedParams?["gas"] as? String == "0x" + String(gas, radix: 16))
        #expect(capturedParams?["gasPrice"] as? String == "0x" + String(gasPrice, radix: 16))
    }

    @Test("sendTransaction without to address (contract deployment)")
    func testSendTransactionDeployment() async throws {
        let session = createMockSession()
        let paramsCapture = ParamsCapture()

        await MockURLProtocol.handlerActor.setHandler { request in
            guard let body = self.extractBody(from: request) else {
                Issue.record("Request body should not be nil")
                return self.createSuccessResponse(result: "0x0")
            }

            let json = try JSONSerialization.jsonObject(with: body) as! [String: Any]
            let params = json["params"] as! [Any]
            if let dictParams = params[0] as? [String: Any] {
                await paramsCapture.setStringParams(dictParams)
            }

            return self.createSuccessResponse(result: "0xdeploymenthash")
        }

        let transport = HttpTransport(url: URL(string: "http://localhost:8545")!, session: session)
        let helper = TransactionHelper(transport: transport)

        let from = try Address("0x1234567890123456789012345678901234567890")
        let bytecode = "0x608060405234801561001057600080fd5b50"

        let txHash = try await helper.sendTransaction(
            from: from,
            to: nil,
            data: bytecode
        )

        let capturedParams = paramsCapture.getStringParams()
        #expect(txHash == "0xdeploymenthash")
        #expect(capturedParams?["from"] as? String == from.value)
        #expect(capturedParams?["to"] == nil)
        #expect(capturedParams?["data"] as? String == bytecode)
    }

    @Test("sendTransaction with value only")
    func testSendTransactionWithValue() async throws {
        let session = createMockSession()
        let paramsCapture = ParamsCapture()

        await MockURLProtocol.handlerActor.setHandler { request in
            guard let body = self.extractBody(from: request) else {
                Issue.record("Request body should not be nil")
                return self.createSuccessResponse(result: "0x0")
            }

            let json = try JSONSerialization.jsonObject(with: body) as! [String: Any]
            let params = json["params"] as! [Any]
            if let dictParams = params[0] as? [String: Any] {
                await paramsCapture.setStringParams(dictParams)
            }

            return self.createSuccessResponse(result: "0xtxhash")
        }

        let transport = HttpTransport(url: URL(string: "http://localhost:8545")!, session: session)
        let helper = TransactionHelper(transport: transport)

        let from = try Address("0x1234567890123456789012345678901234567890")
        let to = try Address("0x0987654321098765432109876543210987654321")
        let value = BigInt(500_000_000_000_000_000) // 0.5 ETH

        let txHash = try await helper.sendTransaction(
            from: from,
            to: to,
            data: "0x",
            value: value
        )

        let capturedParams = paramsCapture.getStringParams()
        #expect(txHash == "0xtxhash")
        #expect(capturedParams?["value"] as? String == "0x" + String(value, radix: 16))
    }

    @Test("sendTransaction throws on invalid response")
    func testSendTransactionInvalidResponse() async throws {
        let session = createMockSession()

        await MockURLProtocol.handlerActor.setHandler { _ in
            // Return a non-string result
            return self.createSuccessResponse(result: 12345)
        }

        let transport = HttpTransport(url: URL(string: "http://localhost:8545")!, session: session)
        let helper = TransactionHelper(transport: transport)

        let from = try Address("0x1234567890123456789012345678901234567890")
        let to = try Address("0x0987654321098765432109876543210987654321")

        do {
            _ = try await helper.sendTransaction(
                from: from,
                to: to,
                data: "0x"
            )
            Issue.record("Should have thrown an error")
        } catch let error as TransactionError {
            if case .invalidResponse(let message) = error {
                #expect(message.contains("Expected transaction hash string"))
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - waitForReceipt Tests

    @Test("waitForReceipt returns receipt immediately")
    func testWaitForReceiptImmediate() async throws {
        let session = createMockSession()

        await MockURLProtocol.handlerActor.setHandler { _ in
            let receiptDict: [String: Any] = [
                "transactionHash": "0xtxhash",
                "transactionIndex": "0x1",
                "blockHash": "0xblockhash",
                "blockNumber": "0x10",
                "from": "0x1234567890123456789012345678901234567890",
                "to": "0x0987654321098765432109876543210987654321",
                "cumulativeGasUsed": "0x5208",
                "gasUsed": "0x5208",
                "status": "0x1",
                "logs": []
            ]
            return self.createSuccessResponse(result: receiptDict)
        }

        let transport = HttpTransport(url: URL(string: "http://localhost:8545")!, session: session)
        let helper = TransactionHelper(transport: transport)

        let receipt = try await helper.waitForReceipt(txHash: "0xtxhash")

        #expect(receipt.transactionHash == "0xtxhash")
        #expect(receipt.blockNumber == "0x10")
        #expect(receipt.isSuccessful == true)
    }

    @Test("waitForReceipt polls until receipt available")
    func testWaitForReceiptPolling() async throws {
        let session = createMockSession()

        actor CallCounter {
            var count = 0
            func increment() -> Int {
                count += 1
                return count
            }
            func getCount() -> Int {
                return count
            }
        }
        let callCounter = CallCounter()

        await MockURLProtocol.handlerActor.setHandler { _ in
            let callCount = await callCounter.increment()

            // Return null for first 2 calls, then return receipt
            if callCount <= 2 {
                return self.createSuccessResponse(result: NSNull())
            } else {
                let receiptDict: [String: Any] = [
                    "transactionHash": "0xtxhash",
                    "transactionIndex": "0x1",
                    "blockHash": "0xblockhash",
                    "blockNumber": "0x10",
                    "from": "0x1234567890123456789012345678901234567890",
                    "to": "0x0987654321098765432109876543210987654321",
                    "cumulativeGasUsed": "0x5208",
                    "gasUsed": "0x5208",
                    "status": "0x1",
                    "logs": []
                ]
                return self.createSuccessResponse(result: receiptDict)
            }
        }

        let transport = HttpTransport(url: URL(string: "http://localhost:8545")!, session: session)
        let helper = TransactionHelper(transport: transport)

        let startTime = Date()
        let receipt = try await helper.waitForReceipt(
            txHash: "0xtxhash",
            pollingInterval: 0.1
        )
        let duration = Date().timeIntervalSince(startTime)

        #expect(receipt.transactionHash == "0xtxhash")
        let finalCount = await callCounter.getCount()
        #expect(finalCount == 3)
        // Should have waited ~0.2 seconds (2 polls * 0.1s interval)
        #expect(duration >= 0.2)
    }

    @Test("waitForReceipt times out")
    func testWaitForReceiptTimeout() async throws {
        let session = createMockSession()

        await MockURLProtocol.handlerActor.setHandler { _ in
            // Always return null (no receipt)
            return self.createSuccessResponse(result: NSNull())
        }

        let transport = HttpTransport(url: URL(string: "http://localhost:8545")!, session: session)
        let helper = TransactionHelper(transport: transport)

        do {
            _ = try await helper.waitForReceipt(
                txHash: "0xtxhash",
                pollingInterval: 0.1,
                timeout: 0.3
            )
            Issue.record("Should have thrown a timeout error")
        } catch let error as TransactionError {
            if case .timeout(let message) = error {
                #expect(message.contains("0.3 seconds"))
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    @Test("waitForReceipt throws on invalid receipt")
    func testWaitForReceiptInvalidReceipt() async throws {
        let session = createMockSession()

        await MockURLProtocol.handlerActor.setHandler { _ in
            // Return invalid receipt (not a dictionary)
            return self.createSuccessResponse(result: "invalid")
        }

        let transport = HttpTransport(url: URL(string: "http://localhost:8545")!, session: session)
        let helper = TransactionHelper(transport: transport)

        do {
            _ = try await helper.waitForReceipt(txHash: "0xtxhash")
            Issue.record("Should have thrown an error")
        } catch let error as TransactionError {
            if case .invalidResponse(let message) = error {
                #expect(message.contains("Expected receipt dictionary"))
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - getTransactionCount Tests

    @Test("getTransactionCount returns correct nonce")
    func testGetTransactionCount() async throws {
        let session = createMockSession()
        let paramsCapture = ParamsCapture()

        await MockURLProtocol.handlerActor.setHandler { request in
            guard let body = self.extractBody(from: request) else {
                Issue.record("Request body should not be nil")
                return self.createSuccessResponse(result: "0x0")
            }

            let json = try JSONSerialization.jsonObject(with: body) as! [String: Any]
            if let arrayParams = json["params"] as? [Any] {
                await paramsCapture.setArrayParams(arrayParams)
            }

            return self.createSuccessResponse(result: "0x1a") // 26 in hex
        }

        let transport = HttpTransport(url: URL(string: "http://localhost:8545")!, session: session)
        let helper = TransactionHelper(transport: transport)

        let address = try Address("0x1234567890123456789012345678901234567890")
        let count = try await helper.getTransactionCount(address: address)

        let capturedParams = paramsCapture.getArrayParams()
        #expect(count == BigInt(26))
        #expect(capturedParams?[0] as? String == address.value)
        #expect(capturedParams?[1] as? String == "latest")
    }

    @Test("getTransactionCount with custom block parameter")
    func testGetTransactionCountCustomBlock() async throws {
        let session = createMockSession()
        let paramsCapture = ParamsCapture()

        await MockURLProtocol.handlerActor.setHandler { request in
            guard let body = self.extractBody(from: request) else {
                Issue.record("Request body should not be nil")
                return self.createSuccessResponse(result: "0x0")
            }

            let json = try JSONSerialization.jsonObject(with: body) as! [String: Any]
            if let arrayParams = json["params"] as? [Any] {
                await paramsCapture.setArrayParams(arrayParams)
            }

            return self.createSuccessResponse(result: "0x5")
        }

        let transport = HttpTransport(url: URL(string: "http://localhost:8545")!, session: session)
        let helper = TransactionHelper(transport: transport)

        let address = try Address("0x1234567890123456789012345678901234567890")
        let count = try await helper.getTransactionCount(address: address, block: "0x100")

        let capturedParams = paramsCapture.getArrayParams()
        #expect(count == BigInt(5))
        #expect(capturedParams?[1] as? String == "0x100")
    }

    @Test("getTransactionCount throws on invalid response")
    func testGetTransactionCountInvalidResponse() async throws {
        let session = createMockSession()

        await MockURLProtocol.handlerActor.setHandler { _ in
            return self.createSuccessResponse(result: 12345) // Not a string
        }

        let transport = HttpTransport(url: URL(string: "http://localhost:8545")!, session: session)
        let helper = TransactionHelper(transport: transport)

        let address = try Address("0x1234567890123456789012345678901234567890")

        do {
            _ = try await helper.getTransactionCount(address: address)
            Issue.record("Should have thrown an error")
        } catch let error as TransactionError {
            if case .invalidResponse(let message) = error {
                #expect(message.contains("Expected transaction count hex string"))
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    @Test("getTransactionCount throws on invalid hex format")
    func testGetTransactionCountInvalidHex() async throws {
        let session = createMockSession()

        await MockURLProtocol.handlerActor.setHandler { _ in
            return self.createSuccessResponse(result: "0xZZZ") // Invalid hex
        }

        let transport = HttpTransport(url: URL(string: "http://localhost:8545")!, session: session)
        let helper = TransactionHelper(transport: transport)

        let address = try Address("0x1234567890123456789012345678901234567890")

        do {
            _ = try await helper.getTransactionCount(address: address)
            Issue.record("Should have thrown an error")
        } catch let error as TransactionError {
            if case .invalidResponse(let message) = error {
                #expect(message.contains("Invalid transaction count format"))
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - getGasPrice Tests

    @Test("getGasPrice returns correct price")
    func testGetGasPrice() async throws {
        let session = createMockSession()

        await MockURLProtocol.handlerActor.setHandler { _ in
            return self.createSuccessResponse(result: "0x4a817c800") // 20 Gwei
        }

        let transport = HttpTransport(url: URL(string: "http://localhost:8545")!, session: session)
        let helper = TransactionHelper(transport: transport)

        let price = try await helper.getGasPrice()

        #expect(price == BigInt(20_000_000_000))
    }

    @Test("getGasPrice throws on invalid response")
    func testGetGasPriceInvalidResponse() async throws {
        let session = createMockSession()

        await MockURLProtocol.handlerActor.setHandler { _ in
            return self.createSuccessResponse(result: 12345) // Not a string
        }

        let transport = HttpTransport(url: URL(string: "http://localhost:8545")!, session: session)
        let helper = TransactionHelper(transport: transport)

        do {
            _ = try await helper.getGasPrice()
            Issue.record("Should have thrown an error")
        } catch let error as TransactionError {
            if case .invalidResponse(let message) = error {
                #expect(message.contains("Expected gas price hex string"))
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    @Test("getGasPrice throws on invalid hex format")
    func testGetGasPriceInvalidHex() async throws {
        let session = createMockSession()

        await MockURLProtocol.handlerActor.setHandler { _ in
            return self.createSuccessResponse(result: "0xGGG") // Invalid hex
        }

        let transport = HttpTransport(url: URL(string: "http://localhost:8545")!, session: session)
        let helper = TransactionHelper(transport: transport)

        do {
            _ = try await helper.getGasPrice()
            Issue.record("Should have thrown an error")
        } catch let error as TransactionError {
            if case .invalidResponse(let message) = error {
                #expect(message.contains("Invalid gas price format"))
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - estimateGas Tests

    @Test("estimateGas with minimal parameters")
    func testEstimateGasMinimal() async throws {
        let session = createMockSession()
        let paramsCapture = ParamsCapture()

        await MockURLProtocol.handlerActor.setHandler { request in
            guard let body = self.extractBody(from: request) else {
                Issue.record("Request body should not be nil")
                return self.createSuccessResponse(result: "0x0")
            }

            let json = try JSONSerialization.jsonObject(with: body) as! [String: Any]
            let params = json["params"] as! [Any]
            if let dictParams = params[0] as? [String: Any] {
                await paramsCapture.setStringParams(dictParams)
            }

            return self.createSuccessResponse(result: "0x5208") // 21000 gas
        }

        let transport = HttpTransport(url: URL(string: "http://localhost:8545")!, session: session)
        let helper = TransactionHelper(transport: transport)

        let from = try Address("0x1234567890123456789012345678901234567890")
        let to = try Address("0x0987654321098765432109876543210987654321")
        let data = "0x"

        let gas = try await helper.estimateGas(
            from: from,
            to: to,
            data: data
        )

        let capturedParams = paramsCapture.getStringParams()
        #expect(gas == BigInt(21_000))
        #expect(capturedParams?["from"] as? String == from.value)
        #expect(capturedParams?["to"] as? String == to.value)
        #expect(capturedParams?["data"] as? String == data)
        #expect(capturedParams?["value"] == nil)
    }

    @Test("estimateGas with all parameters")
    func testEstimateGasAllParams() async throws {
        let session = createMockSession()
        let paramsCapture = ParamsCapture()

        await MockURLProtocol.handlerActor.setHandler { request in
            guard let body = self.extractBody(from: request) else {
                Issue.record("Request body should not be nil")
                return self.createSuccessResponse(result: "0x0")
            }

            let json = try JSONSerialization.jsonObject(with: body) as! [String: Any]
            let params = json["params"] as! [Any]
            if let dictParams = params[0] as? [String: Any] {
                await paramsCapture.setStringParams(dictParams)
            }

            return self.createSuccessResponse(result: "0x7530") // 30000 gas
        }

        let transport = HttpTransport(url: URL(string: "http://localhost:8545")!, session: session)
        let helper = TransactionHelper(transport: transport)

        let from = try Address("0x1234567890123456789012345678901234567890")
        let to = try Address("0x0987654321098765432109876543210987654321")
        let data = "0x12345678"
        let value = BigInt(1_000_000_000_000_000_000)

        let gas = try await helper.estimateGas(
            from: from,
            to: to,
            data: data,
            value: value
        )

        let capturedParams = paramsCapture.getStringParams()
        #expect(gas == BigInt(30_000))
        #expect(capturedParams?["from"] as? String == from.value)
        #expect(capturedParams?["to"] as? String == to.value)
        #expect(capturedParams?["data"] as? String == data)
        #expect(capturedParams?["value"] as? String == "0x" + String(value, radix: 16))
    }

    @Test("estimateGas for contract deployment")
    func testEstimateGasDeployment() async throws {
        let session = createMockSession()
        let paramsCapture = ParamsCapture()

        await MockURLProtocol.handlerActor.setHandler { request in
            guard let body = self.extractBody(from: request) else {
                Issue.record("Request body should not be nil")
                return self.createSuccessResponse(result: "0x0")
            }

            let json = try JSONSerialization.jsonObject(with: body) as! [String: Any]
            let params = json["params"] as! [Any]
            if let dictParams = params[0] as? [String: Any] {
                await paramsCapture.setStringParams(dictParams)
            }

            return self.createSuccessResponse(result: "0x30d40") // ~200k gas
        }

        let transport = HttpTransport(url: URL(string: "http://localhost:8545")!, session: session)
        let helper = TransactionHelper(transport: transport)

        let from = try Address("0x1234567890123456789012345678901234567890")
        let bytecode = "0x608060405234801561001057600080fd5b50"

        let gas = try await helper.estimateGas(
            from: from,
            to: nil,
            data: bytecode
        )

        let capturedParams = paramsCapture.getStringParams()
        #expect(gas == BigInt(200_000))
        #expect(capturedParams?["from"] as? String == from.value)
        #expect(capturedParams?["to"] == nil)
        #expect(capturedParams?["data"] as? String == bytecode)
    }

    @Test("estimateGas throws on invalid response")
    func testEstimateGasInvalidResponse() async throws {
        let session = createMockSession()

        await MockURLProtocol.handlerActor.setHandler { _ in
            return self.createSuccessResponse(result: 12345) // Not a string
        }

        let transport = HttpTransport(url: URL(string: "http://localhost:8545")!, session: session)
        let helper = TransactionHelper(transport: transport)

        let from = try Address("0x1234567890123456789012345678901234567890")
        let to = try Address("0x0987654321098765432109876543210987654321")

        do {
            _ = try await helper.estimateGas(from: from, to: to, data: "0x")
            Issue.record("Should have thrown an error")
        } catch let error as TransactionError {
            if case .invalidResponse(let message) = error {
                #expect(message.contains("Expected gas estimate hex string"))
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    @Test("estimateGas throws on invalid hex format")
    func testEstimateGasInvalidHex() async throws {
        let session = createMockSession()

        await MockURLProtocol.handlerActor.setHandler { _ in
            return self.createSuccessResponse(result: "0xHHH") // Invalid hex
        }

        let transport = HttpTransport(url: URL(string: "http://localhost:8545")!, session: session)
        let helper = TransactionHelper(transport: transport)

        let from = try Address("0x1234567890123456789012345678901234567890")
        let to = try Address("0x0987654321098765432109876543210987654321")

        do {
            _ = try await helper.estimateGas(from: from, to: to, data: "0x")
            Issue.record("Should have thrown an error")
        } catch let error as TransactionError {
            if case .invalidResponse(let message) = error {
                #expect(message.contains("Invalid gas estimate format"))
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - TransactionReceipt Tests

    @Test("TransactionReceipt initializes with all fields")
    func testTransactionReceiptInit() throws {
        let dict: [String: Any] = [
            "transactionHash": "0xtxhash",
            "transactionIndex": "0x1",
            "blockHash": "0xblockhash",
            "blockNumber": "0x10",
            "from": "0x1234567890123456789012345678901234567890",
            "to": "0x0987654321098765432109876543210987654321",
            "contractAddress": "0xcontractaddress",
            "cumulativeGasUsed": "0x5208",
            "gasUsed": "0x5208",
            "status": "0x1",
            "logs": [
                ["address": "0xlogaddress", "data": "0xlogdata"]
            ]
        ]

        let receipt = try TransactionReceipt(from: dict)

        #expect(receipt.transactionHash == "0xtxhash")
        #expect(receipt.transactionIndex == "0x1")
        #expect(receipt.blockHash == "0xblockhash")
        #expect(receipt.blockNumber == "0x10")
        #expect(receipt.from == "0x1234567890123456789012345678901234567890")
        #expect(receipt.to == "0x0987654321098765432109876543210987654321")
        #expect(receipt.contractAddress == "0xcontractaddress")
        #expect(receipt.cumulativeGasUsed == "0x5208")
        #expect(receipt.gasUsed == "0x5208")
        #expect(receipt.status == "0x1")
        #expect(receipt.logs.count == 1)
        #expect(receipt.isSuccessful == true)
    }

    @Test("TransactionReceipt with optional fields missing")
    func testTransactionReceiptOptionalFields() throws {
        let dict: [String: Any] = [
            "transactionHash": "0xtxhash",
            "transactionIndex": "0x1",
            "blockHash": "0xblockhash",
            "blockNumber": "0x10",
            "from": "0x1234567890123456789012345678901234567890",
            // "to" is missing (contract creation)
            // "contractAddress" is missing
            "cumulativeGasUsed": "0x5208",
            "gasUsed": "0x5208",
            "status": "0x1"
            // "logs" is missing
        ]

        let receipt = try TransactionReceipt(from: dict)

        #expect(receipt.to == nil)
        #expect(receipt.contractAddress == nil)
        #expect(receipt.logs.isEmpty)
    }

    @Test("TransactionReceipt isSuccessful returns true for 0x1")
    func testTransactionReceiptSuccessful() throws {
        let dict: [String: Any] = [
            "transactionHash": "0xtxhash",
            "transactionIndex": "0x1",
            "blockHash": "0xblockhash",
            "blockNumber": "0x10",
            "from": "0xfrom",
            "cumulativeGasUsed": "0x5208",
            "gasUsed": "0x5208",
            "status": "0x1"
        ]

        let receipt = try TransactionReceipt(from: dict)
        #expect(receipt.isSuccessful == true)
    }

    @Test("TransactionReceipt isSuccessful returns false for 0x0")
    func testTransactionReceiptFailed() throws {
        let dict: [String: Any] = [
            "transactionHash": "0xtxhash",
            "transactionIndex": "0x1",
            "blockHash": "0xblockhash",
            "blockNumber": "0x10",
            "from": "0xfrom",
            "cumulativeGasUsed": "0x5208",
            "gasUsed": "0x5208",
            "status": "0x0"
        ]

        let receipt = try TransactionReceipt(from: dict)
        #expect(receipt.isSuccessful == false)
    }

    @Test("TransactionReceipt throws on missing required field")
    func testTransactionReceiptMissingField() throws {
        let dict: [String: Any] = [
            "transactionHash": "0xtxhash",
            // Missing transactionIndex
            "blockHash": "0xblockhash",
            "blockNumber": "0x10",
            "from": "0xfrom",
            "cumulativeGasUsed": "0x5208",
            "gasUsed": "0x5208",
            "status": "0x1"
        ]

        do {
            _ = try TransactionReceipt(from: dict)
            Issue.record("Should have thrown an error")
        } catch let error as TransactionError {
            if case .invalidResponse(let message) = error {
                #expect(message.contains("Missing transactionIndex"))
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    @Test("TransactionReceipt throws on wrong field type")
    func testTransactionReceiptWrongFieldType() throws {
        let dict: [String: Any] = [
            "transactionHash": "0xtxhash",
            "transactionIndex": 123, // Should be string
            "blockHash": "0xblockhash",
            "blockNumber": "0x10",
            "from": "0xfrom",
            "cumulativeGasUsed": "0x5208",
            "gasUsed": "0x5208",
            "status": "0x1"
        ]

        do {
            _ = try TransactionReceipt(from: dict)
            Issue.record("Should have thrown an error")
        } catch let error as TransactionError {
            if case .invalidResponse(let message) = error {
                #expect(message.contains("Missing transactionIndex"))
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - TransactionError Tests

    @Test("TransactionError invalidResponse has correct description")
    func testTransactionErrorInvalidResponse() {
        let error = TransactionError.invalidResponse("Test message")
        #expect(error.errorDescription?.contains("Invalid response") == true)
        #expect(error.errorDescription?.contains("Test message") == true)
    }

    @Test("TransactionError timeout has correct description")
    func testTransactionErrorTimeout() {
        let error = TransactionError.timeout("Waited too long")
        #expect(error.errorDescription?.contains("Timeout") == true)
        #expect(error.errorDescription?.contains("Waited too long") == true)
    }

    @Test("TransactionError transactionFailed has correct description")
    func testTransactionErrorTransactionFailed() {
        let error = TransactionError.transactionFailed("Reverted")
        #expect(error.errorDescription?.contains("Transaction failed") == true)
        #expect(error.errorDescription?.contains("Reverted") == true)
    }
}
