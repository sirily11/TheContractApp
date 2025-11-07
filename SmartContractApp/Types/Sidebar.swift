//
//  Sidebar.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/7/25.
//

enum SidebarCategory: String, CaseIterable, Hashable, Identifiable {
    case endpoints
    case abi
    case contract
    case wallet

    var id: String { rawValue }

    var title: String {
        switch self {
        case .endpoints: return "Endpoints"
        case .abi: return "ABI"
        case .contract: return "Contract"
        case .wallet: return "Wallet"
        }
    }

    var systemImage: String {
        switch self {
        case .endpoints: return "network"
        case .abi: return "doc.text"
        case .contract: return "scroll"
        case .wallet: return "creditcard"
        }
    }
}
