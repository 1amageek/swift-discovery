// MARK: - PeerID
// Discovery Peer Identifier
// Self-declared identity following mDNS philosophy

import Foundation

/// Peer identifier (self-declared, like mDNS hostname)
public struct PeerID: Sendable, Hashable, Codable, CustomStringConvertible {
    /// Peer name (like mDNS service instance name)
    public let name: String

    /// Initialize with a name
    /// - Parameter name: Peer name (1-63 characters, DNS-compatible)
    public init(_ name: String) {
        // Sanitize to DNS-compatible name
        let sanitized = name
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        self.name = String(sanitized.prefix(63))
    }

    /// Full identifier for mDNS (name.local)
    public var localName: String {
        "\(name).local"
    }

    /// Short representation for display
    public var shortString: String {
        String(name.prefix(8))
    }

    public var description: String {
        "Peer(\(name))"
    }

    /// Broadcast ID (empty name)
    public static let broadcast = PeerID("")

    /// Check if this is a broadcast ID
    public var isBroadcast: Bool {
        name.isEmpty
    }
}

// MARK: - Codable

extension PeerID {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let name = try container.decode(String.self)
        self.init(name)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(name)
    }
}
