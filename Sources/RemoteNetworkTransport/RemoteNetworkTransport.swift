// MARK: - RemoteNetworkTransport
// Discovery Remote Network Transport
// Cross-network discovery and communication via HTTP/WebSocket

import Foundation
import Network
import DiscoveryCore

// MARK: - Remote Network Transport

/// Transport implementation for remote peer discovery across network boundaries
///
/// Uses HTTP for discovery (/.well-known/discovery-peer.json) and WebSocket for communication.
/// Scope: Remote networks (across the Internet)
public actor RemoteNetworkTransport: Transport {
    // MARK: - Properties

    public nonisolated let transportID: String = "discovery.remote-network"
    public nonisolated let displayName: String = "Remote Network"

    /// Well-known path for peer discovery
    public static let wellKnownPath = ".well-known/discovery-peer.json"

    /// Default WebSocket path
    public static let webSocketPath = "/discovery"

    /// Local peer reference
    private let localPeer: LocalPeer

    /// Is the transport running
    private var running = false

    /// Known peers cache (transport-agnostic, exposed via protocol)
    private var knownPeers: [PeerID: ResolvedPeer] = [:]

    /// Internal URL mapping (transport-specific, NOT exposed)
    private var peerURLs: [PeerID: URL] = [:]

    /// Active WebSocket connections
    private var webSocketTasks: [PeerID: URLSessionWebSocketTask] = [:]

    /// URL session for HTTP requests
    private let urlSession: URLSession

    /// Known peer URLs to poll for discovery
    private var discoveryURLs: [URL] = []

    /// Event continuation
    private var eventContinuation: AsyncStream<TransportEvent>.Continuation?

    /// Events stream
    private var _events: AsyncStream<TransportEvent>?

    // MARK: - Initialization

    public init(localPeer: LocalPeer, discoveryURLs: [URL] = []) {
        self.localPeer = localPeer
        self.discoveryURLs = discoveryURLs
        self.urlSession = URLSession(configuration: .default)
    }

    // MARK: - Configuration

    /// Add a URL to discover peers from
    public func addDiscoveryURL(_ url: URL) {
        discoveryURLs.append(url)
    }

    /// Remove a discovery URL
    public func removeDiscoveryURL(_ url: URL) {
        discoveryURLs.removeAll { $0 == url }
    }

    // MARK: - Transport Protocol

    public var isActive: Bool {
        running
    }

    public var events: AsyncStream<TransportEvent> {
        get async {
            if let existing = _events {
                return existing
            }
            let (stream, continuation) = AsyncStream<TransportEvent>.makeStream()
            _events = stream
            eventContinuation = continuation
            return stream
        }
    }

    public func start() async throws {
        guard !running else {
            throw TransportError.alreadyStarted
        }

        running = true

        // Initial discovery from known URLs
        await discoverFromKnownURLs()

        eventContinuation?.yield(.started)
    }

    public func stop() async throws {
        guard running else { return }

        running = false

        // Close all WebSocket connections
        for (_, task) in webSocketTasks {
            task.cancel(with: .goingAway, reason: nil)
        }
        webSocketTasks.removeAll()
        peerURLs.removeAll()
        knownPeers.removeAll()

        eventContinuation?.yield(.stopped)
    }

    public func resolve(_ peerID: PeerID) async throws -> ResolvedPeer? {
        // Check cache first
        if let cached = knownPeers[peerID], cached.isValid {
            return cached
        }
        return nil
    }

    public nonisolated func discover(
        provides: CapabilityID,
        timeout: Duration
    ) -> AsyncThrowingStream<DiscoveredPeer, Error> {
        AsyncThrowingStream { [self] continuation in
            Task {
                let peers = await self.getKnownPeersSnapshot()

                for peer in peers where peer.isValid {
                    if peer.provides.contains(provides) {
                        let discovered = DiscoveredPeer(
                            peerID: peer.peerID,
                            capability: provides,
                            quality: 1.0,
                            metadata: peer.metadata
                        )
                        continuation.yield(discovered)
                    }
                }

                try? await Task.sleep(for: timeout)
                continuation.finish()
            }
        }
    }

    public nonisolated func discover(
        accepts: CapabilityID,
        timeout: Duration
    ) -> AsyncThrowingStream<DiscoveredPeer, Error> {
        AsyncThrowingStream { [self] continuation in
            Task {
                let peers = await self.getKnownPeersSnapshot()

                for peer in peers where peer.isValid {
                    if peer.accepts.contains(accepts) {
                        let discovered = DiscoveredPeer(
                            peerID: peer.peerID,
                            capability: accepts,
                            quality: 1.0,
                            metadata: peer.metadata
                        )
                        continuation.yield(discovered)
                    }
                }

                try? await Task.sleep(for: timeout)
                continuation.finish()
            }
        }
    }

    public nonisolated func discoverAll(timeout: Duration) -> AsyncThrowingStream<DiscoveredPeer, Error> {
        AsyncThrowingStream { [self] continuation in
            Task {
                let peers = await self.getKnownPeersSnapshot()

                for peer in peers where peer.isValid {
                    for capability in peer.provides {
                        let discovered = DiscoveredPeer(
                            peerID: peer.peerID,
                            capability: capability,
                            quality: 1.0,
                            metadata: peer.metadata
                        )
                        continuation.yield(discovered)
                    }
                }

                try? await Task.sleep(for: timeout)
                continuation.finish()
            }
        }
    }

    private func getKnownPeersSnapshot() -> [ResolvedPeer] {
        Array(knownPeers.values)
    }

    public func invoke(
        _ capability: CapabilityID,
        on peerID: PeerID,
        arguments: Data,
        timeout: Duration
    ) async throws -> InvocationResult {
        let startTime = Date()

        // Get or create WebSocket connection
        let webSocket = try await getWebSocket(to: peerID)

        // Create invocation message
        let invocationID = UUID().uuidString
        let payload = InvokePayload(
            capability: capability,
            invocationID: invocationID,
            arguments: arguments
        )

        let payloadData = try JSONEncoder().encode(payload)
        let message = await localPeer.createMessage(
            type: .invoke,
            to: peerID,
            payload: payloadData
        )

        // Send message via WebSocket
        let messageData = try message.serialize()
        try await webSocket.send(.data(messageData))

        // Wait for response
        let responseData = try await receiveMessage(on: webSocket, timeout: timeout)
        let responseMessage = try Message.deserialize(from: responseData)

        let roundTripTime = Duration.seconds(Date().timeIntervalSince(startTime))

        // Parse response
        guard responseMessage.header.type == .invokeResponse else {
            return .failure(
                error: InvocationError(code: .invocationFailed, message: "Unexpected response type"),
                roundTripTime: roundTripTime,
                sourcePeerID: peerID
            )
        }

        let response = try JSONDecoder().decode(InvokeResponsePayload.self, from: responseMessage.payload)

        if response.success {
            return .success(
                data: response.result ?? Data(),
                roundTripTime: roundTripTime,
                sourcePeerID: peerID
            )
        } else {
            return .failure(
                error: InvocationError(
                    code: DiscoveryErrorCode(rawValue: response.errorCode ?? 0) ?? .unknown,
                    message: response.errorMessage ?? "Unknown error"
                ),
                roundTripTime: roundTripTime,
                sourcePeerID: peerID
            )
        }
    }

    // MARK: - Discovery

    private func discoverFromKnownURLs() async {
        for baseURL in discoveryURLs {
            await discoverPeer(from: baseURL)
        }
    }

    /// Discover a peer from a base URL by fetching /.well-known/discovery-peer.json
    public func discoverPeer(from baseURL: URL) async {
        let wellKnownURL = baseURL.appendingPathComponent(Self.wellKnownPath)

        do {
            let (data, response) = try await urlSession.data(from: wellKnownURL)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return
            }

            let peerInfo = try JSONDecoder().decode(WellKnownPeerInfo.self, from: data)
            let peerID = PeerID(peerInfo.id)

            // Don't add ourselves
            guard peerID != localPeer.peerID else { return }

            // Parse provides capabilities
            var provides: [CapabilityID] = []
            for capString in peerInfo.provides {
                if let capID = try? CapabilityID(parsing: capString) {
                    provides.append(capID)
                }
            }

            // Parse accepts capabilities
            var accepts: [CapabilityID] = []
            for capString in peerInfo.accepts {
                if let capID = try? CapabilityID(parsing: capString) {
                    accepts.append(capID)
                }
            }

            // Store URL internally (transport-specific, NOT exposed)
            peerURLs[peerID] = baseURL

            // Build metadata including websocket path if specified
            var metadata = peerInfo.metadata ?? [:]
            if let websocketPath = peerInfo.websocket {
                metadata["websocket"] = websocketPath
            }

            // Create transport-agnostic resolved peer
            let resolved = ResolvedPeer(
                peerID: peerID,
                provides: provides,
                accepts: accepts,
                metadata: metadata
            )

            knownPeers[peerID] = resolved

            // Emit discovery event for each provides capability
            for capability in provides {
                let discovered = DiscoveredPeer(
                    peerID: peerID,
                    capability: capability,
                    metadata: metadata
                )
                eventContinuation?.yield(.peerDiscovered(discovered))
            }
        } catch {
            // Discovery failed - ignore
        }
    }

    // MARK: - WebSocket

    private func getWebSocket(to peerID: PeerID) async throws -> URLSessionWebSocketTask {
        // Check existing connection
        if let existing = webSocketTasks[peerID],
           existing.state == .running {
            return existing
        }

        // Get base URL (internal transport detail)
        guard let baseURL = peerURLs[peerID] else {
            throw TransportError.resolutionFailed(peerID)
        }

        // Create WebSocket URL
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true) else {
            throw TransportError.connectionFailed("Invalid base URL")
        }
        components.scheme = baseURL.scheme == "https" ? "wss" : "ws"

        // Use custom websocket path if available from peer info, otherwise use default
        if let resolved = knownPeers[peerID],
           let customPath = resolved.metadata["websocket"] {
            components.path = customPath
        } else {
            components.path = Self.webSocketPath
        }

        guard let wsURL = components.url else {
            throw TransportError.connectionFailed("Invalid WebSocket URL")
        }

        // Create WebSocket task
        let task = urlSession.webSocketTask(with: wsURL)
        webSocketTasks[peerID] = task
        task.resume()

        return task
    }

    private func receiveMessage(on webSocket: URLSessionWebSocketTask, timeout: Duration) async throws -> Data {
        try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                let message = try await webSocket.receive()
                switch message {
                case .data(let data):
                    return data
                case .string(let string):
                    return string.data(using: .utf8) ?? Data()
                @unknown default:
                    throw TransportError.timeout
                }
            }

            group.addTask {
                try await Task.sleep(for: timeout)
                throw TransportError.timeout
            }

            guard let result = try await group.next() else {
                throw TransportError.timeout
            }
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Well-Known Peer Info

/// Structure for /.well-known/discovery-peer.json
public struct WellKnownPeerInfo: Codable {
    /// Peer ID (name)
    public let id: String

    /// Protocol version
    public let version: Int

    /// List of capability IDs this peer provides (what it can do)
    public let provides: [String]

    /// List of capability IDs this peer accepts (what it can receive)
    public let accepts: [String]

    /// WebSocket endpoint (optional, defaults to /discovery)
    public let websocket: String?

    /// Peer metadata
    public let metadata: [String: String]?

    public init(
        id: String,
        version: Int = 1,
        provides: [String] = [],
        accepts: [String] = [],
        websocket: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.version = version
        self.provides = provides
        self.accepts = accepts
        self.websocket = websocket
        self.metadata = metadata
    }

    /// Backward compatibility: capabilities is an alias for provides
    @available(*, deprecated, renamed: "provides")
    public var capabilities: [String] { provides }
}
