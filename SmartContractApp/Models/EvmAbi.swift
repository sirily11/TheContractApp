//
//  EvmAbi.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/6/25.
//

import Foundation
import SwiftData

@Model
final class EvmAbi {
    var id: Int
    var name: String
    var abiContent: String // JSON string containing the ABI
    var createdAt: Date
    var updatedAt: Date
    
    init(id: Int = 0, name: String, abiContent: String, 
         createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.abiContent = abiContent
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}