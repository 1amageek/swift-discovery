// MARK: - Transport
// Discovery Transport Protocol
// Abstract protocol for any communication method

import Foundation

// MARK: - Transport Protocol

/// Protocol for Discovery transport mechanisms
///
/// Any communication method can conform to this protocol to be integrated into Discovery.
/// Transport details (endpoints, addresses, connection types) are internal to each
/// implementation and are NOT exposed to the application layer.
///
/// Example implementations:
/// - LocalNetworkTransport: Local network discovery via mDNS/DNS-SD
/// - NearbyTransport: Nearby device discovery via Bluetooth LE
/// - RemoteNetworkTransport: Global discovery via HTTP/.well-known
public protocol Transport: Sendable {
    /// Unique identifier for this transport
    /// Example: "discovery.local-network", "discovery.nearby", "discovery.remote-network"
    var transportID: String { get }

    /// Human-readable display name
    /// Example: "Local Network", "Nearby", "Remote Network"
    var displayName: String { get }

    /// Whether the transport is currently active
    var isActive: Bool { get async }

    // MARK: - Lifecycle

    /// Start the transport
    /// - Throws: TransportError if already started or initialization fails
    func start() async throws

    /// Stop the transport
    /// - Throws: TransportError if not started
    func stop() async throws

    // MARK: - Resolution

    /// Resolve a peer by ID
    ///
    /// Attempts to find and verify the existence of a peer with the given ID.
    /// Returns transport-agnostic information about the peer.
    ///
    /// - Parameter peerID: The peer to resolve
    /// - Returns: Resolved peer reference or nil if not found
    func resolve(_ peerID: PeerID) async throws -> ResolvedPeer?

    // MARK: - Discovery

    /// Discover peers that provide a specific capability
    ///
    /// Searches for peers that provide the specified capability (what they can do).
    /// Results are streamed as they are discovered.
    ///
    /// - Parameters:
    ///   - provides: The capability to search for (what peers can provide)
    ///   - timeout: Maximum time to wait for responses
    /// - Returns: Stream of discovered peers
    func discover(provides: CapabilityID, timeout: Duration) -> AsyncThrowingStream<DiscoveredPeer, Error>

    /// Discover peers that accept a specific capability
    ///
    /// Searches for peers that accept the specified capability (what they can receive).
    /// Results are streamed as they are discovered.
    ///
    /// - Parameters:
    ///   - accepts: The capability to search for (what peers can accept)
    ///   - timeout: Maximum time to wait for responses
    /// - Returns: Stream of discovered peers
    func discover(accepts: CapabilityID, timeout: Duration) -> AsyncThrowingStream<DiscoveredPeer, Error>

    /// Discover all nearby peers
    ///
    /// Searches for all reachable peers regardless of capability.
    /// Results are streamed as they are discovered.
    ///
    /// - Parameter timeout: Maximum time to wait for responses
    /// - Returns: Stream of discovered peers
    func discoverAll(timeout: Duration) -> AsyncThrowingStream<DiscoveredPeer, Error>

    // MARK: - Invocation

    /// Invoke a capability on a remote peer
    ///
    /// Sends an invocation request to the specified peer and waits for response.
    /// The transport handles all connection details internally.
    ///
    /// - Parameters:
    ///   - capability: The capability to invoke
    ///   - peerID: Target peer ID
    ///   - arguments: Invocation arguments (typically JSON encoded)
    ///   - timeout: Maximum time to wait for response
    /// - Returns: Invocation result (success with data or failure with error)
    func invoke(
        _ capability: CapabilityID,
        on peerID: PeerID,
        arguments: Data,
        timeout: Duration
    ) async throws -> InvocationResult

    // MARK: - Events

    /// Stream of transport events
    ///
    /// Provides real-time notifications about:
    /// - Transport lifecycle (started, stopped)
    /// - Peer discovery and loss
    /// - Messages received and sent
    /// - Errors
    var events: AsyncStream<TransportEvent> { get async }
}

// MARK: - Response Sending Transport Protocol

/// Protocol for transports that can send responses to incoming requests
public protocol ResponseSendingTransport: Transport {
    /// Send a response back to a peer
    ///
    /// - Parameters:
    ///   - data: Response data (JSON encoded InvokeResponsePayload)
    ///   - recipientID: The peer to send to
    ///   - originalMessage: The original invoke message (for correlation)
    func sendResponse(_ data: Data, to recipientID: PeerID, inResponseTo originalMessage: Message) async throws
}

// MARK: - Backward Compatibility

extension Transport {
    /// Backward compatibility: discover(capability:) is an alias for discover(provides:)
    @available(*, deprecated, renamed: "discover(provides:timeout:)")
    func discover(capability: CapabilityID, timeout: Duration) -> AsyncThrowingStream<DiscoveredPeer, Error> {
        discover(provides: capability, timeout: timeout)
    }
}

// MARK: - Duration Extension

extension Duration {
    /// Convert to TimeInterval for Date calculations
    var timeInterval: TimeInterval {
        let (seconds, attoseconds) = self.components
        return TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
    }
}
