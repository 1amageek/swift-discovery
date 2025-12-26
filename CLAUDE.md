# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**swift-discovery** (Discovery Over Transport) is a Swift implementation of a **transport-agnostic peer discovery protocol**. Unlike mDNS which only discovers devices on the same local network, Discovery discovers peers across ALL available transports simultaneously - local network (mDNS), Bluetooth (BLE), and Internet.

Key insight: The application never knows HOW a peer was discovered or HOW to connect to it. All transport details are abstracted away.

## Build Commands

```bash
# Build
swift build

# Run tests
swift test

# Run a single test
swift test --filter DiscoveryCoreTests.testName
```

## Platform Requirements

- macOS 15.0+
- iOS 18.0+
- Swift 6.2+

## Module Structure

```
swift-discovery/
├── DiscoveryCore           # Core protocols and types
├── LocalNetworkTransport   # mDNS/DNS-SD transport
├── NearbyTransport         # BLE transport
├── RemoteNetworkTransport  # HTTP/WebSocket transport
└── Discovery               # Umbrella module (re-exports all)
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Application Layer                        │
│                                                              │
│   discover(capability:) → Stream<DiscoveredPeer>            │
│   resolve(peerID:) → ResolvedPeer?                          │
│   invoke(capability:on:arguments:) → Result                 │
│                                                              │
│   What application knows:                                    │
│   • PeerID (who)                                            │
│   • Capabilities (what they can do)                         │
│   • Metadata (additional info)                              │
│   • Quality (reliability metric)                            │
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
│                                                              │
│   discover() → merges results from ALL transports           │
│   resolve() → tries ALL transports                          │
│   invoke() → uses best available transport                  │
└─────────────────────────────────────────────────────────────┘
         │                   │                    │
         ▼                   ▼                    ▼
┌────────────────┐   ┌──────────────┐   ┌───────────────────┐
│LocalNetwork    │   │ Nearby       │   │ RemoteNetwork     │
│Transport (LAN) │   │ Transport    │   │ Transport         │
│                │   │ (BLE)        │   │ (Internet)        │
│ Internal:      │   │              │   │                   │
│ • mDNS name    │   │ Internal:    │   │ Internal:         │
│ • TCP conn     │   │ • peripheral │   │ • URL             │
│                │   │ • GATT       │   │ • WebSocket       │
└────────────────┘   └──────────────┘   └───────────────────┘
```

## Core Concepts

### Transport Protocol
Any communication method that conforms to `Transport` can be registered:
```swift
protocol Transport {
    var transportID: String { get }
    func start() async throws
    func stop() async throws
    func resolve(_ peerID: PeerID) async throws -> ResolvedPeer?
    func discover(capability: CapabilityID, timeout: Duration)
        -> AsyncThrowingStream<DiscoveredPeer, Error>
    func invoke(_ capability: CapabilityID, on peerID: PeerID,
                arguments: Data, timeout: Duration) async throws -> InvocationResult
}
```

### TransportCoordinator
The coordination layer that manages multiple transports:
```swift
let coordinator = TransportCoordinator(localPeer: peer)

// Register any Transport implementations
await coordinator.register(LocalNetworkTransport(localPeer: peer))
await coordinator.register(NearbyTransport(localPeer: peer))
await coordinator.register(RemoteNetworkTransport(localPeer: peer))

// Start all transports
try await coordinator.startAll()

// Discover from ALL transports at once
for try await discovered in coordinator.discover(capability: capID) {
    // Don't know if this came from mDNS, BLE, or Internet
    print("Found: \(discovered.peerID)")
}

// Invoke - coordinator picks the best available transport
let result = try await coordinator.invoke(capability, on: peerID, arguments: data)
```

### PeerID (Self-Declared Identity)
Like mDNS hostnames, PeerIDs are self-declared string names:
```swift
let peerID = PeerID("my-robot")
// peerID.name == "my-robot"
// peerID.localName == "my-robot.local"
```

### Capability
Functionality offered by peers with semantic versioning:
```swift
let cap = try CapabilityID(parsing: "robot.mobility.move.1.0.0")
// namespace: "robot.mobility", name: "move", version: 1.0.0
```

### Message (Unsigned)
Simple binary protocol without cryptographic signatures:
```swift
let message = Message.create(
    type: .invoke,
    senderID: localPeer.peerID,
    recipientID: targetID,
    sequenceNumber: 1,
    payload: data
)
```

## Source Files

### DiscoveryCore
| File | Description |
|------|-------------|
| `PeerID.swift` | Self-declared string-based identity |
| `Capability.swift` | CapabilityID, SemanticVersion, CapabilitySet |
| `Message.swift` | MessageType, MessageHeader, Message |
| `MessagePayloads.swift` | Announce, Query, Invoke, Error payloads |
| `Transport.swift` | Transport protocol (transport abstraction) |
| `TransportCoordinator.swift` | Multi-transport coordinator |
| `ResolvedPeer.swift` | Transport-agnostic peer reference |
| `DiscoveredPeer.swift` | Transport-agnostic discovered peer |

### Transport Modules
| Module | Discovery | Communication | Scope |
|--------|-----------|---------------|-------|
| LocalNetworkTransport | mDNS/DNS-SD | TCP | LAN |
| NearbyTransport | BLE Advertising | GATT | ~100m |
| RemoteNetworkTransport | HTTP/.well-known | WebSocket | Internet |

## Key Design Principles

1. **Transport Protocol**: Any communication method can be a Transport
2. **Multi-Transport Discovery**: All transports searched simultaneously
3. **Transport Agnostic**: Application never knows transport details
4. **Location Transparency**: Same API regardless of peer location
5. **Peer-to-Peer**: No central server, all peers equal
6. **Self-Declared Identity**: Like mDNS, no central authority
7. **Actor-Based Concurrency**: Swift actors for thread safety

## Testing

32 unit tests covering:
- PeerID (creation, sanitization, codable)
- Capability (parsing, versioning, compatibility)
- Message (creation, serialization, validation)
- LocalPeer (message creation, broadcasts)
- ResolvedPeer/DiscoveredPeer (transport-agnostic)
- Payload encoding/decoding

## mDNS vs Discovery

| Aspect | mDNS | Discovery |
|--------|------|-----------|
| Scope | Same network only | ALL available transports |
| Identity | Hostname (self-declared) | PeerID (self-declared) |
| Discovery | Service types | Capabilities |
| Transport | Specific (multicast) | Any (Transport protocol) |
