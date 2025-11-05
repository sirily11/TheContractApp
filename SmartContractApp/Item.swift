//
//  Item.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/5/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
