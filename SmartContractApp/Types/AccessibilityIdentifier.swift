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

    enum Sidebar {
        static let endpoints = A11yID(rawValue: "sidebar-endpoints")
        static let abi = A11yID(rawValue: "sidebar-abi")
        static let wallet = A11yID(rawValue: "sidebar-wallet")
        static let contract = A11yID(rawValue: "sidebar-contract")
    }

    // MARK: - Endpoint Namespace

    enum Endpoint {
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

    enum ABI {
        static let addButton = A11yID(rawValue: "abi-add-button")
        static let createButton = A11yID(rawValue: "abi-create-button")
        static let updateButton = A11yID(rawValue: "abi-update-button")
        static let cancelButton = A11yID(rawValue: "abi-cancel-button")

        static func row(_ id: String) -> A11yID {
            A11yID(rawValue: "abi-row-\(id)")
        }
    }

    // MARK: - Wallet Namespace

    enum Wallet {
        static let addButton = A11yID(rawValue: "wallet-add-button")
        static let createButton = A11yID(rawValue: "wallet-create-button")
        static let updateButton = A11yID(rawValue: "wallet-update-button")
        static let cancelButton = A11yID(rawValue: "wallet-cancel-button")

        // Form fields
        static let privateKeyField = A11yID(rawValue: "wallet-privatekey-field")
        static let aliasTextField = A11yID(rawValue: "wallet-alias-textfield")

        // Menu items
        static let importFromPrivateKeyMenuItem = A11yID(rawValue: "wallet-import-privatekey-menu-item")
        static let randomWalletMenuItem = A11yID(rawValue: "wallet-random-menu-item")

        static func row(_ id: String) -> A11yID {
            A11yID(rawValue: "wallet-row-\(id)")
        }
    }

    // MARK: - Contract Namespace

    enum Contract {
        static let addButton = A11yID(rawValue: "contract-add-button")
        static let createButton = A11yID(rawValue: "contract-create-button")
        static let updateButton = A11yID(rawValue: "contract-update-button")
        static let cancelButton = A11yID(rawValue: "contract-cancel-button")
        static let endpointButton = A11yID(rawValue: "contract-endpoint-button")

        // Menu items
        static let solidityMenuItem = A11yID(rawValue: "contract-solidity-menu-item")
        static let bytecodeMenuItem = A11yID(rawValue: "contract-bytecode-menu-item")

        // Dynamic identifiers
        static func row(_ id: String) -> A11yID {
            A11yID(rawValue: "contract-row-\(id)")
        }

        static func callButton(_ index: Int) -> A11yID {
            A11yID(rawValue: "contract-call-button-\(index)")
        }
    }

    // MARK: - Chat Namespace

    enum Chat {
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

    enum Settings {
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

    // MARK: - Deployment Namespace

    enum Deployment {
        // Navigation buttons
        static let nextButton = A11yID(rawValue: "deployment-next-button")
        static let backButton = A11yID(rawValue: "deployment-back-button")
        static let retryButton = A11yID(rawValue: "deployment-retry-button")
        static let closeButton = A11yID(rawValue: "deployment-close-button")
        static let cancelButton = A11yID(rawValue: "deployment-cancel-button")

        // Form fields
        static let contractNameTextField = A11yID(rawValue: "deployment-contract-name-textfield")
        static let endpointPicker = A11yID(rawValue: "deployment-endpoint-picker")
        static let solidityContractPicker = A11yID(rawValue: "deployment-solidity-contract-picker")
        static let versionPicker = A11yID(rawValue: "deployment-version-picker")

        // Constructor section
        static let constructorSection = A11yID(rawValue: "deployment-constructor-section")
    }

    // MARK: - FunctionCall Namespace

    enum FunctionCall {
        static let cancelButton = A11yID(rawValue: "functioncall-cancel-button")
        static let backButton = A11yID(rawValue: "functioncall-back-button")
        static let continueButton = A11yID(rawValue: "functioncall-continue-button")
        static let callFunctionButton = A11yID(rawValue: "functioncall-call-function-button")
        static let signAndSendButton = A11yID(rawValue: "functioncall-sign-send-button")
        static let doneButton = A11yID(rawValue: "functioncall-done-button")
        static let retryButton = A11yID(rawValue: "functioncall-retry-button")

        // Result page
        static let successMessage = A11yID(rawValue: "functioncall-success-message")
        static let errorMessage = A11yID(rawValue: "functioncall-error-message")

        // Parameter form
        static func parameterField(_ index: Int) -> A11yID {
            A11yID(rawValue: "functioncall-parameter-\(index)")
        }
    }

    // MARK: - Signing Namespace

    enum Signing {
        static let approveButton = A11yID(rawValue: "signing-approve-button")
        static let rejectButton = A11yID(rawValue: "signing-reject-button")
        static let retryButton = A11yID(rawValue: "signing-retry-button")
        static let doneButton = A11yID(rawValue: "signing-done-button")
        static let closeWindowButton = A11yID(rawValue: "signing-close-window-button")
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

    /// Access Deployment identifiers with dot syntax: .deployment.nextButton
    static let deployment = Deployment.self

    /// Access FunctionCall identifiers with dot syntax: .functionCall.continueButton
    static let functionCall = FunctionCall.self

    /// Access Signing identifiers with dot syntax: .signing.approveButton
    static let signing = Signing.self
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
