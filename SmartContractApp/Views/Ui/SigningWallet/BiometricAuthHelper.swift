//
//  BiometricAuthHelper.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import Foundation
import LocalAuthentication

/// Helper class for biometric authentication (FaceID/TouchID)
class BiometricAuthHelper {
    // MARK: - Properties

    private let context = LAContext()

    // MARK: - Biometric Availability

    /// Check if biometric authentication is available on this device
    /// - Returns: True if biometric authentication is available
    func isBiometricAvailable() -> Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Get the type of biometric authentication available
    /// - Returns: String describing the biometric type ("Face ID", "Touch ID", or "None")
    func biometricType() -> String {
        guard isBiometricAvailable() else { return "None" }

        switch context.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "None"
        @unknown default:
            return "Unknown"
        }
    }

    // MARK: - Authentication

    /// Authenticate the user with biometrics
    /// - Parameters:
    ///   - reason: The reason for authentication to show to the user
    ///   - completion: Completion handler with success/failure result
    func authenticate(reason: String = "Authenticate to sign transaction", completion: @escaping (Bool, Error?) -> Void) {
        let context = LAContext()
        var error: NSError?

        // Check if biometric authentication is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            completion(false, error)
            return
        }

        // Perform authentication
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }

    /// Authenticate the user with biometrics (async/await version)
    /// - Parameter reason: The reason for authentication to show to the user
    /// - Returns: True if authentication succeeded
    /// - Throws: LAError if authentication fails or is not available
    func authenticate(reason: String = "Authenticate to sign transaction") async throws -> Bool {
        let context = LAContext()
        var error: NSError?

        // Check if biometric authentication is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                throw error
            }
            throw LAError(.biometryNotAvailable)
        }

        // Perform authentication using withCheckedThrowingContinuation
        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                DispatchQueue.main.async {
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: success)
                    }
                }
            }
        }
    }
}

// MARK: - Biometric Error Extension

extension LAError {
    var friendlyMessage: String {
        switch code {
        case .authenticationFailed:
            return "Authentication failed. Please try again."
        case .userCancel:
            return "Authentication was cancelled."
        case .userFallback:
            return "User chose to enter password instead."
        case .biometryNotAvailable:
            return "Biometric authentication is not available on this device."
        case .biometryNotEnrolled:
            return "No biometric authentication is enrolled. Please set up Face ID or Touch ID in Settings."
        case .biometryLockout:
            return "Biometric authentication is locked. Please try again later or use your passcode."
        default:
            return "Authentication error: \(localizedDescription)"
        }
    }
}
