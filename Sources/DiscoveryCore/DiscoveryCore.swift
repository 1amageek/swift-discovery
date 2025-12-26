// MARK: - DiscoveryCore
// Discovery Over Transport - Core Module
// Transport-agnostic peer discovery protocol

/// DiscoveryCore version
public let DiscoveryCoreVersion = "1.0.0"

/// DiscoveryCore protocol version
public let DiscoveryCoreProtocolVersion: UInt8 = 1

// Re-export all types
// Identity: PeerID (self-declared name)
// Capability: CapabilityID, Capability, CapabilitySet
// Message: Message, MessageHeader, MessageType
// Transport: Transport protocol, Quorum, TransportEvent
// Peer: LocalPeer, ResolvedPeer, DiscoveredPeer
