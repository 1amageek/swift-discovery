// MARK: - MessageFlags
// Discovery Message Flags

import Foundation

/// Flags for message behavior
public struct MessageFlags: OptionSet, Sendable, Hashable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    /// Message requires acknowledgment
    public static let requiresAck = MessageFlags(rawValue: 1 << 0)

    /// Message is encrypted
    public static let encrypted = MessageFlags(rawValue: 1 << 1)

    /// Message is compressed
    public static let compressed = MessageFlags(rawValue: 1 << 2)

    /// Message is a broadcast
    public static let broadcast = MessageFlags(rawValue: 1 << 3)

    /// Message is urgent/high priority
    public static let urgent = MessageFlags(rawValue: 1 << 4)

    /// Message is a response
    public static let response = MessageFlags(rawValue: 1 << 5)

    /// Message is part of a stream
    public static let streaming = MessageFlags(rawValue: 1 << 6)

    /// Final message in stream
    public static let final = MessageFlags(rawValue: 1 << 7)
}
