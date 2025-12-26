// MARK: - MessageType
// Discovery Message Type

import Foundation

/// Types of Discovery messages
public enum MessageType: UInt8, Sendable, Hashable, Codable, CaseIterable {
    /// Peer presence announcement
    case announce = 0x01

    /// Capability query
    case query = 0x02

    /// Query response
    case queryResponse = 0x03

    /// Capability invocation request
    case invoke = 0x04

    /// Invocation response
    case invokeResponse = 0x05

    /// Notification/event
    case notify = 0x06

    /// Error response
    case error = 0x07

    /// Ping (keepalive)
    case ping = 0x08

    /// Pong (keepalive response)
    case pong = 0x09

    /// Trust verification request
    case trustVerify = 0x0A

    /// Trust verification response
    case trustVerifyResponse = 0x0B

    public var name: String {
        switch self {
        case .announce: return "ANNOUNCE"
        case .query: return "QUERY"
        case .queryResponse: return "QUERY_RESPONSE"
        case .invoke: return "INVOKE"
        case .invokeResponse: return "INVOKE_RESPONSE"
        case .notify: return "NOTIFY"
        case .error: return "ERROR"
        case .ping: return "PING"
        case .pong: return "PONG"
        case .trustVerify: return "TRUST_VERIFY"
        case .trustVerifyResponse: return "TRUST_VERIFY_RESPONSE"
        }
    }
}
