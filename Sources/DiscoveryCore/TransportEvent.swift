// MARK: - TransportEvent
// Discovery Transport Events
// Events and errors for transport layer

import Foundation

/// Events emitted by a transport
public enum TransportEvent: Sendable {
    /// Transport started
    case started

    /// Transport stopped
    case stopped

    /// Peer discovered
    case peerDiscovered(DiscoveredPeer)

    /// Peer lost (no longer reachable)
    case peerLost(PeerID)

    /// Message received
    case messageReceived(Message, from: PeerID)

    /// Message sent
    case messageSent(Message, to: PeerID)

    /// Error occurred
    case error(TransportError)
}

/// Transport errors
public enum TransportError: Error, Sendable {
    case notStarted
    case alreadyStarted
    case connectionFailed(String)
    case connectionClosed
    case resolutionFailed(PeerID)
    case invocationFailed(InvocationError)
    case timeout
    case invalidData
}
