// MARK: - TransportCoordinator
// Discovery Transport Coordinator
// Manages multiple transports and provides unified access

import Foundation

/// Handler for incoming invocation requests
public typealias IncomingInvocationHandler = @Sendable (
    _ payload: InvokePayload,
    _ senderID: PeerID
) async throws -> InvokeResponsePayload

/// Coordinates multiple transports for unified peer discovery and communication
///
/// TransportCoordinator aggregates results from all registered transports, allowing applications
/// to discover and communicate with peers regardless of the underlying transport.
///
/// ```swift
/// let coordinator = TransportCoordinator(localPeer: peer)
/// await coordinator.register(LocalNetworkTransport(localPeer: peer))
/// await coordinator.register(NearbyTransport(localPeer: peer))
/// try await coordinator.startAll()
///
/// // Discover from ALL transports simultaneously
/// for try await peer in coordinator.discover(capability: capID) {
///     print("Found: \(peer.peerID)")
/// }
/// ```
public actor TransportCoordinator {
    /// Registered transports
    private var transports: [String: any Transport] = [:]

    /// Local peer identity
    public let localPeer: LocalPeer

    /// Handler for incoming invocations
    private var incomingInvocationHandler: IncomingInvocationHandler?

    /// Event listener tasks
    private var eventListenerTasks: [String: Task<Void, Never>] = [:]

    public init(localPeer: LocalPeer) {
        self.localPeer = localPeer
    }

    // MARK: - Incoming Invocation Handler

    /// Set handler for incoming invocations
    public func setIncomingInvocationHandler(_ handler: @escaping IncomingInvocationHandler) {
        self.incomingInvocationHandler = handler
    }

    /// Remove incoming invocation handler
    public func removeIncomingInvocationHandler() {
        self.incomingInvocationHandler = nil
    }

    /// Get the current incoming invocation handler (for testing)
    public func getIncomingInvocationHandler() -> IncomingInvocationHandler? {
        self.incomingInvocationHandler
    }

    // MARK: - Transport Management

    /// Register a transport
    public func register(_ transport: any Transport) {
        transports[transport.transportID] = transport
    }

    /// Unregister a transport
    public func unregister(_ transportID: String) {
        transports.removeValue(forKey: transportID)
    }

    /// Get a specific transport
    public func transport(_ transportID: String) -> (any Transport)? {
        transports[transportID]
    }

    /// All registered transports
    public var allTransports: [any Transport] {
        Array(transports.values)
    }

    // MARK: - Lifecycle

    /// Start all transports
    public func startAll() async throws {
        for transport in transports.values {
            try await transport.start()
            startEventListener(for: transport)
        }
    }

    /// Stop all transports
    public func stopAll() async throws {
        // Cancel all event listeners
        for (transportID, task) in eventListenerTasks {
            task.cancel()
            eventListenerTasks.removeValue(forKey: transportID)
        }

        for transport in transports.values {
            try await transport.stop()
        }
    }

    // MARK: - Event Handling

    /// Start listening for events from a transport
    private func startEventListener(for transport: any Transport) {
        let transportID = transport.transportID

        let task = Task { [weak self] in
            for await event in await transport.events {
                guard let self = self else { break }
                await self.handleEvent(event, from: transportID)
            }
        }

        eventListenerTasks[transportID] = task
    }

    /// Handle an event from a transport
    private func handleEvent(_ event: TransportEvent, from transportID: String) async {
        switch event {
        case .messageReceived(let message, let senderID):
            await handleIncomingMessage(message, from: senderID, via: transportID)

        case .peerDiscovered:
            // Peer discovered - application can handle this through events
            break

        case .error(let error):
            // Log error (could be extended with a delegate)
            _ = error

        default:
            break
        }
    }

    /// Handle incoming message
    private func handleIncomingMessage(_ message: Message, from senderID: PeerID, via transportID: String) async {
        // Only handle invoke messages
        guard message.header.type == .invoke else { return }

        // Parse the invoke payload
        guard let payload = try? JSONDecoder().decode(InvokePayload.self, from: message.payload) else {
            return
        }

        // Call the handler if set
        guard let handler = incomingInvocationHandler else {
            return
        }

        do {
            let response = try await handler(payload, senderID)
            // Send response back via the same transport
            await sendResponse(response, to: senderID, via: transportID, originalMessage: message)
        } catch {
            // Send error response
            let errorResponse = InvokeResponsePayload(
                invocationID: payload.invocationID,
                success: false,
                errorCode: DiscoveryErrorCode.invocationFailed.rawValue,
                errorMessage: error.localizedDescription
            )
            await sendResponse(errorResponse, to: senderID, via: transportID, originalMessage: message)
        }
    }

    /// Send response back to sender
    private func sendResponse(
        _ response: InvokeResponsePayload,
        to recipientID: PeerID,
        via transportID: String,
        originalMessage: Message
    ) async {
        guard let transport = transports[transportID] as? ResponseSendingTransport else {
            return
        }

        do {
            let responseData = try JSONEncoder().encode(response)
            try await transport.sendResponse(responseData, to: recipientID, inResponseTo: originalMessage)
        } catch {
            // Log error
        }
    }

    // MARK: - Resolution (across all transports)

    /// Resolve a peer across all transports
    public func resolve(_ peerID: PeerID) async throws -> ResolvedPeer? {
        for transport in transports.values {
            if let resolved = try await transport.resolve(peerID) {
                return resolved
            }
        }
        return nil
    }

    // MARK: - Discovery (across all transports)

    /// Discover peers that provide a capability across all transports
    public func discover(
        provides: CapabilityID,
        timeout: Duration = .seconds(5)
    ) -> AsyncThrowingStream<DiscoveredPeer, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await withTaskGroup(of: Void.self) { group in
                    for transport in self.transports.values {
                        group.addTask {
                            do {
                                for try await peer in transport.discover(provides: provides, timeout: timeout) {
                                    continuation.yield(peer)
                                }
                            } catch {
                                // Log error but continue with other transports
                            }
                        }
                    }
                }
                continuation.finish()
            }
        }
    }

    /// Discover peers that accept a capability across all transports
    public func discover(
        accepts: CapabilityID,
        timeout: Duration = .seconds(5)
    ) -> AsyncThrowingStream<DiscoveredPeer, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await withTaskGroup(of: Void.self) { group in
                    for transport in self.transports.values {
                        group.addTask {
                            do {
                                for try await peer in transport.discover(accepts: accepts, timeout: timeout) {
                                    continuation.yield(peer)
                                }
                            } catch {
                                // Log error but continue with other transports
                            }
                        }
                    }
                }
                continuation.finish()
            }
        }
    }

    /// Backward compatibility: discover(capability:) is an alias for discover(provides:)
    @available(*, deprecated, renamed: "discover(provides:timeout:)")
    public func discover(
        capability: CapabilityID,
        timeout: Duration = .seconds(5)
    ) -> AsyncThrowingStream<DiscoveredPeer, Error> {
        discover(provides: capability, timeout: timeout)
    }

    // MARK: - Invocation

    /// Invoke capability on peer using best available transport
    public func invoke(
        _ capability: CapabilityID,
        on peerID: PeerID,
        arguments: Data,
        timeout: Duration = .seconds(30)
    ) async throws -> InvocationResult {
        // Try to resolve peer first
        guard let resolved = try await resolve(peerID) else {
            throw TransportError.resolutionFailed(peerID)
        }

        // Check if the peer has the requested capability
        guard resolved.capabilities.contains(capability) else {
            throw TransportError.invocationFailed(
                InvocationError(code: .capabilityNotFound, message: "Peer does not have capability: \(capability)")
            )
        }

        // Find an active transport to invoke
        for transport in transports.values {
            if await transport.isActive {
                do {
                    let result = try await transport.invoke(
                        capability,
                        on: peerID,
                        arguments: arguments,
                        timeout: timeout
                    )
                    return result
                } catch {
                    // Try next transport
                    continue
                }
            }
        }

        throw TransportError.invocationFailed(
            InvocationError(code: .resourceUnavailable, message: "No transport available")
        )
    }
}
