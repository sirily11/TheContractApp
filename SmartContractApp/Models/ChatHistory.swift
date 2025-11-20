//
//  ChatHistory.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/20/25.
//

import Foundation
import SwiftData

@Model
final class ChatHistory {
    var id: UUID
    var title: String
    var messages: [String]  // JSON strings
    var model: String?
    var providerId: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        messages: [String] = [],
        model: String? = nil,
        providerId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.model = model
        self.providerId = providerId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
