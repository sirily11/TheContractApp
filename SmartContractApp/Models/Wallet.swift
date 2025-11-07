//
//  Wallet.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/6/25.
//

import Foundation
import SwiftData

@Model
final class EVMWallet {
    var id: Int
    var alias: String
    var address: String
    var derivationPath: String?
    var isFromMnemonic: Bool
    var createdAt: Date
    var updatedAt: Date

    init(id: Int = 0, alias: String, address: String, derivationPath: String? = nil,
         isFromMnemonic: Bool = false, createdAt: Date = Date(), updatedAt: Date = Date())
    {
        self.id = id
        self.alias = alias
        self.address = address
        self.derivationPath = derivationPath
        self.isFromMnemonic = isFromMnemonic
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
