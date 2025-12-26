// MARK: - DiscoveryErrorCode
// Discovery Error Codes

import Foundation

/// Standard Discovery error codes
public enum DiscoveryErrorCode: UInt32, Sendable {
    case unknown = 0
    case invalidMessage = 1001
    case invalidSignature = 1002
    case timestampExpired = 1003
    case capabilityNotFound = 2001
    case capabilityNotAvailable = 2002
    case incompatibleVersion = 2003
    case invocationFailed = 3001
    case invocationTimeout = 3002
    case invocationDenied = 3003
    case trustInsufficient = 4001
    case trustExpired = 4002
    case rateLimitExceeded = 5001
    case resourceUnavailable = 5002
}
