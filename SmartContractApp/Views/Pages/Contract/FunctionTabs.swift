//
//  ContractTab.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/20/25.
//
import SwiftUI

enum FunctionTab: LocalizedStringKey, CaseIterable {
    case functions = "Functions"
    case history = "History"

    var systemImage: String {
        switch self {
        case .functions:
            return "function"
        case .history:
            return "clock"
        }
    }
}
