// MARK: - MessageError
// Discovery Message Errors

import Foundation

/// Result of message validation
public enum MessageValidationResult: Sendable {
    case success
    case failure(MessageValidationError)

    public var isValid: Bool {
        if case .success = self { return true }
        return false
    }
}

/// Message validation errors
public enum MessageValidationError: Error, Sendable {
    case unsupportedVersion(UInt8)
    case payloadLengthMismatch
    case payloadTooLarge
    case malformedHeader
    case malformedPayload
}

/// Errors related to message operations
public enum MessageError: Error, Sendable {
    case serializationFailed
    case insufficientData
    case invalidMessageType
    case invalidPeerID
}

extension MessageError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .serializationFailed:
            return "Failed to serialize message"
        case .insufficientData:
            return "Insufficient data for message deserialization"
        case .invalidMessageType:
            return "Invalid message type"
        case .invalidPeerID:
            return "Invalid peer ID in message"
        }
    }
}
