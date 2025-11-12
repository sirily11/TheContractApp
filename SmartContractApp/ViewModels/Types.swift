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
