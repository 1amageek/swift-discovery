// MARK: - MessagePayloads
// Discovery Message Payload Types

import Foundation

/// Announce payload
public struct AnnouncePayload: Sendable, Codable {
    /// Peer ID (self-declared name)
    public let peerID: PeerID

    /// Capabilities offered
    public let capabilities: [CapabilityID]

    /// Optional display name
    public let displayName: String?

    /// Metadata
    public let metadata: [String: String]

    public init(
        peerID: PeerID,
        capabilities: [CapabilityID],
        displayName: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.peerID = peerID
        self.capabilities = capabilities
        self.displayName = displayName
        self.metadata = metadata
    }
}

/// Query payload
public struct QueryPayload: Sendable, Codable {
    /// Capability being queried
    public let capability: CapabilityID

    /// Optional filter criteria
    public let filter: [String: String]?

    public init(capability: CapabilityID, filter: [String: String]? = nil) {
        self.capability = capability
        self.filter = filter
    }
}

/// Invoke payload
public struct InvokePayload: Sendable, Codable {
    /// Capability to invoke
    public let capability: CapabilityID

    /// Invocation ID for correlation
    public let invocationID: String

    /// Input arguments (JSON encoded)
    public let arguments: Data

    public init(capability: CapabilityID, invocationID: String, arguments: Data) {
        self.capability = capability
        self.invocationID = invocationID
        self.arguments = arguments
    }
}

/// Invoke response payload
public struct InvokeResponsePayload: Sendable, Codable {
    /// Correlation invocation ID
    public let invocationID: String

    /// Success indicator
    public let success: Bool

    /// Result data (JSON encoded)
    public let result: Data?

    /// Error code if failed
    public let errorCode: UInt32?

    /// Error message if failed
    public let errorMessage: String?

    public init(
        invocationID: String,
        success: Bool,
        result: Data? = nil,
        errorCode: UInt32? = nil,
        errorMessage: String? = nil
    ) {
        self.invocationID = invocationID
        self.success = success
        self.result = result
        self.errorCode = errorCode
        self.errorMessage = errorMessage
    }
}

/// Error payload
public struct ErrorPayload: Sendable, Codable {
    /// Error code
    public let code: UInt32

    /// Error message
    public let message: String

    /// Additional details
    public let details: [String: String]?

    public init(code: UInt32, message: String, details: [String: String]? = nil) {
        self.code = code
        self.message = message
        self.details = details
    }
}
