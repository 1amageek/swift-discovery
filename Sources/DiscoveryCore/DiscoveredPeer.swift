// MARK: - DiscoveredPeer
// Discovery Discovered Peer
// Transport-agnostic discovered peer

import Foundation

/// A peer discovered during capability search
/// Transport details are abstracted away - the application only sees
/// what the peer is and what it can do, not how it was found.
public struct DiscoveredPeer: Sendable, Identifiable {
    public var id: PeerID { peerID }

    /// Peer's unique ID (self-declared name)
    public let peerID: PeerID

    /// The matched capability
    public let capability: CapabilityID

    /// Signal strength or quality metric (0.0 to 1.0)
    /// This is transport-agnostic: could be BLE RSSI, network latency, etc.
    public let quality: Double

    /// When discovered
    public let discoveredAt: Date

    /// Peer metadata
    public let metadata: [String: String]

    public init(
        peerID: PeerID,
        capability: CapabilityID,
        quality: Double = 1.0,
        discoveredAt: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.peerID = peerID
        self.capability = capability
        self.quality = min(max(quality, 0.0), 1.0)
        self.discoveredAt = discoveredAt
        self.metadata = metadata
    }

    /// Convenience initializer with name string
    public init(
        name: String,
        capability: CapabilityID,
        quality: Double = 1.0,
        discoveredAt: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.init(
            peerID: PeerID(name),
            capability: capability,
            quality: quality,
            discoveredAt: discoveredAt,
            metadata: metadata
        )
    }
}
