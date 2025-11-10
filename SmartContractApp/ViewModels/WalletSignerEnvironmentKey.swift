//
//  WalletSignerEnvironmentKey.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import SwiftUI

// MARK: - Environment Key

private struct WalletSignerKey: EnvironmentKey {
    static let defaultValue: WalletSigner? = nil
}

extension EnvironmentValues {
    var walletSigner: WalletSigner? {
        get { self[WalletSignerKey.self] }
        set { self[WalletSignerKey.self] = newValue }
    }
}
