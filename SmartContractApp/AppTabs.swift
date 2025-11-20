//
//  AppTabs.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/20/25.
//
import SwiftUI

enum AppTab: String, CaseIterable, Hashable, Identifiable {
    case configurations
    case execute
    case chat

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .configurations: return "Configurations"
        case .execute: return "Execute"
        case .chat: return "Chat"
        }
    }

    var systemImage: String {
        switch self {
        case .configurations: return "gearshape.2"
        case .execute: return "doc.text.fill"
        case .chat: return "bubble.right.fill"
        }
    }
}
