//
//  Chain.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/7/25.
//
import Foundation

enum SupportedChain: String, CaseIterable, Equatable, Identifiable {
    var id: String { rawValue }
    case evm
}
