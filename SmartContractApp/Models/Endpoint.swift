//
//  Endpoint.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/5/25.
//

import Foundation
import SwiftData

@Model
final class Endpoint {
    var id: Int
    var name: String
    var url: String
    var chainId: String
    var createdAt: Date
    var updatedAt: Date
    
    init(id: Int = 0, name: String, url: String, chainId: String, 
         createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.url = url
        self.chainId = chainId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
