# Symbiosis Quorum Protocol

## Technical Specification v2.0

---

# Document Information

| Property | Value |
|----------|-------|
| Title | Symbiosis Quorum Protocol Technical Specification |
| Version | 2.0 |
| Status | Draft |
| Date | 2024-12 |

## Conformance Language

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in RFC 2119.

---

# 1. Overview

## 1.1 Scope

本仕様書は、Symbiosis Quorum Protocol（SQP）v2.0の技術的詳細を定義する。

v2.0の主な変更点：
- `QuorumSystem` → `Transport` プロトコルにリネーム
- `QuorumSystemManager` → `Quorum` にリネーム
- Trust Layerの削除
- 暗号的Identityの削除（自己申告型に変更）
- Transport詳細の完全な抽象化

## 1.2 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Application                            │
│                   (User's Agent Logic)                      │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      SQP Core API                           │
│                                                             │
│  Agent, AgentID, Capability, Message, Quorum                │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   Transport Protocol                        │
│                                                             │
│  resolve(), discover(), invoke()                            │
│  (Transport details are HIDDEN from application)           │
└─────────────────────────────────────────────────────────────┘
                            │
            ┌───────────────┼───────────────┐
            ▼               ▼               ▼
     ┌───────────┐   ┌───────────┐   ┌───────────┐
     │   MDNS    │   │    BLE    │   │  Internet │
     │ Transport │   │ Transport │   │ Transport │
     └───────────┘   └───────────┘   └───────────┘
```

## 1.3 Key Design Principles

1. **Transport Protocol**: Any communication method can conform to Transport
2. **Multi-Transport Discovery**: All transports searched simultaneously
3. **Transport Agnostic**: Application MUST NOT know transport details
4. **Self-Declared Identity**: Like mDNS hostnames

---

# 2. Data Types

## 2.1 Primitive Types

### 2.1.1 Byte Sequences

```
Bytes: Variable-length byte array
  - Representation: [UInt8]
  - Length: 0 or more

FixedBytes<N>: Fixed-length byte array
  - Representation: N UInt8 values
  - Length: Exactly N bytes
```

### 2.1.2 Strings

```
String: UTF-8 encoded string
  - Encoding: UTF-8
  - Max length: Implementation-dependent (recommended: 65535 bytes)
```

### 2.1.3 Integers

```
UInt8:  8-bit unsigned integer (0 to 255)
UInt16: 16-bit unsigned integer (0 to 65535)
UInt32: 32-bit unsigned integer (0 to 4294967295)
UInt64: 64-bit unsigned integer

Byte order: Big-endian (network byte order)
```

### 2.1.4 Timestamp

```
Timestamp: Unix timestamp in milliseconds
  - Type: UInt64
  - Base: Milliseconds since 1970-01-01T00:00:00Z
```

---

# 3. AgentID

## 3.1 Definition

```swift
struct AgentID {
    let name: String  // Self-declared name (like mDNS hostname)
}
```

## 3.2 Format Rules

```
AgentID name format:
  - Lowercase alphanumeric and hyphens only: [a-z0-9\-]
  - Maximum length: 63 characters (DNS compatible)
  - MUST NOT start or end with hyphen
  - MUST NOT be empty (except for broadcast)

Valid examples:
  my-robot
  kitchen-helper-1
  sensor42

Invalid examples:
  My-Robot      (uppercase)
  my robot      (space)
  -robot        (starts with hyphen)
```

## 3.3 Special Values

```
Broadcast: AgentID with empty name
  - Used for broadcast messages
  - AgentID("") or AgentID.broadcast
```

## 3.4 Local Name

```
localName = name + ".local"

Example:
  AgentID("my-robot").localName == "my-robot.local"
```

---

# 4. Capability

## 4.1 CapabilityID Format

```
CapabilityID = namespace.name.major.minor.patch

namespace:
  - One or more segments separated by "."
  - Each segment: [a-z][a-z0-9]*

name:
  - [a-z][a-z0-9]*

version:
  - Semantic versioning: major.minor.patch
  - Each component: non-negative integer

Examples:
  robot.mobility.move.1.0.0
  cooking.prepare.2.1.0
  sensor.temperature.read.1.0.0
```

## 4.2 Capability Structure

```swift
struct Capability {
    let id: CapabilityID
    let description: String
    let metadata: [String: String]
}
```

## 4.3 Version Compatibility

```
Compatible if:
  - Same namespace
  - Same name
  - Same major version
  - Provider minor >= Required minor

Example:
  Required: 1.2.0
  Compatible: 1.2.0, 1.3.0, 1.5.2
  Incompatible: 1.1.0, 2.0.0
```

---

# 5. Message Format

## 5.1 Message Structure

```swift
struct Message {
    let header: MessageHeader
    let payload: Data
}
```

## 5.2 MessageHeader (Variable Length)

```
MessageHeader:
  version:        UInt8       // Protocol version (0x02)
  type:           UInt8       // Message type
  flags:          UInt16      // Flags (big-endian)
  sequenceNumber: UInt32      // Sequence number (big-endian)
  timestamp:      UInt64      // Timestamp (big-endian)
  payloadLength:  UInt32      // Payload length (big-endian)
  senderIDLength: UInt8       // Sender ID name length
  senderID:       String      // Sender ID name (UTF-8)
  recipientIDLength: UInt8    // Recipient ID name length
  recipientID:    String      // Recipient ID name (UTF-8)
```

## 5.3 Binary Layout

```
Offset  Size     Field
──────────────────────────────────────
0       1        version (0x02)
1       1        type
2       2        flags (big-endian)
4       4        sequenceNumber (big-endian)
8       8        timestamp (big-endian)
16      4        payloadLength (big-endian)
20      1        senderIDLength
21      S        senderID (S = senderIDLength)
21+S    1        recipientIDLength
22+S    R        recipientID (R = recipientIDLength)
22+S+R  N        payload (N = payloadLength)
──────────────────────────────────────
Total: 22 + S + R + N bytes

Fixed header size: 20 bytes
Variable part: 2 + S + R bytes (length prefixes + names)
```

## 5.4 Message Types

```swift
enum MessageType: UInt8 {
    // Discovery
    case announce       = 0x01  // Presence announcement
    case query          = 0x02  // Agent search
    case queryResponse  = 0x03  // Search response

    // Communication
    case invoke         = 0x10  // Capability invocation
    case invokeResponse = 0x11  // Invocation response
    case notify         = 0x12  // Notification

    // Control
    case ping           = 0x30  // Health check
    case pong           = 0x31  // Health response
    case error          = 0x3F  // Error
}
```

## 5.5 Message Flags

```swift
struct MessageFlags: OptionSet {
    static let broadcast    = MessageFlags(rawValue: 0x0001)
    static let requiresAck  = MessageFlags(rawValue: 0x0002)
    static let compressed   = MessageFlags(rawValue: 0x0004)
    static let encrypted    = MessageFlags(rawValue: 0x0008)
    static let priority     = MessageFlags(rawValue: 0x0010)
}
```

---

# 6. Transport Protocol

## 6.1 Overview

Transportは、通信手段を抽象化するプロトコルである。任意の通信手段がこのプロトコルに準拠することで、SQPに統合できる。

```swift
protocol Transport: Sendable {
    /// Unique identifier for this transport
    var transportID: String { get }

    /// Display name for this transport
    var displayName: String { get }

    /// Whether the transport is currently active
    var isActive: Bool { get async }

    // MARK: - Lifecycle

    /// Start the transport
    func start() async throws

    /// Stop the transport
    func stop() async throws

    // MARK: - Resolution

    /// Resolve an agent by ID
    func resolve(_ agentID: AgentID) async throws -> ResolvedAgent?

    // MARK: - Discovery

    /// Discover agents with a specific capability
    func discover(capability: CapabilityID, timeout: Duration)
        -> AsyncThrowingStream<DiscoveredAgent, Error>

    /// Discover all nearby agents
    func discoverAll(timeout: Duration)
        -> AsyncThrowingStream<DiscoveredAgent, Error>

    // MARK: - Invocation

    /// Invoke a capability on a remote agent
    func invoke(
        _ capability: CapabilityID,
        on agentID: AgentID,
        arguments: Data,
        timeout: Duration
    ) async throws -> InvocationResult

    // MARK: - Events

    /// Stream of transport events
    var events: AsyncStream<TransportEvent> { get async }
}
```

## 6.2 ResolvedAgent (Transport-Agnostic)

```swift
struct ResolvedAgent {
    let agentID: AgentID
    let capabilities: [CapabilityID]
    let metadata: [String: String]
    let resolvedAt: Date
    let ttl: Duration

    var isValid: Bool { /* TTL check */ }

    // NOTE: No endpoint field - transport details are hidden
}
```

## 6.3 DiscoveredAgent (Transport-Agnostic)

```swift
struct DiscoveredAgent {
    let agentID: AgentID
    let capability: CapabilityID
    let quality: Double  // 0.0 to 1.0
    let discoveredAt: Date
    let metadata: [String: String]

    // NOTE: No transportID field - transport details are hidden
}
```

## 6.4 InvocationResult

```swift
enum InvocationResult {
    case success(data: Data, roundTripTime: Duration, sourceAgentID: AgentID)
    case failure(error: InvocationError, roundTripTime: Duration, sourceAgentID: AgentID)
}
```

## 6.5 TransportEvent

```swift
enum TransportEvent: Sendable {
    case started
    case stopped
    case agentDiscovered(DiscoveredAgent)
    case agentLost(AgentID)
    case messageReceived(Message, from: AgentID)
    case messageSent(Message, to: AgentID)
    case error(TransportError)
}
```

## 6.6 TransportError

```swift
enum TransportError: Error, Sendable {
    case notStarted
    case alreadyStarted
    case connectionFailed(String)
    case resolutionFailed(AgentID)
    case invocationFailed(InvocationError)
    case timeout
}
```

---

# 7. Quorum

## 7.1 Overview

Quorumは、複数のTransportを統合し、全Transportで同時に発見・通信を行う。

```swift
actor Quorum {
    let localAgent: LocalAgent

    func register(_ transport: any Transport)
    func unregister(_ transportID: String)

    func startAll() async throws
    func stopAll() async throws

    // Unified discovery across ALL transports
    func discover(capability: CapabilityID, timeout: Duration)
        -> AsyncThrowingStream<DiscoveredAgent, Error>

    // Resolution across ALL transports
    func resolve(_ agentID: AgentID) async throws -> ResolvedAgent?

    // Invocation using best available transport
    func invoke(
        _ capability: CapabilityID,
        on agentID: AgentID,
        arguments: Data,
        timeout: Duration
    ) async throws -> InvocationResult
}
```

## 7.2 Discovery Aggregation

```
Application calls:
  quorum.discover(capability: "cooking.prepare.1.0.0")

Quorum internally:
  ├── MDNSTransport.discover() → streams results
  ├── BLETransport.discover() → streams results
  └── InternetTransport.discover() → streams results
      │
      └── All results merged into single stream
          │
          └── Application receives unified stream
```

## 7.3 Resolution Strategy

```
1. Try each registered transport in order
2. Return first successful resolution
3. Return nil if all transports fail
```

## 7.4 Invocation Strategy

```
1. Check if agent has requested capability
2. Find an active transport
3. Try invocation
4. If failed, try next transport
5. Return result or error
```

---

# 8. Payload Formats

## 8.1 AnnouncePayload

```swift
struct AnnouncePayload: Codable {
    let agentID: AgentID
    let capabilities: [CapabilityID]
    let displayName: String?
    let metadata: [String: String]
}
```

## 8.2 QueryPayload

```swift
struct QueryPayload: Codable {
    let capability: CapabilityID
    let filter: [String: String]?
}
```

## 8.3 InvokePayload

```swift
struct InvokePayload: Codable {
    let capability: CapabilityID
    let invocationID: String
    let arguments: Data
}
```

## 8.4 InvokeResponsePayload

```swift
struct InvokeResponsePayload: Codable {
    let invocationID: String
    let success: Bool
    let result: Data?
    let errorCode: UInt32?
    let errorMessage: String?
}
```

## 8.5 ErrorPayload

```swift
struct ErrorPayload: Codable {
    let code: UInt32
    let message: String
    let details: [String: String]?
}
```

---

# 9. MDNSTransport Implementation

## 9.1 Overview

```
Discovery: mDNS/DNS-SD
Communication: TCP
Service Type: _sqp._tcp.local
```

## 9.2 Internal State

```swift
actor MDNSTransport: Transport {
    // Transport-agnostic cache (exposed via protocol)
    private var knownAgents: [AgentID: ResolvedAgent] = [:]

    // Transport-specific state (internal only, NOT exposed)
    private var agentEndpoints: [AgentID: String] = [:]
    private var connections: [AgentID: NWConnection] = [:]
}
```

## 9.3 TXT Record Format

```
id=<agent-name>
v=<protocol-version>
caps=<capability1> <capability2> ...
name=<display-name>
```

---

# 10. Error Handling

## 10.1 Error Codes

```swift
enum SQPErrorCode: UInt32 {
    case unknown = 0x0001
    case timeout = 0x0002
    case agentNotFound = 0x0100
    case capabilityNotFound = 0x0200
    case invalidParameters = 0x0201
    case invocationFailed = 0x0202
    case resourceUnavailable = 0x0203
    case connectionFailed = 0x0400
}
```

## 10.2 TransportError

```swift
enum TransportError: Error {
    case notStarted
    case alreadyStarted
    case connectionFailed(String)
    case resolutionFailed(AgentID)
    case invocationFailed(InvocationError)
    case timeout
}
```

---

# 11. Naming Changes from v1.0

| v1.0 | v2.0 | Description |
|------|------|-------------|
| `QuorumSystem` | `Transport` | Protocol for communication methods |
| `QuorumSystemManager` | `Quorum` | Multi-transport coordinator |
| `QuorumSystemEvent` | `TransportEvent` | Events from transport |
| `QuorumSystemError` | `TransportError` | Transport errors |
| `LocalMDNSSystem` | `MDNSTransport` | mDNS implementation |
| `systemID` | `transportID` | Transport identifier |

---

# Appendix

## A. Well-Known Ports

```
Port     Protocol    Usage
─────────────────────────────────
8420     TCP         SQP default
```

## B. Service Registration

```
Service Type: _sqp._tcp
Domain: local
```

## C. Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2024-12 | Initial (QuorumSystem naming) |
| 2.0 | 2024-12 | Renamed to Transport protocol |

---

*End of Technical Specification*
