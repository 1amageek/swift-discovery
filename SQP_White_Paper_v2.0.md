# Symbiosis Quorum Protocol

## White Paper v2.0

---

# Abstract

Symbiosis Quorum Protocol（SQP）は、物理世界で独立動作するエージェント（ロボット、デバイス、AI）が**利用可能な全てのTransportを同時に使って**互いを発見し、協調するためのプロトコルである。

mDNSは同一ネットワーク内のデバイスのみを発見する。SQPはmDNS、BLE、インターネットなど**全ての利用可能なTransportで同時に**エージェントを発見する。アプリケーションは「どのTransportで見つけたか」を知る必要がない。

**Symbiosis**は、人間とロボットが共生する世界というビジョンを表す。**Quorum**は、複数のTransportが協調して動作することを表す - 単一のTransportではなく、利用可能な全てのTransportが協力してエージェントを発見する。

---

# 1. Introduction

## 1.1 Background

mDNS（Multicast DNS）は、同一ローカルネットワーク内でデバイスを発見するための優れたプロトコルである。しかし、以下の制限がある：

- **同一ネットワーク限定**: 異なるネットワーク上のデバイスは発見できない
- **単一Transport**: マルチキャストUDPのみ
- **デバイス中心**: エージェントの「能力」ではなく「サービス」で発見

## 1.2 The Problem

将来、数十億のロボットとAIエージェントが物理世界で動作する。これらは：

- ローカルネットワーク上にいるかもしれない（mDNS）
- Bluetoothの範囲内にいるかもしれない（BLE）
- インターネット上にいるかもしれない（HTTP/WebSocket）
- 複数の手段で同時に到達可能かもしれない

アプリケーションが「どのTransportを使うか」を意識する必要があるのは設計として不適切である。

## 1.3 The Solution: SQP

SQPは、mDNSの哲学を拡張し、**全ての利用可能なTransportで同時に**エージェントを発見する。

```
mDNS: 同一ネットワーク内のみ

SQP:  全てのTransportを同時に使用
      ├── MDNSTransport (ローカルネットワーク)
      ├── BLETransport (近距離)
      └── InternetTransport (グローバル)
```

アプリケーションは `discover(capability:)` を呼ぶだけで、どこにいるエージェントでも見つけられる。

---

# 2. Core Philosophy

## 2.1 Transport Protocol

SQPの核心：**Transportプロトコルに準拠した通信手段なら何でもセットできる**。

```swift
protocol Transport {
    var transportID: String { get }
    func start() async throws
    func stop() async throws
    func resolve(_ agentID: AgentID) async throws -> ResolvedAgent?
    func discover(capability: CapabilityID, timeout: Duration)
        -> AsyncThrowingStream<DiscoveredAgent, Error>
    func invoke(_ capability: CapabilityID, on agentID: AgentID,
                arguments: Data, timeout: Duration) async throws -> InvocationResult
}
```

新しい通信手段（例：衛星通信、メッシュネットワーク）が登場しても、Transportプロトコルに準拠すればSQPに統合できる。

## 2.2 Transport Agnostic（Transport非依存）

SQPの最も重要な原則：**アプリケーションはTransportを知らない**。

```
┌─────────────────────────────────────────────────────────┐
│                   Application                            │
│                                                          │
│   // アプリケーションはこれだけ知っている                    │
│   discover(capability:) → [Agent]                        │
│   resolve(agentID:) → Agent?                             │
│   invoke(capability:on:arguments:) → Result              │
│                                                          │
│   // アプリケーションはこれを知らない                        │
│   // - どのTransportで見つけたか                           │
│   // - どうやって接続するか                                 │
│   // - エンドポイントのアドレス                              │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                      Quorum                              │
│           (全Transportを同時に使用)                       │
└─────────────────────────────────────────────────────────┘
        │               │               │
        ▼               ▼               ▼
   ┌──────────┐    ┌──────────┐    ┌──────────┐
   │  MDNS    │    │   BLE    │    │ Internet │
   │Transport │    │Transport │    │Transport │
   └──────────┘    └──────────┘    └──────────┘
```

## 2.3 Self-Declared Identity（自己申告型Identity）

mDNSのホスト名と同様に、エージェントは自分の名前を自己申告する。

```swift
let agentID = AgentID("my-robot")
// 中央機関による発行は不要
// 暗号的証明も不要
// mDNSホスト名と同じ考え方
```

名前の衝突は、mDNSと同様にローカルで解決される。

## 2.4 Capability-Based Discovery（能力ベースの発見）

mDNSがサービスタイプで発見するように、SQPは**能力（Capability）**で発見する。

```swift
// 「調理できるエージェント」を探す
for try await agent in quorum.discover(capability: "cooking.prepare.1.0.0") {
    print("Found: \(agent.agentID)")
}
```

## 2.5 Peer-to-Peer（対等性）

中央サーバーなし。全エージェントが対等なピア。

```
Robot A ←──→ Robot B ←──→ Robot C
    ↑                        ↑
    └────────────────────────┘

どちらからも発見・通信を開始できる
```

---

# 3. Architecture

## 3.1 Layer Structure

```
┌─────────────────────────────────────────────────────────┐
│                      Application                         │
│                   (User's Agent Logic)                   │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                      SQP Core API                        │
│                                                          │
│   Agent, AgentID, Capability, Message                    │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                        Quorum                            │
│                                                          │
│   resolve(), discover(), invoke()                        │
│   (全Transportを統合)                                     │
└─────────────────────────────────────────────────────────┘
                           │
           ┌───────────────┼───────────────┐
           ▼               ▼               ▼
    ┌───────────┐   ┌───────────┐   ┌───────────┐
    │   MDNS    │   │    BLE    │   │  Internet │
    │ Transport │   │ Transport │   │ Transport │
    └───────────┘   └───────────┘   └───────────┘
```

## 3.2 Quorum

全てのTransportを統合する中心的なコンポーネント：

```swift
let quorum = Quorum(localAgent: agent)

// 利用可能なTransportを登録
await quorum.register(MDNSTransport(localAgent: agent))
await quorum.register(BLETransport(localAgent: agent))
await quorum.register(InternetTransport(localAgent: agent))

// 全Transportを開始
try await quorum.startAll()

// 発見 - 全Transportから同時に結果が来る
for try await discovered in quorum.discover(capability: capID) {
    // mDNS、BLE、Internetのどれで見つけたか知らない
    print("Found: \(discovered.agentID)")
}
```

## 3.3 ResolvedAgent / DiscoveredAgent

Transport詳細を隠蔽した構造体：

```swift
// アプリケーションが見るもの
struct ResolvedAgent {
    let agentID: AgentID           // 誰か
    let capabilities: [CapabilityID] // 何ができるか
    let metadata: [String: String]   // 追加情報
    let ttl: Duration                // 有効期間

    // endpoint は含まれない - 抽象化されている
}

struct DiscoveredAgent {
    let agentID: AgentID           // 誰か
    let capability: CapabilityID   // マッチした能力
    let quality: Double            // 品質指標 (0.0-1.0)
    let metadata: [String: String] // 追加情報

    // transportID は含まれない - 抽象化されている
}
```

---

# 4. Fundamental Concepts

## 4.1 AgentID

mDNSホスト名と同様の自己申告型識別子。

```swift
struct AgentID {
    let name: String  // 例: "my-robot"

    var localName: String { "\(name).local" }

    static let broadcast = AgentID("")  // ブロードキャスト用
}
```

特徴：
- 自己申告（中央機関不要）
- 小文字英数字とハイフンのみ
- 最大63文字（DNS互換）
- 衝突はローカルで解決

## 4.2 Capability

エージェントが提供できる機能。

```
CapabilityID = namespace.name.version

例:
  robot.mobility.move.1.0.0
  cooking.prepare.2.1.0
  sensor.temperature.read.1.0.0
```

セマンティックバージョニングで互換性を管理。

## 4.3 Transport Protocol

各通信手段が実装するプロトコル：

```swift
protocol Transport {
    var transportID: String { get }
    var displayName: String { get }
    var isActive: Bool { get async }

    func start() async throws
    func stop() async throws

    func resolve(_ agentID: AgentID) async throws -> ResolvedAgent?
    func discover(capability: CapabilityID, timeout: Duration)
        -> AsyncThrowingStream<DiscoveredAgent, Error>
    func invoke(_ capability: CapabilityID, on agentID: AgentID,
                arguments: Data, timeout: Duration) async throws -> InvocationResult
}
```

---

# 5. Transport Implementations

## 5.1 MDNSTransport

ローカルネットワーク上のエージェント発見。

```
Discovery: mDNS/DNS-SD (_sqp._tcp.local)
Communication: TCP
Scope: Same network
```

## 5.2 BLETransport (Planned)

Bluetooth範囲内のエージェント発見。

```
Discovery: BLE Advertising
Communication: GATT
Scope: ~100m
```

## 5.3 InternetTransport (Planned)

インターネット上のエージェント発見。

```
Discovery: /.well-known/agent.json
Communication: HTTP/WebSocket
Scope: Global
```

## 5.4 Custom Transports

Transportプロトコルに準拠すれば、任意の通信手段を追加できる：

```swift
// 例: 衛星通信
class SatelliteTransport: Transport {
    var transportID: String { "sqp.satellite" }
    // ... 実装
}

// 例: LoRaメッシュ
class LoRaTransport: Transport {
    var transportID: String { "sqp.lora" }
    // ... 実装
}

// Quorumに登録
await quorum.register(SatelliteTransport())
await quorum.register(LoRaTransport())
```

---

# 6. Comparison with mDNS

| Aspect | mDNS | SQP |
|--------|------|-----|
| Scope | Same network only | ALL available Transports |
| Identity | Hostname (self-declared) | AgentID (self-declared) |
| Discovery method | Service types | Capabilities |
| Transport | Multicast UDP | Any (Transport protocol) |
| Extensibility | Fixed | Any Transport can be added |
| Application awareness | Knows IP/port | Knows nothing about transport |

SQPは「mDNSのような自己申告型発見」を「任意のTransport」に拡張したもの。

---

# 7. Use Cases

## 7.1 Smart Home

```swift
// キッチンロボットが調理支援ロボットを探す
for try await helper in quorum.discover(capability: "cooking.assist.1.0.0") {
    // 同じWiFi上かもしれない (MDNS)
    // Bluetoothで繋がっているかもしれない (BLE)
    // クラウドサービスかもしれない (Internet)
    // → アプリケーションは気にしない

    try await quorum.invoke("cooking.assist.1.0.0", on: helper.agentID, arguments: recipe)
}
```

## 7.2 Industrial Robotics

```swift
// 工場内のロボットが協調作業
let carriers = quorum.discover(capability: "transport.carry.1.0.0")
let assemblers = quorum.discover(capability: "assembly.weld.1.0.0")

// 同じLAN上のロボット、BLE接続のロボット、
// クラウド経由の遠隔ロボット - 全て同じAPIで扱える
```

## 7.3 Disaster Response

```swift
// 緊急時：利用可能な全ての通信手段を使用
await quorum.register(MDNSTransport(localAgent: agent))  // WiFi
await quorum.register(BLETransport(localAgent: agent))   // Bluetooth
await quorum.register(LoRaTransport(localAgent: agent))  // 長距離メッシュ
await quorum.register(SatelliteTransport(localAgent: agent)) // 衛星

// どれかが生きていればエージェントを発見できる
for try await rescuer in quorum.discover(capability: "rescue.search.1.0.0") {
    // ...
}
```

---

# 8. Conclusion

SQP (Symbiosis Quorum Protocol) は、mDNSの哲学を全てのTransportに拡張したプロトコルである。

**核心概念：**

1. **Transport Protocol**: 任意の通信手段をTransportとして追加可能
2. **Quorum**: 全Transportを統合し、同時に発見・通信
3. **Transport Agnostic**: アプリケーションは接続方法を知らない
4. **自己申告型Identity**: mDNSホスト名と同様、中央機関不要
5. **能力ベース発見**: サービスではなく「何ができるか」で発見
6. **対等なピア**: 中央サーバーなし

```
mDNS: 同一ネットワーク内でデバイスを発見

SQP:  Transportプロトコルに準拠した
      任意の通信手段で
      エージェントを同時に発見
```

これが「Quorum」の意味 - 複数のTransportが協調して動作する。

---

# Appendix

## A. Terminology

| Term | Definition |
|------|------------|
| Agent | SQPにおける基本エンティティ |
| AgentID | 自己申告型の文字列識別子 |
| Transport | 通信手段を抽象化したプロトコル |
| Quorum | 複数のTransportを統合する層 |
| Capability | エージェントが提供できる機能 |

## B. Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2024-12 | Initial release (with Trust layer) |
| 2.0 | 2024-12 | Simplified: Transport protocol, self-declared identity |

---

*End of White Paper*
