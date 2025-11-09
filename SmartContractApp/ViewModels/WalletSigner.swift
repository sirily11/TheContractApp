//
//  WalletSigner.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/9/25.
//
import EvmCore
import Foundation

enum SigningProgress {
    case preparing
    case signing
    case sending(transactionHash: String)
    case completed(signedData: Data)
}

protocol WalletSigner {
    var walletSigner: Signer { get }

    func queueSigningRequest(tx: Data) async throws -> Data

    func signAndSend(tx: Data) -> AsyncThrowingStream<SigningProgress, Error>

    func cancelAllSigningRequests() async

    func cancelSigningRequest(at index: Int) async

    // stream of queued signing requests
    var signingRequestStream: AsyncStream<Data> { get }
}
