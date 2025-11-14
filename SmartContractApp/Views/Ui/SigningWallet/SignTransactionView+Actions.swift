//
//  SignTransactionView+Actions.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import LocalAuthentication
import SwiftUI

// MARK: - Actions

extension SignTransactionView {
    /// Estimate gas fee for the transaction
    func estimateGasFee() async {
        // Skip if transaction already has a gas estimate
        guard transaction.gasEstimate == nil else {
            estimatedGas = transaction.gasEstimate
            return
        }

        // Verify we have an endpoint and wallet
        guard let endpoint = selectedEndpoint else {
            gasEstimationError = "No network endpoint selected"
            return
        }

        guard let wallet = selectedWallet else {
            gasEstimationError = "No wallet selected"
            return
        }

        // Set the current wallet on the view model
        walletSigner.currentWallet = wallet

        isEstimatingGas = true
        gasEstimationError = nil

        do {
            let estimate = try await walletSigner.estimateGasForTransaction(transaction, endpoint: endpoint)
            estimatedGas = estimate
            isEstimatingGas = false
        } catch {
            gasEstimationError = error.localizedDescription
            isEstimatingGas = false
        }
    }

    /// Authenticate with biometrics and approve the transaction
    func authenticateAndApprove() async {
        isAuthenticating = true
        authenticationResult = nil

        do {
            // Authenticate with biometrics
            let authSuccess = try await biometricHelper.authenticate(reason: "Authenticate to sign transaction")

            guard authSuccess else {
                authenticationResult = false
                isAuthenticating = false
                return
            }

            // Verify we have an endpoint and wallet
            guard let endpoint = selectedEndpoint else {
                authenticationResult = false
                isAuthenticating = false
                return
            }

            guard let wallet = selectedWallet else {
                authenticationResult = false
                isAuthenticating = false
                return
            }

            // Set the current wallet on the view model
            walletSigner.currentWallet = wallet

            // Authentication complete, now process transaction
            // (view model will manage isProcessingTransaction state)
            isAuthenticating = false

            // Sign and send transaction
            let txHash = try await walletSigner.processApprovedTransaction(transaction, endpoint: endpoint)

            // Success!
            authenticationResult = true

        } catch let error as LAError {
            // Handle biometric authentication errors
            authenticationResult = false
            isAuthenticating = false
        } catch {
            // Handle signing/network errors
            authenticationResult = false
            isAuthenticating = false
        }
    }

    /// Reject the transaction and dismiss the view
    func rejectTransaction() {
        do {
            try walletSigner.rejectTransaction(transaction)
        } catch {
            // Log error but still dismiss to avoid UI stuck state
            print("Error rejecting transaction: \(error.localizedDescription)")
        }
        dismiss()
    }
}
