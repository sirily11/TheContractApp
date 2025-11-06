import Foundation

/// Errors that can occur during signing operations
public enum SignerError: Error, LocalizedError {
    case unsupportedOperation(String)
    case invalidPrivateKey
    case signingFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .unsupportedOperation(let message):
            return "Unsupported operation: \(message)"
        case .invalidPrivateKey:
            return "Invalid private key"
        case .signingFailed(let error):
            return "Signing failed: \(error.localizedDescription)"
        }
    }
}
