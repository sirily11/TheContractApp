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
    var id: Int
    var endpointId: Int?
    var selectedEVMContractId: Int?
    var selectedEVMAbiId: Int?
    var selectedWalletID: Int?
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    @Relationship var endpoint: Endpoint?
    @Relationship var selectedEVMContract: EVMContract?
    @Relationship var selectedEVMAbi: EvmAbi?
    @Relationship var selectedWallet: EVMWallet?
    
    init(id: Int = 0, endpointId: Int? = nil, selectedEVMContractId: Int? = nil, 
         selectedEVMAbiId: Int? = nil, selectedWalletID: Int? = nil, 
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

