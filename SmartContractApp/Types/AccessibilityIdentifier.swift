//
//  AccessibilityIdentifier.swift
//  SmartContractApp
//
//  Created by Claude Code
//

import SwiftUI

// MARK: - Accessibility Identifier Wrapper

/// Wrapper type for accessibility identifiers
/// Supports clean dot syntax: .accessibilityIdentifier(.endpoint.cancelButton)
struct A11yID {
    let rawValue: String

    // MARK: - Sidebar Namespace
    struct Sidebar {
        static let endpoints = A11yID(rawValue: "sidebar-endpoints")
        static let abi = A11yID(rawValue: "sidebar-abi")
        static let wallet = A11yID(rawValue: "sidebar-wallet")
        static let contract = A11yID(rawValue: "sidebar-contract")
    }

    // MARK: - Endpoint Namespace
    struct Endpoint {
        // Buttons
        static let addButton = A11yID(rawValue: "endpoint-add-button")
        static let createButton = A11yID(rawValue: "endpoint-create-button")
        static let updateButton = A11yID(rawValue: "endpoint-update-button")
        static let cancelButton = A11yID(rawValue: "endpoint-cancel-button")
        static let detectAgainButton = A11yID(rawValue: "endpoint-detect-again-button")
        static let deleteConfirmButton = A11yID(rawValue: "endpoint-delete-confirm-button")

        // Menu Items
        static let editMenuItem = A11yID(rawValue: "endpoint-edit-menu-item")
        static let deleteMenuItem = A11yID(rawValue: "endpoint-delete-menu-item")

        // Text Fields
        static let nameTextField = A11yID(rawValue: "endpoint-name-textfield")
        static let urlTextField = A11yID(rawValue: "endpoint-url-textfield")
        static let chainIdTextField = A11yID(rawValue: "endpoint-chainid-textfield")
        static let tokenSymbolTextField = A11yID(rawValue: "endpoint-token-symbol-textfield")
        static let tokenNameTextField = A11yID(rawValue: "endpoint-token-name-textfield")
        static let tokenDecimalsTextField = A11yID(rawValue: "endpoint-token-decimals-textfield")

        // Toggles
        static let autoDetectToggle = A11yID(rawValue: "endpoint-auto-detect-toggle")

        // Dynamic IDs
        static func row(_ id: String) -> A11yID {
            A11yID(rawValue: "endpoint-row-\(id)")
        }

        static func rowContent(_ id: String) -> A11yID {
            A11yID(rawValue: "endpoint-row-content-\(id)")
        }
    }

    // MARK: - ABI Namespace
    struct ABI {
        static let addButton = A11yID(rawValue: "abi-add-button")
        static let createButton = A11yID(rawValue: "abi-create-button")
        static let updateButton = A11yID(rawValue: "abi-update-button")
        static let cancelButton = A11yID(rawValue: "abi-cancel-button")

        static func row(_ id: String) -> A11yID {
            A11yID(rawValue: "abi-row-\(id)")
        }
    }

    // MARK: - Wallet Namespace
    struct Wallet {
        static let addButton = A11yID(rawValue: "wallet-add-button")
        static let createButton = A11yID(rawValue: "wallet-create-button")
        static let updateButton = A11yID(rawValue: "wallet-update-button")
        static let cancelButton = A11yID(rawValue: "wallet-cancel-button")

        static func row(_ id: String) -> A11yID {
            A11yID(rawValue: "wallet-row-\(id)")
        }
    }

    // MARK: - Contract Namespace
    struct Contract {
        static let addButton = A11yID(rawValue: "contract-add-button")
        static let createButton = A11yID(rawValue: "contract-create-button")
        static let updateButton = A11yID(rawValue: "contract-update-button")
        static let cancelButton = A11yID(rawValue: "contract-cancel-button")

        static func row(_ id: String) -> A11yID {
            A11yID(rawValue: "contract-row-\(id)")
        }
    }

    // MARK: - Chat Namespace
    struct Chat {
        static let addButton = A11yID(rawValue: "chat-add-button")
        static let deleteButton = A11yID(rawValue: "chat-delete-button")
        static let renameButton = A11yID(rawValue: "chat-rename-button")
        static let openSettingsButton = A11yID(rawValue: "chat-open-settings-button")
        static let providerPicker = A11yID(rawValue: "chat-provider-picker")
        static let modelPicker = A11yID(rawValue: "chat-model-picker")
        static let messageInput = A11yID(rawValue: "chat-message-input")
        static let sendButton = A11yID(rawValue: "chat-send-button")

        static func row(_ id: String) -> A11yID {
            A11yID(rawValue: "chat-row-\(id)")
        }
    }

    // MARK: - Settings Namespace
    struct Settings {
        // Buttons
        static let addButton = A11yID(rawValue: "settings-add-button")
        static let createButton = A11yID(rawValue: "settings-create-button")
        static let updateButton = A11yID(rawValue: "settings-update-button")
        static let cancelButton = A11yID(rawValue: "settings-cancel-button")
        static let fetchModelsButton = A11yID(rawValue: "settings-fetch-models-button")

        // Text Fields
        static let nameTextField = A11yID(rawValue: "settings-name-textfield")
        static let endpointTextField = A11yID(rawValue: "settings-endpoint-textfield")
        static let apiKeyField = A11yID(rawValue: "settings-apikey-field")

        // Pickers
        static let typePicker = A11yID(rawValue: "settings-type-picker")

        // Toggles
        static let autoFetchToggle = A11yID(rawValue: "settings-auto-fetch-toggle")

        static func providerRow(_ id: String) -> A11yID {
            A11yID(rawValue: "settings-provider-row-\(id)")
        }
    }

    // MARK: - Namespace Accessors (Enable dot syntax)

    /// Access Sidebar identifiers with dot syntax: .sidebar.endpoints
    static let sidebar = Sidebar.self

    /// Access Endpoint identifiers with dot syntax: .endpoint.cancelButton
    static let endpoint = Endpoint.self

    /// Access ABI identifiers with dot syntax: .abi.addButton
    static let abi = ABI.self

    /// Access Wallet identifiers with dot syntax: .wallet.addButton
    static let wallet = Wallet.self

    /// Access Contract identifiers with dot syntax: .contract.addButton
    static let contract = Contract.self

    /// Access Chat identifiers with dot syntax: .chat.addButton
    static let chat = Chat.self

    /// Access Settings identifiers with dot syntax: .settings.addButton
    static let settings = Settings.self
}

// MARK: - View Extension

extension View {
    /// Adds an accessibility identifier using the clean dot syntax
    /// - Parameter id: The accessibility identifier (e.g., .endpoint.cancelButton)
    /// - Returns: The view with the accessibility identifier applied
    ///
    /// Usage:
    /// ```swift
    /// Button("Cancel") { }
    ///     .accessibilityIdentifier(.endpoint.cancelButton)
    /// ```
    func accessibilityIdentifier(_ id: A11yID) -> some View {
        self.accessibilityIdentifier(id.rawValue)
    }
}

// MARK: - Legacy Compatibility

/// Legacy type alias for backward compatibility
/// Use A11yID with dot syntax instead: .accessibilityIdentifier(.endpoint.cancelButton)
typealias AccessibilityID = A11yID
