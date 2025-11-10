//
//  WindowStateManager.swift
//  SmartContractApp
//
//  Created by Claude on 11/11/25.
//

import SwiftUI

/// Manages the state of auxiliary windows in the app
@Observable
class WindowStateManager {
    /// Tracks whether the signing wallet window is currently open
    var isSigningWalletWindowOpen: Bool = false
}
