// MARK: - InvocationResult
// Discovery Invocation Result

import Foundation

/// Result of a capability invocation
public struct InvocationResult: Sendable {
    /// Whether the invocation succeeded
    public let success: Bool

    /// Result data (JSON encoded) if successful
    public let data: Data?

    /// Error if failed
    public let error: InvocationError?

    /// Round-trip time
    public let roundTripTime: Duration

    /// Source peer ID
    public let sourcePeerID: PeerID

    public init(
        success: Bool,
        data: Data? = nil,
        error: InvocationError? = nil,
        roundTripTime: Duration,
        sourcePeerID: PeerID
    ) {
        self.success = success
        self.data = data
        self.error = error
        self.roundTripTime = roundTripTime
        self.sourcePeerID = sourcePeerID
    }

    /// Create a successful result
    public static func success(
        data: Data,
        roundTripTime: Duration,
        sourcePeerID: PeerID
    ) -> InvocationResult {
        InvocationResult(
            success: true,
            data: data,
            roundTripTime: roundTripTime,
            sourcePeerID: sourcePeerID
        )
    }

    /// Create a failed result
    public static func failure(
        error: InvocationError,
        roundTripTime: Duration,
        sourcePeerID: PeerID
    ) -> InvocationResult {
        InvocationResult(
            success: false,
            error: error,
            roundTripTime: roundTripTime,
            sourcePeerID: sourcePeerID
        )
    }
}

/// Invocation error details
public struct InvocationError: Error, Sendable {
    public let code: DiscoveryErrorCode
    public let message: String
    public let details: [String: String]?

    public init(code: DiscoveryErrorCode, message: String, details: [String: String]? = nil) {
        self.code = code
        self.message = message
        self.details = details
    }
}
