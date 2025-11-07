//
//  Endpoint.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/5/25.
//

import Foundation
import SwiftData
import EvmCore

enum ChainValidationError: Error, LocalizedError {
    case invalidUrl
    case connectionFailed(String)
    case chainIdMismatch(expected: String, detected: String)

    var errorDescription: String? {
        switch self {
        case .invalidUrl:
            return "Invalid URL format"
        case .connectionFailed(let message):
            return "Failed to connect: \(message)"
        case .chainIdMismatch(let expected, let detected):
            return "Chain ID mismatch! Expected: \(expected), Got: \(detected)"
        }
    }
}

@Model
final class Endpoint {
    var id: Int
    var name: String
    var url: String
    var chainId: String
    var autoDetectChainId: Bool
    var createdAt: Date
    var updatedAt: Date

    init(id: Int = 0, name: String, url: String, chainId: String,
         autoDetectChainId: Bool = false,
         createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.url = url
        self.chainId = chainId
        self.autoDetectChainId = autoDetectChainId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }


    /// Fetches the chain ID from the RPC endpoint and validates it against the stored chain ID
    /// - Returns: The detected chain ID as a string
    /// - Throws: ChainValidationError if URL is invalid, connection fails, or chain ID doesn't match
    func fetchChainId() async throws (ChainValidationError) -> String {
        guard let endpointUrl = URL(string: self.url) else {
            throw ChainValidationError.invalidUrl
        }

        do {
            let transport = HttpTransport(url: endpointUrl)
            let evmClient = EvmClient(transport: transport)
            let chainIdBigInt = try await evmClient.chainId()
            let detectedChainId = String(chainIdBigInt)

            // Validate that detected chain ID matches stored chain ID
            if detectedChainId != self.chainId {
                throw ChainValidationError.chainIdMismatch(
                    expected: self.chainId,
                    detected: detectedChainId
                )
            }

            return detectedChainId
        } catch let error as ChainValidationError {
            throw error
        } catch {
            throw ChainValidationError.connectionFailed(error.localizedDescription)
        }
    }
}
