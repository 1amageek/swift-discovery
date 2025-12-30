# swift-discovery

**Discovery Over Transport** - A Swift implementation of a transport-agnostic peer discovery protocol.

Unlike mDNS which only discovers devices on the same local network, Discovery discovers peers across ALL available transports simultaneously - local network (mDNS), Bluetooth (BLE), and Internet.

## Key Insight

The application never knows HOW a peer was discovered or HOW to connect to it. All transport details are abstracted away.

## Requirements

- macOS 15.0+
- iOS 18.0+
- tvOS 18.0+
- watchOS 11.0+
- visionOS 2.0+
- Swift 6.2+

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/1amageek/swift-discovery.git", from: "1.0.0")
]
```

Then add the dependency to your target:

```swift
.target(
    name: "YourApp",
    dependencies: ["Discovery"]  // Umbrella module
)
```

Or import individual modules:

```swift
.target(
    name: "YourApp",
    dependencies: [
        "DiscoveryCore",           // Core protocols only
        "LocalNetworkTransport",   // mDNS/DNS-SD
    ]
)
```

## Quick Start

```swift
import Discovery

// Create local peer
let peer = LocalPeer(name: "my-device")

// Create coordinator
let coordinator = TransportCoordinator(localPeer: peer)

// Register transports
await coordinator.register(LocalNetworkTransport(localPeer: peer))
await coordinator.register(NearbyTransport(localPeer: peer))
await coordinator.register(RemoteNetworkTransport(localPeer: peer))

// Start all transports
try await coordinator.startAll()

// Discover peers that PROVIDE a capability
let capability = try CapabilityID(parsing: "service.example.action.1.0.0")
for try await discovered in coordinator.discover(provides: capability) {
    print("Found provider: \(discovered.peerID)")
}

// Discover peers that ACCEPT a capability
for try await discovered in coordinator.discover(accepts: capability) {
    print("Found consumer: \(discovered.peerID)")
}

// Invoke a capability
let result = try await coordinator.invoke(
    capability,
    on: discovered.peerID,
    arguments: data
)
```

## Module Structure

```
swift-discovery/
├── DiscoveryCore           # Core protocols and types
├── LocalNetworkTransport   # mDNS/DNS-SD transport (LAN)
├── NearbyTransport         # BLE transport (~100m)
├── RemoteNetworkTransport  # HTTP/WebSocket transport (Internet)
└── Discovery               # Umbrella module (re-exports all)
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Application Layer                        │
│                                                              │
│   discover(provides:) → Stream<DiscoveredPeer>              │
│   discover(accepts:) → Stream<DiscoveredPeer>               │
│   resolve(peerID:) → ResolvedPeer?                          │
│   invoke(capability:on:arguments:) → Result                 │
│                                                              │
│   What application knows:                                    │
│   • PeerID (who)                                            │
│   • Capabilities (what they provide/accept)                 │
│   • Metadata (additional info)                              │
│                                                              │
│   What application does NOT know:                           │
│   • How to reach the peer (transport details)               │
│   • Which transport discovered the peer                     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   TransportCoordinator                       │
│          (Coordinates ALL transports simultaneously)         │
└─────────────────────────────────────────────────────────────┘
         │                   │                    │
         ▼                   ▼                    ▼
┌────────────────┐   ┌──────────────┐   ┌───────────────────┐
│LocalNetwork    │   │ Nearby       │   │ RemoteNetwork     │
│Transport       │   │ Transport    │   │ Transport         │
│(mDNS/TCP)      │   │ (BLE/GATT)   │   │ (HTTP/WebSocket)  │
└────────────────┘   └──────────────┘   └───────────────────┘
```

## Core Concepts

### PeerID

Self-declared identity (like mDNS hostnames):

```swift
let peerID = PeerID("my-robot")
// peerID.name == "my-robot"
// peerID.localName == "my-robot.local"
```

### Capability

Functionality offered by peers with semantic versioning:

```swift
let cap = try CapabilityID(parsing: "robot.mobility.move.1.0.0")
// namespace: "robot.mobility"
// name: "move"
// version: 1.0.0
```

### Transport Protocol

Any communication method can conform to `Transport`:

```swift
public protocol Transport: Sendable {
    var transportID: String { get }
    var displayName: String { get }
    var isActive: Bool { get async }

    func start() async throws
    func stop() async throws
    func resolve(_ peerID: PeerID) async throws -> ResolvedPeer?

    // Discover peers that PROVIDE a capability
    func discover(provides: CapabilityID, timeout: Duration)
        -> AsyncThrowingStream<DiscoveredPeer, Error>

    // Discover peers that ACCEPT a capability
    func discover(accepts: CapabilityID, timeout: Duration)
        -> AsyncThrowingStream<DiscoveredPeer, Error>

    // Discover all nearby peers
    func discoverAll(timeout: Duration)
        -> AsyncThrowingStream<DiscoveredPeer, Error>

    func invoke(_ capability: CapabilityID, on peerID: PeerID,
                arguments: Data, timeout: Duration) async throws -> InvocationResult

    var events: AsyncStream<TransportEvent> { get async }
}
```

### TransportCoordinator

Coordinates multiple transports for unified discovery:

```swift
let coordinator = TransportCoordinator(localPeer: peer)
await coordinator.register(LocalNetworkTransport(localPeer: peer))
await coordinator.register(NearbyTransport(localPeer: peer))
try await coordinator.startAll()

// Discovers from ALL transports simultaneously
for try await peer in coordinator.discover(provides: capID) {
    // Don't know which transport found this peer
    print("Found: \(peer.peerID)")
}

// Handle incoming invocations
await coordinator.setIncomingInvocationHandler { payload, senderID in
    // Process the invocation and return response
    return InvokeResponsePayload(
        invocationID: payload.invocationID,
        success: true,
        result: responseData
    )
}
```

## Discovery Model

Discovery supports bidirectional capability matching:

### Providers vs Consumers

```swift
// Find peers that PROVIDE a capability (servers/producers)
for try await peer in coordinator.discover(provides: printCapability) {
    // peer can print documents
}

// Find peers that ACCEPT a capability (clients/consumers)
for try await peer in coordinator.discover(accepts: documentCapability) {
    // peer wants to receive documents
}
```

### Use Cases

| Method | Use Case | Example |
|--------|----------|---------|
| `discover(provides:)` | Find service providers | Find printers, find file servers |
| `discover(accepts:)` | Find service consumers | Find devices waiting for data |

## Transports

| Transport | Discovery | Communication | Scope |
|-----------|-----------|---------------|-------|
| LocalNetworkTransport | mDNS/DNS-SD | TCP | LAN |
| NearbyTransport | BLE Advertising | GATT | ~100m |
| RemoteNetworkTransport | HTTP/.well-known | WebSocket | Internet |

## Handling Incoming Invocations

Set up a handler to respond to incoming capability invocations:

```swift
await coordinator.setIncomingInvocationHandler { payload, senderID in
    switch payload.capability.name {
    case "echo":
        // Echo the received data back
        return InvokeResponsePayload(
            invocationID: payload.invocationID,
            success: true,
            result: payload.arguments
        )
    default:
        return InvokeResponsePayload(
            invocationID: payload.invocationID,
            success: false,
            errorCode: DiscoveryErrorCode.capabilityNotFound.rawValue,
            errorMessage: "Unknown capability"
        )
    }
}
```

## Design Principles

1. **Transport Agnostic** - Application never knows transport details
2. **Multi-Transport Discovery** - All transports searched simultaneously
3. **Location Transparency** - Same API regardless of peer location
4. **Peer-to-Peer** - No central server, all peers equal
5. **Self-Declared Identity** - Like mDNS, no central authority
6. **Actor-Based Concurrency** - Swift actors for thread safety
7. **Bidirectional Discovery** - Find both providers and consumers of capabilities

## License

MIT License
