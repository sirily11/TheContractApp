//
//  Config.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/6/25.
//

import Foundation
import SwiftData

@Model
final class EVMConfig {
    var id: UUID
    var endpointId: UUID?
    var selectedEVMContractId: UUID?
    var selectedEVMAbiId: UUID?
    var selectedWalletID: UUID?
    var createdAt: Date
    var updatedAt: Date

    // Relationships
    @Relationship var endpoint: Endpoint?
    @Relationship var selectedEVMContract: EVMContract?
    @Relationship var selectedEVMAbi: EvmAbi?
    @Relationship var selectedWallet: EVMWallet?

    init(id: UUID = UUID(), endpointId: UUID? = nil, selectedEVMContractId: UUID? = nil,
         selectedEVMAbiId: UUID? = nil, selectedWalletID: UUID? = nil,
         createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.endpointId = endpointId
        self.selectedEVMContractId = selectedEVMContractId
        self.selectedEVMAbiId = selectedEVMAbiId
        self.selectedWalletID = selectedWalletID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

