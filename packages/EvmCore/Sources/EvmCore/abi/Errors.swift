import Foundation

// MARK: - Errors

public enum AbiParserError: Error, LocalizedError {
    case invalidString
    case invalidFormat
    case encodingFailed
    case fileNotFound
    case invalidItemType(expected: AbiItemType, got: AbiItemType)
    case missingRequiredField(String)

    public var errorDescription: String? {
        switch self {
        case .invalidString:
            return "Invalid string encoding"
        case .invalidFormat:
            return "Invalid ABI format - must be a JSON array or object"
        case .encodingFailed:
            return "Failed to encode ABI to JSON"
        case .fileNotFound:
            return "ABI file not found"
        case .invalidItemType(let expected, let got):
            return "Invalid ABI item type - expected \(expected.rawValue), got \(got.rawValue)"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        }
    }
}
