// MARK: - NearbyTransport
// Discovery Nearby Transport
// Proximity-based discovery and communication

import Foundation
import DiscoveryCore
#if canImport(CoreBluetooth)
import CoreBluetooth
#endif

// MARK: - Nearby Transport

/// Transport implementation for nearby peer discovery
///
/// Uses Bluetooth LE for discovery and GATT for communication.
/// Scope: ~100m range (proximity-based)
///
/// This is a sample implementation demonstrating how to implement
/// the Transport protocol. A complete implementation would require
/// proper CoreBluetooth delegate handling.
public actor NearbyTransport: Transport {
    // MARK: - Properties

    public nonisolated let transportID: String = "discovery.nearby"
    public nonisolated let displayName: String = "Nearby"

    /// Discovery BLE Service UUID
    public static let serviceUUID = "DISC0000-0000-1000-8000-00805F9B34FB"

    /// Characteristic for peer info
    public static let peerInfoCharacteristicUUID = "DISC0001-0000-1000-8000-00805F9B34FB"

    /// Characteristic for invocation
    public static let invokeCharacteristicUUID = "DISC0002-0000-1000-8000-00805F9B34FB"

    /// Local peer reference
    private let localPeer: LocalPeer

    /// Is the transport running
    private var running = false

    /// Known peers cache (transport-agnostic, exposed via protocol)
    private var knownPeers: [PeerID: ResolvedPeer] = [:]

    #if canImport(CoreBluetooth)
    /// Internal peripheral mapping (transport-specific, NOT exposed)
    private var peerPeripherals: [PeerID: CBPeripheral] = [:]

    /// RSSI values for quality calculation
    private var peerRSSI: [PeerID: Int] = [:]

    /// Central manager for scanning
    private var centralManager: CBCentralManager?

    /// Peripheral manager for advertising
    private var peripheralManager: CBPeripheralManager?
    #endif

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

        #if canImport(CoreBluetooth)
        // In a complete implementation:
        // 1. Initialize CBCentralManager
        // 2. Initialize CBPeripheralManager
        // 3. Start scanning for Discovery service
        // 4. Start advertising local peer
        #endif

        running = true
        eventContinuation?.yield(.started)
    }

    public func stop() async throws {
        guard running else { return }

        running = false

        #if canImport(CoreBluetooth)
        // Stop scanning
        centralManager?.stopScan()

        // Stop advertising
        peripheralManager?.stopAdvertising()

        // Disconnect all peripherals
        for (_, peripheral) in peerPeripherals {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        peerPeripherals.removeAll()
        peerRSSI.removeAll()
        #endif

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
                            quality: await self.signalQuality(for: peer.peerID),
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
                            quality: await self.signalQuality(for: peer.peerID),
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
                            quality: await self.signalQuality(for: peer.peerID),
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

    public func invoke(
        _ capability: CapabilityID,
        on peerID: PeerID,
        arguments: Data,
        timeout: Duration
    ) async throws -> InvocationResult {
        let startTime = Date()

        #if canImport(CoreBluetooth)
        // Get peripheral (internal transport detail)
        guard let peripheral = peerPeripherals[peerID] else {
            throw TransportError.resolutionFailed(peerID)
        }

        // In a complete implementation:
        // 1. Connect to peripheral if needed
        // 2. Discover services and characteristics
        // 3. Write invocation to invoke characteristic
        // 4. Wait for notification with response

        _ = peripheral  // Suppress unused warning in sample
        #endif

        // Sample: Return timeout error (real implementation would communicate via GATT)
        let roundTripTime = Duration.seconds(Date().timeIntervalSince(startTime))
        return .failure(
            error: InvocationError(code: .resourceUnavailable, message: "BLE invocation not implemented in sample"),
            roundTripTime: roundTripTime,
            sourcePeerID: peerID
        )
    }

    // MARK: - Private Methods

    private func getKnownPeersSnapshot() -> [ResolvedPeer] {
        Array(knownPeers.values)
    }

    /// Signal quality based on RSSI (BLE-specific, converted to 0.0-1.0)
    private func signalQuality(for peerID: PeerID) -> Double {
        #if canImport(CoreBluetooth)
        guard let rssi = peerRSSI[peerID] else {
            return 0.5  // Default quality if RSSI unknown
        }
        return rssiToQuality(Double(rssi))
        #else
        return 0.5
        #endif
    }

    /// Convert RSSI to quality metric (0.0-1.0)
    ///
    /// RSSI typically ranges from -30 (excellent) to -90 (poor)
    private func rssiToQuality(_ rssi: Double) -> Double {
        // RSSI: -30 (best) to -90 (worst)
        // Quality: 1.0 (best) to 0.0 (worst)
        let normalized = (rssi + 90) / 60  // -90 -> 0, -30 -> 1
        return min(max(normalized, 0.0), 1.0)
    }

    #if canImport(CoreBluetooth)
    // MARK: - BLE Discovery Handling (Sample)

    /// Handle discovered peripheral (would be called from CBCentralManagerDelegate)
    func handleDiscoveredPeripheral(
        _ peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi: NSNumber
    ) {
        // Parse peer info from advertisement data
        // In a real implementation, this would parse the service data

        // Sample: Create peer from peripheral name
        guard let name = peripheral.name else { return }

        let peerID = PeerID(name)

        // Don't add ourselves
        guard peerID != localPeer.peerID else { return }

        // Store peripheral internally (transport-specific, NOT exposed)
        peerPeripherals[peerID] = peripheral
        peerRSSI[peerID] = rssi.intValue

        // Create transport-agnostic resolved peer
        // In real implementation, provides/accepts would come from advertisement or GATT read
        let resolved = ResolvedPeer(
            peerID: peerID,
            provides: [],  // Would be populated from advertisement data
            accepts: [],   // Would be populated from advertisement data
            metadata: [:]
        )

        knownPeers[peerID] = resolved

        // Emit discovery event
        let quality = rssiToQuality(rssi.doubleValue)
        for capability in resolved.provides {
            let discovered = DiscoveredPeer(
                peerID: peerID,
                capability: capability,
                quality: quality,
                metadata: resolved.metadata
            )
            eventContinuation?.yield(.peerDiscovered(discovered))
        }
    }

    /// Handle peripheral disconnection
    func handlePeripheralDisconnected(_ peripheral: CBPeripheral) {
        guard let name = peripheral.name else { return }
        let peerID = PeerID(name)

        knownPeers.removeValue(forKey: peerID)
        peerPeripherals.removeValue(forKey: peerID)
        peerRSSI.removeValue(forKey: peerID)

        eventContinuation?.yield(.peerLost(peerID))
    }
    #endif
}

// MARK: - BLE Advertisement Data

/// Data structure for BLE advertisement (service data)
struct BLEAdvertisementData: Codable {
    let name: String
    let version: UInt8
    let capabilityCount: Int
    let metadata: [String: String]

    init(name: String, version: UInt8 = 1, capabilityCount: Int = 0, metadata: [String: String] = [:]) {
        self.name = name
        self.version = version
        self.capabilityCount = capabilityCount
        self.metadata = metadata
    }
}
