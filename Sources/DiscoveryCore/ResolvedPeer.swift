// MARK: - ResolvedPeer
// Discovery Resolved Peer
// Transport-agnostic peer reference

import Foundation

/// A resolved peer reference
/// Transport details are abstracted away - the application only sees
/// what the peer is, not how to reach it.
public struct ResolvedPeer: Sendable, Identifiable {
    public var id: PeerID { peerID }

    /// Peer's unique ID (self-declared name)
    public let peerID: PeerID

    /// Capabilities provided by this peer (what this peer can do)
    public let provides: [CapabilityID]

    /// Capabilities accepted by this peer (what this peer can receive)
    public let accepts: [CapabilityID]

    /// Peer metadata
    public let metadata: [String: String]

    /// When this resolution was performed
    public let resolvedAt: Date

    /// Time-to-live for this resolution
    public let ttl: Duration

    /// Whether the resolution is still valid (time-based)
    public var isValid: Bool {
        Date() < resolvedAt.addingTimeInterval(ttl.timeInterval)
    }

    /// Backward compatibility: capabilities is an alias for provides
    public var capabilities: [CapabilityID] { provides }

    public init(
        peerID: PeerID,
        provides: [CapabilityID] = [],
        accepts: [CapabilityID] = [],
        metadata: [String: String] = [:],
        resolvedAt: Date = Date(),
        ttl: Duration = .seconds(300)
    ) {
        self.peerID = peerID
        self.provides = provides
        self.accepts = accepts
        self.metadata = metadata
        self.resolvedAt = resolvedAt
        self.ttl = ttl
    }

    /// Convenience initializer with name string
    public init(
        name: String,
        provides: [CapabilityID] = [],
        accepts: [CapabilityID] = [],
        metadata: [String: String] = [:],
        resolvedAt: Date = Date(),
        ttl: Duration = .seconds(300)
    ) {
        self.init(
            peerID: PeerID(name),
            provides: provides,
            accepts: accepts,
            metadata: metadata,
            resolvedAt: resolvedAt,
            ttl: ttl
        )
    }
}
