//
//  Wallet.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/6/25.
//

import Foundation
import KeychainSwift
import SwiftData

@Model
final class EVMWallet {
    var id: UUID
    var alias: String
    var address: String
    /**
         The path to the keychain item that stores the wallet.
         We store the actual private key and mnemonic in the keychain item.
         And our database only stores the path to the keychain item.

         Private key is stored in path {keychainPath}/private_key
         Mnemonic is stored in path {keychainPath}/mnemonic
     */
    var keychainPath: String
    var isFromMnemonic: Bool
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Relationships

    @Relationship(deleteRule: .cascade, inverse: \Transaction.wallet)
    var transactions: [Transaction]?

    init(id: UUID = UUID(), alias: String, address: String, keychainPath: String,
         isFromMnemonic: Bool = false, createdAt: Date = Date(), updatedAt: Date = Date())
    {
        self.id = id
        self.alias = alias
        self.address = address
        self.keychainPath = keychainPath
        self.isFromMnemonic = isFromMnemonic
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Keychain Keys

    private var privateKeyKeychainKey: String {
        "\(keychainPath)/private_key"
    }

    private var mnemonicKeychainKey: String {
        "\(keychainPath)/mnemonic"
    }

    // MARK: - Keychain Access

    /// Retrieves the private key from the keychain
    /// - Throws: `WalletError.privateKeyNotFound` if the private key is not in the keychain
    /// - Returns: The private key as a hex string
    func getPrivateKey() throws(WalletError) -> String {
        let keychain = KeychainSwift()
        guard let privateKey = keychain.get(privateKeyKeychainKey) else {
            throw WalletError.privateKeyNotFound
        }
        return privateKey
    }

    /// Retrieves the mnemonic from the keychain
    /// - Throws: `WalletError.mnemonicNotFound` if the wallet is from a mnemonic but the mnemonic is not in the keychain
    /// - Returns: The mnemonic phrase, or nil if the wallet is not from a mnemonic
    func getMnemonic() throws(WalletError) -> String? {
        guard isFromMnemonic else {
            return nil
        }

        let keychain = KeychainSwift()
        guard let mnemonic = keychain.get(mnemonicKeychainKey) else {
            throw WalletError.mnemonicNotFound
        }
        return mnemonic
    }

    /// Stores the private key in the keychain
    /// - Parameter privateKey: The private key to store (as a hex string)
    /// - Throws: `WalletError.keychainStorageFailed` if the operation fails
    func setPrivateKey(_ privateKey: String) throws(WalletError) {
        let keychain = KeychainSwift()
        guard keychain.set(privateKey, forKey: privateKeyKeychainKey) else {
            throw WalletError.keychainStorageFailed
        }
        updatedAt = Date()
    }

    /// Stores the mnemonic in the keychain
    /// - Parameter mnemonic: The mnemonic phrase to store
    /// - Throws: `WalletError.keychainStorageFailed` if the operation fails
    func setMnemonic(_ mnemonic: String) throws(WalletError) {
        let keychain = KeychainSwift()
        guard keychain.set(mnemonic, forKey: mnemonicKeychainKey) else {
            throw WalletError.keychainStorageFailed
        }
        isFromMnemonic = true
        updatedAt = Date()
    }

    /// Deletes all wallet data from the keychain
    /// - Throws: `WalletError.keychainDeletionFailed` if the operation fails
    func deleteFromKeychain() throws(WalletError) {
        let keychain = KeychainSwift()

        let privateKeyDeleted = keychain.delete(privateKeyKeychainKey)
        let mnemonicDeleted = isFromMnemonic ? keychain.delete(mnemonicKeychainKey) : true

        if !privateKeyDeleted || !mnemonicDeleted {
            throw WalletError.keychainDeletionFailed
        }
    }
}

// MARK: - Wallet Errors

enum WalletError: LocalizedError {
    case privateKeyNotFound
    case mnemonicNotFound
    case keychainStorageFailed
    case keychainDeletionFailed

    var errorDescription: String? {
        switch self {
        case .privateKeyNotFound:
            return "Private key not found in keychain"
        case .mnemonicNotFound:
            return "Mnemonic not found in keychain"
        case .keychainStorageFailed:
            return "Failed to store data in keychain"
        case .keychainDeletionFailed:
            return "Failed to delete data from keychain"
        }
    }
}
