// MARK: - LocalPeer
// Discovery Local Peer
// Represents the local peer in the discovery network

import Foundation

/// Represents the local peer running this code
public struct LocalPeer: Sendable {
    /// Peer's ID (self-declared name)
    public let peerID: PeerID

    /// Capabilities provided by this peer (what this peer can do)
    public let provides: CapabilitySet

    /// Capabilities accepted by this peer (what this peer can receive)
    public let accepts: CapabilitySet

    /// Display name
    public let displayName: String?

    /// Peer metadata
    public let metadata: [String: String]

    /// Message sequence counter
    private let sequenceCounter: SequenceCounter

    public init(
        name: String,
        provides: CapabilitySet = CapabilitySet(),
        accepts: CapabilitySet = CapabilitySet(),
        displayName: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.peerID = PeerID(name)
        self.provides = provides
        self.accepts = accepts
        self.displayName = displayName
        self.metadata = metadata
        self.sequenceCounter = SequenceCounter()
    }

    /// Backward compatibility: capabilities is an alias for provides
    public var capabilities: CapabilitySet { provides }

    /// Get next sequence number
    public func nextSequenceNumber() async -> UInt32 {
        await sequenceCounter.next()
    }

    /// Create a message
    public func createMessage(
        type: MessageType,
        flags: MessageFlags = [],
        to recipientID: PeerID,
        payload: Data
    ) async -> Message {
        Message.create(
            type: type,
            flags: flags,
            senderID: peerID,
            recipientID: recipientID,
            sequenceNumber: await nextSequenceNumber(),
            payload: payload
        )
    }

    /// Create a broadcast message
    public func createBroadcast(
        type: MessageType,
        payload: Data
    ) async -> Message {
        Message.broadcast(
            type: type,
            senderID: peerID,
            sequenceNumber: await nextSequenceNumber(),
            payload: payload
        )
    }
}

/// Thread-safe sequence number counter
actor SequenceCounter {
    private var value: UInt32 = 0

    func next() -> UInt32 {
        value &+= 1
        return value
    }
}
