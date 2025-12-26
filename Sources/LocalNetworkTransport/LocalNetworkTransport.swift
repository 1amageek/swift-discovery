// MARK: - LocalNetworkTransport
// Discovery Local Network Transport
// Same network discovery and communication

import Foundation
import Network
import DiscoveryCore

// MARK: - Local Network Transport

/// Transport implementation for same-network peer discovery
///
/// Uses mDNS/DNS-SD for discovery and TCP for communication.
/// Scope: Same network (LAN, WiFi)
public actor LocalNetworkTransport: Transport {
    // MARK: - Properties

    public nonisolated let transportID: String = "discovery.local-network"
    public nonisolated let displayName: String = "Local Network"

    /// mDNS service type
    public static let serviceType = "_discovery._tcp"

    /// mDNS service domain
    public static let serviceDomain = "local."

    /// Local peer reference
    private let localPeer: LocalPeer

    /// Is the system running
    private var running = false

    /// NWBrowser for discovery
    private var browser: NWBrowser?

    /// NWListener for incoming connections
    private var listener: NWListener?

    /// Known peers cache (transport-agnostic info)
    private var knownPeers: [PeerID: ResolvedPeer] = [:]

    /// Internal endpoint mapping (transport-specific, not exposed)
    private var peerEndpoints: [PeerID: String] = [:]

    /// Active connections
    private var connections: [PeerID: NWConnection] = [:]

    /// Event continuation
    private var eventContinuation: AsyncStream<TransportEvent>.Continuation?

    /// Events stream
    private var _events: AsyncStream<TransportEvent>?

    // MARK: - Initialization

    public init(localPeer: LocalPeer) {
        self.localPeer = localPeer
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

        // Start listener for incoming connections
        try await startListener()

        // Start browser for discovery
        try await startBrowser()

        running = true
        eventContinuation?.yield(.started)
    }

    public func stop() async throws {
        guard running else { return }

        running = false

        // Stop browser
        browser?.cancel()
        browser = nil

        // Stop listener
        listener?.cancel()
        listener = nil

        // Close all connections
        for (_, connection) in connections {
            connection.cancel()
        }
        connections.removeAll()
        peerEndpoints.removeAll()
        knownPeers.removeAll()

        eventContinuation?.yield(.stopped)
    }

    public func resolve(_ peerID: PeerID) async throws -> ResolvedPeer? {
        // Check cache first
        if let cached = knownPeers[peerID], cached.isValid {
            return cached
        }

        // For mDNS, we rely on discovery to populate the cache
        // Return nil if not found
        return nil
    }

    public nonisolated func discover(
        provides: CapabilityID,
        timeout: Duration
    ) -> AsyncThrowingStream<DiscoveredPeer, Error> {
        AsyncThrowingStream { [self] continuation in
            Task {
                // Get snapshot of known peers
                let peers = await self.getKnownPeersSnapshot()

                // Filter by provides capability
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

                // Wait for timeout to discover more
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
                // Get snapshot of known peers
                let peers = await self.getKnownPeersSnapshot()

                // Filter by accepts capability
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

                // Wait for timeout to discover more
                try? await Task.sleep(for: timeout)
                continuation.finish()
            }
        }
    }

    public nonisolated func discoverAll(timeout: Duration) -> AsyncThrowingStream<DiscoveredPeer, Error> {
        AsyncThrowingStream { [self] continuation in
            Task {
                // Get snapshot of known peers
                let peers = await self.getKnownPeersSnapshot()

                // Return all known peers with their provides capabilities
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

                // Wait for timeout to discover more
                try? await Task.sleep(for: timeout)
                continuation.finish()
            }
        }
    }

    /// Get a snapshot of known peers for discovery
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

        // Get or create connection
        let connection = try await getConnection(to: peerID)

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

        // Send message
        let messageData = try message.serialize()
        try await send(messageData, on: connection)

        // Wait for response
        let responseData = try await receive(on: connection, timeout: timeout)
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

    // MARK: - Private Methods

    private func startListener() async throws {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true

        // Add TXT record with peer info
        let txtRecord = createTXTRecord()

        listener = try NWListener(using: parameters)

        // Advertise service
        listener?.service = NWListener.Service(
            name: localPeer.peerID.name,
            type: Self.serviceType,
            domain: Self.serviceDomain,
            txtRecord: txtRecord
        )

        listener?.stateUpdateHandler = { [weak self] state in
            Task { await self?.handleListenerState(state) }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            Task { await self?.handleNewConnection(connection) }
        }

        listener?.start(queue: .global())
    }

    private func startBrowser() async throws {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        browser = NWBrowser(
            for: .bonjour(type: Self.serviceType, domain: Self.serviceDomain),
            using: parameters
        )

        browser?.stateUpdateHandler = { [weak self] state in
            Task { await self?.handleBrowserState(state) }
        }

        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            Task { await self?.handleBrowseResults(results, changes: changes) }
        }

        browser?.start(queue: .global())
    }

    private func createTXTRecord() -> NWTXTRecord {
        var record = NWTXTRecord()
        record["id"] = localPeer.peerID.name
        record["v"] = String(DiscoveryCoreProtocolVersion)

        // Add provides capabilities (space-separated, truncated if needed)
        let providesList = localPeer.provides.all.map { $0.id.fullString }.joined(separator: " ")
        if providesList.count <= 255 {
            record["provides"] = providesList
        } else {
            record["provides"] = String(providesList.prefix(252)) + "..."
        }

        // Add accepts capabilities (space-separated, truncated if needed)
        let acceptsList = localPeer.accepts.all.map { $0.id.fullString }.joined(separator: " ")
        if acceptsList.count <= 255 {
            record["accepts"] = acceptsList
        } else {
            record["accepts"] = String(acceptsList.prefix(252)) + "..."
        }

        if let name = localPeer.displayName {
            record["name"] = name
        }

        return record
    }

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            break
        case .failed(let error):
            eventContinuation?.yield(.error(.connectionFailed(error.localizedDescription)))
        default:
            break
        }
    }

    private func handleBrowserState(_ state: NWBrowser.State) {
        switch state {
        case .ready:
            break
        case .failed(let error):
            eventContinuation?.yield(.error(.connectionFailed(error.localizedDescription)))
        default:
            break
        }
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>, changes: Set<NWBrowser.Result.Change>) {
        for change in changes {
            switch change {
            case .added(let result):
                handleDiscoveredService(result)
            case .removed(let result):
                handleRemovedService(result)
            default:
                break
            }
        }
    }

    private func handleDiscoveredService(_ result: NWBrowser.Result) {
        guard case .service(let name, let type, let domain, _) = result.endpoint else {
            return
        }

        // Parse TXT record
        if case .bonjour(let txtRecord) = result.metadata {
            let peerName = txtRecord["id"] ?? name
            let peerID = PeerID(peerName)

            // Don't add ourselves
            guard peerID != localPeer.peerID else { return }

            // Parse provides capabilities
            var provides: [CapabilityID] = []
            if let providesString = txtRecord["provides"] {
                for capString in providesString.split(separator: " ") {
                    if let capID = try? CapabilityID(parsing: String(capString)) {
                        provides.append(capID)
                    }
                }
            }

            // Parse accepts capabilities
            var accepts: [CapabilityID] = []
            if let acceptsString = txtRecord["accepts"] {
                for capString in acceptsString.split(separator: " ") {
                    if let capID = try? CapabilityID(parsing: String(capString)) {
                        accepts.append(capID)
                    }
                }
            }

            // Store endpoint internally (transport-specific, not exposed)
            let endpoint = "\(name).\(type)\(domain)"
            peerEndpoints[peerID] = endpoint

            let metadata = txtRecord["name"].map { ["name": $0] } ?? [:]

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
        }
    }

    private func handleRemovedService(_ result: NWBrowser.Result) {
        if case .bonjour(let txtRecord) = result.metadata,
           let idName = txtRecord["id"] {
            let peerID = PeerID(idName)
            knownPeers.removeValue(forKey: peerID)
            peerEndpoints.removeValue(forKey: peerID)
            connections.removeValue(forKey: peerID)?.cancel()
            eventContinuation?.yield(.peerLost(peerID))
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            Task { await self?.handleConnectionState(connection, state: state) }
        }
        connection.start(queue: .global())
    }

    private func handleConnectionState(_ connection: NWConnection, state: NWConnection.State) {
        switch state {
        case .ready:
            // Start receiving messages
            Task { await receiveMessages(on: connection) }
        case .failed, .cancelled:
            // Clean up
            break
        default:
            break
        }
    }

    private func receiveMessages(on connection: NWConnection) async {
        // Continuous receive loop
        while running {
            do {
                let data = try await receive(on: connection, timeout: .seconds(60))
                let message = try Message.deserialize(from: data)
                await handleMessage(message, from: connection)
            } catch {
                break
            }
        }
    }

    private func handleMessage(_ message: Message, from connection: NWConnection) async {
        let senderID = message.header.senderID

        eventContinuation?.yield(.messageReceived(message, from: senderID))

        // Handle based on type
        switch message.header.type {
        case .invoke:
            await handleInvoke(message, from: connection)
        case .ping:
            await handlePing(message, from: connection)
        default:
            break
        }
    }

    private func handleInvoke(_ message: Message, from connection: NWConnection) async {
        // Parse invoke payload
        guard let payload = try? JSONDecoder().decode(InvokePayload.self, from: message.payload) else {
            return
        }

        // Check if we provide the capability
        guard localPeer.provides.contains(payload.capability) else {
            let errorPayload = InvokeResponsePayload(
                invocationID: payload.invocationID,
                success: false,
                errorCode: DiscoveryErrorCode.capabilityNotFound.rawValue,
                errorMessage: "Capability not found"
            )
            await sendResponse(errorPayload, to: message.header.senderID, on: connection)
            return
        }

        // For now, send a placeholder response
        // In a real implementation, this would invoke the actual capability handler
        let responsePayload = InvokeResponsePayload(
            invocationID: payload.invocationID,
            success: true,
            result: Data()
        )
        await sendResponse(responsePayload, to: message.header.senderID, on: connection)
    }

    private func handlePing(_ message: Message, from connection: NWConnection) async {
        // Send pong response
        let pongMessage = await localPeer.createMessage(
            type: .pong,
            to: message.header.senderID,
            payload: Data()
        )
        if let data = try? pongMessage.serialize() {
            try? await send(data, on: connection)
        }
    }

    private func sendResponse(_ payload: InvokeResponsePayload, to peerID: PeerID, on connection: NWConnection) async {
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }
        let message = await localPeer.createMessage(
            type: .invokeResponse,
            to: peerID,
            payload: payloadData
        )
        if let data = try? message.serialize() {
            try? await send(data, on: connection)
        }
    }

    private func getConnection(to peerID: PeerID) async throws -> NWConnection {
        // Check existing connection
        if let existing = connections[peerID], existing.state == .ready {
            return existing
        }

        // Get internal endpoint (transport-specific)
        guard let endpointString = peerEndpoints[peerID] else {
            throw TransportError.resolutionFailed(peerID)
        }

        // Create new connection
        let endpoint = NWEndpoint.service(
            name: endpointString.components(separatedBy: ".").first ?? "",
            type: Self.serviceType,
            domain: Self.serviceDomain,
            interface: nil
        )

        let connection = NWConnection(to: endpoint, using: .tcp)
        connections[peerID] = connection

        return try await withCheckedThrowingContinuation { continuation in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    continuation.resume(returning: connection)
                case .failed(let error):
                    continuation.resume(throwing: TransportError.connectionFailed(error.localizedDescription))
                default:
                    break
                }
            }
            connection.start(queue: .global())
        }
    }

    private func send(_ data: Data, on connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func receive(on connection: NWConnection, timeout: Duration) async throws -> Data {
        try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let data = data {
                            continuation.resume(returning: data)
                        } else {
                            continuation.resume(throwing: TransportError.timeout)
                        }
                    }
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
