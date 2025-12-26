# Symbiosis Quorum Protocol

## Technical Specification v1.0

---

# Document Information

| Property | Value |
|----------|-------|
| Title | Symbiosis Quorum Protocol Technical Specification |
| Version | 1.0 |
| Status | Draft |
| Date | 2024-12 |

## Conformance Language

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in RFC 2119.

---

# Table of Contents

1. [Overview](#1-overview)
2. [Data Types](#2-data-types)
3. [Identity](#3-identity)
4. [Capability](#4-capability)
5. [Trust Model](#5-trust-model)
6. [QuorumSystem Protocol](#6-quorumsystem-protocol)
7. [Message Format](#7-message-format)
8. [Discovery](#8-discovery)
9. [Communication](#9-communication)
10. [Security](#10-security)
11. [Error Handling](#11-error-handling)
12. [QuorumSystem Implementations](#12-quorumsystem-implementations)
13. [Interoperability](#13-interoperability)

---

# 1. Overview

## 1.1 Scope

本仕様書は、Symbiosis Quorum Protocol（SQP）のLevel 0（Protocol-Based Recognition）における技術的詳細を定義する。

本仕様書の範囲：
- データ型定義
- プロトコル仕様
- メッセージフォーマット
- セキュリティ要件
- QuorumSystem実装要件

本仕様書の範囲外：
- Level 1以上の認識方式（視覚、聴覚等）
- 特定の実装の詳細
- アプリケーションレベルのロジック

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
│  Agent, Identity, Capability, Trust, QuorumSystem           │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  QuorumSystem Protocol                      │
│                                                             │
│  resolve(), discover(), invoke(), trustLevel()              │
└─────────────────────────────────────────────────────────────┘
                            │
            ┌───────────────┼───────────────┐
            ▼               ▼               ▼
     ┌───────────┐   ┌───────────┐   ┌───────────┐
     │ LocalMDNS │   │    BLE    │   │ A2ABridge │
     │  System   │   │  System   │   │  System   │
     └───────────┘   └───────────┘   └───────────┘
            │               │               │
            ▼               ▼               ▼
     ┌───────────┐   ┌───────────┐   ┌───────────┐
     │  mDNS/TCP │   │BLE/GATT   │   │HTTP/JSON  │
     └───────────┘   └───────────┘   └───────────┘
```

## 1.3 Terminology

| Term | Definition |
|------|------------|
| Agent | SQPにおける基本エンティティ |
| Agent ID | 32バイトの暗号学的識別子 |
| QuorumSystem | 認識と通信を実現する抽象インターフェース |
| Alias | Agent IDに対する人間可読な別名 |
| Capability | Agentが提供する機能 |
| Invoke | Capabilityの呼び出し |
| Trust | 信頼度（0.0〜1.0の浮動小数点数） |
| Trust Anchor | Trustの起点 |

---

# 2. Data Types

## 2.1 Primitive Types

### 2.1.1 Byte Sequences

```
Bytes: 可変長バイト列
  - 表現: [UInt8] または同等のバイト配列
  - 長さ: 0以上

FixedBytes<N>: 固定長バイト列
  - 表現: N個のUInt8
  - 長さ: 正確にNバイト
```

### 2.1.2 Strings

```
String: UTF-8エンコードされた文字列
  - エンコーディング: UTF-8
  - 最大長: 実装依存（推奨: 65535バイト）
```

### 2.1.3 Integers

```
UInt8:  8ビット符号なし整数 (0 to 255)
UInt16: 16ビット符号なし整数 (0 to 65535)
UInt32: 32ビット符号なし整数 (0 to 4294967295)
UInt64: 64ビット符号なし整数 (0 to 18446744073709551615)
Int64:  64ビット符号付き整数

バイトオーダー: ビッグエンディアン（ネットワークバイトオーダー）
```

### 2.1.4 Floating Point

```
Float32: IEEE 754 単精度浮動小数点数
Float64: IEEE 754 倍精度浮動小数点数
```

### 2.1.5 Timestamp

```
Timestamp: ミリ秒単位のUnixタイムスタンプ
  - 型: UInt64
  - 基準: 1970-01-01T00:00:00Z からのミリ秒
```

## 2.2 Cryptographic Types

### 2.2.1 PublicKey

```
PublicKey: Ed25519公開鍵
  - サイズ: 32バイト
  - フォーマット: Ed25519生バイト

構造:
┌────────────────────────────────────┐
│            32 bytes                │
│      Ed25519 Public Key            │
└────────────────────────────────────┘
```

### 2.2.2 PrivateKey

```
PrivateKey: Ed25519秘密鍵
  - サイズ: 32バイト（シード）または64バイト（拡張）
  - フォーマット: Ed25519生バイト

注意: 秘密鍵は安全に保管しなければならない（MUST）
```

### 2.2.3 Signature

```
Signature: Ed25519署名
  - サイズ: 64バイト
  - フォーマット: Ed25519署名

構造:
┌────────────────────────────────────┐
│            64 bytes                │
│        Ed25519 Signature           │
└────────────────────────────────────┘
```

### 2.2.4 Hash

```
Hash: SHA-256ハッシュ
  - サイズ: 32バイト
  - アルゴリズム: SHA-256

構造:
┌────────────────────────────────────┐
│            32 bytes                │
│          SHA-256 Hash              │
└────────────────────────────────────┘
```

## 2.3 Identifier Types

### 2.3.1 Agent ID

```
Agent ID: Agentの一意識別子
  - サイズ: 32バイト
  - 算出: SHA-256(PublicKey)

構造:
┌────────────────────────────────────┐
│            32 bytes                │
│    SHA-256(Ed25519 PublicKey)      │
└────────────────────────────────────┘

文字列表現:
  Full URI:  "sqp:agent/" + Base58(Agent ID)
  Short:     Base58(Agent ID)[0:8]
  
例:
  Full:  sqp:agent/3FZbkVd8nP2xQrT9mKjL5wYhE7cR4vN1aB6sD
  Short: 3FZbkVd8
```

### 2.3.2 MessageID

```
MessageID: メッセージの一意識別子
  - サイズ: 16バイト
  - 生成: 暗号学的乱数

構造:
┌────────────────────────────────────┐
│            16 bytes                │
│      Random (CSPRNG)               │
└────────────────────────────────────┘
```

### 2.3.3 CapabilityID

```
CapabilityID: Capabilityの識別子
  - フォーマット: namespace.name.version
  - 各要素: [a-z0-9\-]+ (小文字英数字とハイフン)
  - version: "v" + 数字

例:
  cooking.prepare.v1
  transport.carry.v2
  system.status.v1
```

---

# 3. Identity

## 3.1 KeyPair

### 3.1.1 Definition

```
KeyPair:
  publicKey:  PublicKey   // 32 bytes
  privateKey: PrivateKey  // 32 bytes (seed)
```

### 3.1.2 Generation

KeyPairの生成：

```
1. CSPRNGを使用して32バイトのシードを生成
2. シードからEd25519キーペアを導出
3. publicKey = Ed25519公開鍵 (32 bytes)
4. privateKey = シード (32 bytes)

要件:
- 乱数生成器は暗号学的に安全でなければならない（MUST）
- ハードウェアRNGの使用を推奨（RECOMMENDED）
```

### 3.1.3 Signing

```
sign(message: Bytes, privateKey: PrivateKey) → Signature

アルゴリズム: Ed25519
入力: 任意長のメッセージ
出力: 64バイトの署名
```

### 3.1.4 Verification

```
verify(message: Bytes, signature: Signature, publicKey: PublicKey) → Bool

アルゴリズム: Ed25519
戻り値: 署名が有効な場合true、それ以外false
```

## 3.2 AgentIdentity

### 3.2.1 Definition

```
AgentIdentity:
  id:           Agent ID          // 32 bytes
  keyPair:      KeyPair           // 公開鍵・秘密鍵ペア
  aliases:      [AliasRecord]     // エイリアスのリスト
  capabilities: [CapabilityID]    // 提供可能な機能
  metadata:     Map<String, Bytes> // 追加メタデータ
```

### 3.2.2 Agent ID Derivation

```
agentID = SHA-256(keyPair.publicKey)

手順:
1. Ed25519公開鍵を取得（32バイト）
2. SHA-256ハッシュを計算
3. 結果の32バイトがAgent ID
```

## 3.3 Alias

### 3.3.1 Definition

```
AliasRecord:
  name:      String      // エイリアス名（例: "@chef"）
  scope:     AliasScope  // スコープ
  agentId:   Agent ID    // 対象Agent ID
  createdAt: Timestamp   // 作成日時
  expiresAt: Timestamp?  // 有効期限（オプション）
  signature: Signature   // 署名
```

### 3.3.2 AliasScope

```
AliasScope: enum
  GLOBAL    = 0x01  // グローバルに有効
  LOCAL     = 0x02  // ローカルネットワーク内で有効
  PRIVATE   = 0x03  // 特定Agentのみが認識
```

### 3.3.3 Alias Format

```
エイリアス名のフォーマット:
  - "@"で始まる（MUST）
  - 最小長: 2文字（"@"を含む）
  - 最大長: 64文字
  - 許可文字: Unicode Letter, Number, "-", "_"
  
有効な例:
  @chef
  @シェフ
  @kitchen-robot-1
  @ユニット_47

無効な例:
  chef        // "@"がない
  @           // 名前がない
  @a b        // スペースを含む
```

### 3.3.4 Alias Signature

```
署名対象データ:
  signatureData = concat(
    name.utf8Bytes,
    scope.rawValue,
    agentId,
    createdAt.bigEndianBytes,
    expiresAt?.bigEndianBytes ?? []
  )

署名:
  signature = sign(signatureData, privateKey)

検証:
  対応する公開鍵で署名を検証
```

---

# 4. Capability

## 4.1 Definition

```
Capability:
  id:          CapabilityID       // 機能ID
  name:        String             // 人間可読な名前
  description: String             // 説明
  version:     String             // バージョン
  parameters:  ParameterSchema    // 入力パラメータスキーマ
  returns:     ReturnSchema       // 戻り値スキーマ
  requiredTrust: Float32          // 必要なTrust
  metadata:    Map<String, Bytes> // 追加メタデータ
```

## 4.2 CapabilityID Format

```
CapabilityID = namespace "." name "." version

namespace:
  - 1つ以上のセグメント
  - セグメント間は"."で区切る
  - 各セグメント: [a-z][a-z0-9\-]*
  
name:
  - [a-z][a-z0-9\-]*
  
version:
  - "v" followed by digits
  - 例: v1, v2, v10

例:
  cooking.prepare.v1
  transport.heavy.carry.v2
  com.example.custom-skill.v1
```

## 4.3 Parameter Schema

```
ParameterSchema:
  parameters: [ParameterDefinition]

ParameterDefinition:
  name:        String           // パラメータ名
  type:        ParameterType    // 型
  required:    Bool             // 必須フラグ
  default:     Bytes?           // デフォルト値
  description: String           // 説明
  constraints: [Constraint]     // 制約

ParameterType: enum
  STRING    = 0x01
  INTEGER   = 0x02
  FLOAT     = 0x03
  BOOLEAN   = 0x04
  BYTES     = 0x05
  ARRAY     = 0x06
  OBJECT    = 0x07

Constraint:
  type:  ConstraintType
  value: Bytes

ConstraintType: enum
  MIN_LENGTH = 0x01
  MAX_LENGTH = 0x02
  MIN_VALUE  = 0x03
  MAX_VALUE  = 0x04
  PATTERN    = 0x05
  ENUM       = 0x06
```

## 4.4 Return Schema

```
ReturnSchema:
  type:       ParameterType
  properties: [PropertyDefinition]?  // OBJECTの場合
  itemType:   ParameterType?         // ARRAYの場合

PropertyDefinition:
  name: String
  type: ParameterType
  description: String
```

## 4.5 Capability Declaration Example

```yaml
capability:
  id: cooking.prepare.v1
  name: Prepare Dish
  description: Prepare a dish based on recipe
  version: v1
  requiredTrust: 0.5
  
  parameters:
    - name: recipe
      type: STRING
      required: true
      description: Recipe name or instructions
      
    - name: servings
      type: INTEGER
      required: false
      default: 2
      description: Number of servings
      constraints:
        - type: MIN_VALUE
          value: 1
        - type: MAX_VALUE
          value: 100
          
  returns:
    type: OBJECT
    properties:
      - name: status
        type: STRING
        description: Result status
      - name: estimatedTime
        type: INTEGER
        description: Estimated time in seconds
```

---

# 5. Trust Model

## 5.1 Trust Level

```
Trust: Float32
  - 範囲: 0.0 to 1.0
  - 0.0: 完全に信頼しない
  - 1.0: 完全に信頼する

TrustCategory:
  STRANGER    = trust < 0.3
  ACQUAINTANCE = 0.3 <= trust < 0.7
  TRUSTED     = 0.7 <= trust < 0.95
  OWNER       = trust >= 0.95
```

## 5.2 Trust Anchor

```
TrustAnchor: enum
  OWNER        = 0x01  // 所有者による設定
  MANUFACTURER = 0x02  // 製造者による保証
  ENCOUNTER    = 0x03  // 初対面
  REFERRAL     = 0x04  // 紹介
  REPUTATION   = 0x05  // 評判

初期Trust値:
  OWNER:        1.0
  MANUFACTURER: 0.7
  ENCOUNTER:    0.3
  REFERRAL:     referrer.trust * 0.8
  REPUTATION:   max(0.2, reputationScore)
```

## 5.3 TrustRecord

```
TrustRecord:
  agentId:           Agent ID     // 対象Agent
  anchor:            TrustAnchor  // Trustの起点
  initialTrust:      Float32      // 初期Trust値
  currentTrust:      Float32      // 現在のTrust値
  totalInteractions: UInt32       // 総インタラクション数
  successfulCount:   UInt32       // 成功回数
  failedCount:       UInt32       // 失敗回数
  lastInteraction:   Timestamp    // 最後のインタラクション
  lastUpdated:       Timestamp    // 最終更新日時
```

## 5.4 Trust Calculation

### 5.4.1 Initial Trust

```
initialTrust(anchor: TrustAnchor, referrer: Agent?) → Float32:
  switch anchor:
    case OWNER:        return 1.0
    case MANUFACTURER: return 0.7
    case ENCOUNTER:    return 0.3
    case REFERRAL:     return getTrust(referrer) * 0.8
    case REPUTATION:   return max(0.2, getReputation())
```

### 5.4.2 Trust Update

```
updateTrust(record: TrustRecord, success: Bool) → Float32:
  
  // パラメータ
  α = 0.1   // 学習率
  γ = 0.01  // 時間減衰係数
  
  // 時間減衰
  daysSinceLast = (now - record.lastInteraction) / (24 * 60 * 60 * 1000)
  decayedTrust = record.currentTrust * exp(-γ * daysSinceLast)
  
  // インタラクション更新
  if success:
    newTrust = decayedTrust + α * (1.0 - decayedTrust)
  else:
    newTrust = decayedTrust - α * decayedTrust
  
  // 範囲制限
  return clamp(newTrust, 0.0, 1.0)
```

### 5.4.3 Trust Decay

```
decayTrust(record: TrustRecord, now: Timestamp) → Float32:
  
  γ = 0.01  // 時間減衰係数
  
  daysSinceLast = (now - record.lastInteraction) / (24 * 60 * 60 * 1000)
  decayedTrust = record.currentTrust * exp(-γ * daysSinceLast)
  
  // 初期Trust値を下限とする
  return max(decayedTrust, record.initialTrust * 0.5)
```

## 5.5 Trust-Based Access Control

### 5.5.1 Access Decision

```
checkAccess(agent: Agent, capability: Capability) → AccessResult:
  
  trust = getTrust(agent)
  requiredTrust = capability.requiredTrust
  
  if trust >= requiredTrust:
    return AccessResult.ALLOWED
  else:
    return AccessResult.DENIED(
      required: requiredTrust,
      actual: trust
    )

AccessResult: enum
  ALLOWED
  DENIED(required: Float32, actual: Float32)
```

### 5.5.2 Trust Requirements

```
推奨Trust閾値:

Capability Type          Required Trust
─────────────────────────────────────────
情報取得                  0.1
基本操作                  0.3
通常操作                  0.5
重要操作                  0.7
危険操作                  0.9
システム操作              0.95
```

---

# 6. QuorumSystem Protocol

## 6.1 Overview

QuorumSystemは、Agentの発見、通信、Trust管理を抽象化するプロトコルである。

```
QuorumSystem (Protocol/Interface):
  
  // === Identity ===
  resolve(id: Agent ID) async throws → Agent
  resolve(alias: String) async throws → Agent
  
  // === Discovery ===
  discover(capability: CapabilityID) async → [Agent]
  discoverAll() async → [Agent]
  
  // === Communication ===
  invoke(
    agent: Agent,
    capability: CapabilityID,
    parameters: Bytes
  ) async throws → Bytes
  
  notify(agent: Agent, event: Event) async throws
  
  // === Trust ===
  trustLevel(for agent: Agent) → Float32
  recordInteraction(with agent: Agent, success: Bool)
  
  // === Lifecycle ===
  start() async throws
  stop() async throws
```

## 6.2 Agent Reference

```
Agent:
  id:           Agent ID
  publicKey:    PublicKey
  aliases:      [String]
  capabilities: [CapabilityID]
  endpoint:     Endpoint          // QuorumSystem実装依存
  trust:        Float32
  lastSeen:     Timestamp
  metadata:     Map<String, Bytes>

Endpoint: union
  MDNSEndpoint(host: String, port: UInt16)
  BLEEndpoint(deviceId: String, serviceUUID: String)
  HTTPEndpoint(url: String)
  // 他のQuorumSystem実装で拡張可能
```

## 6.3 Resolution

### 6.3.1 Resolve by ID

```
resolve(id: Agent ID) async throws → Agent

処理フロー:
1. ローカルキャッシュを確認
2. キャッシュにあれば返却
3. なければDiscoveryを実行
4. 発見できたらキャッシュに追加して返却
5. 発見できなければAgentNotFoundErrorをthrow

キャッシュ有効期間: 実装依存（推奨: 5分）
```

### 6.3.2 Resolve by Alias

```
resolve(alias: String) async throws → Agent

処理フロー:
1. ローカルエイリアスマッピングを確認
2. マッピングがあればAgent IDを取得
3. Agent IDでresolve(id:)を呼び出し
4. マッピングがなければAliasNotFoundErrorをthrow

エイリアス検証:
- 署名を検証しなければならない（MUST）
- 有効期限を確認しなければならない（MUST）
```

## 6.4 Discovery

### 6.4.1 Discover by Capability

```
discover(capability: CapabilityID) async → [Agent]

処理フロー:
1. ネットワークに問い合わせ
2. 指定Capabilityを持つAgentを収集
3. Agentリストを返却

マッチング:
- 完全一致: "cooking.prepare.v1"
- ワイルドカード: "cooking.*", "*.prepare.*"
```

### 6.4.2 Discover All

```
discoverAll() async → [Agent]

処理フロー:
1. ネットワーク上の全Agentを発見
2. Agentリストを返却

制限:
- タイムアウトを設定すべき（SHOULD）
- 最大件数を制限してもよい（MAY）
```

## 6.5 Communication

### 6.5.1 Invoke

```
invoke(
  agent: Agent,
  capability: CapabilityID,
  parameters: Bytes
) async throws → Bytes

処理フロー:
1. Trustを確認
2. Trustが不足していればInsufficientTrustErrorをthrow
3. メッセージを構築
4. 送信して応答を待機
5. 応答を返却
6. インタラクション結果を記録

タイムアウト: 実装依存（推奨: 30秒）
リトライ: 実装依存（推奨: 最大3回）
```

### 6.5.2 Notify

```
notify(agent: Agent, event: Event) async throws

処理フロー:
1. イベントメッセージを構築
2. 送信（応答不要）
3. 送信失敗時はエラーをthrow

特性:
- Fire-and-forget
- 配達保証なし
- 応答なし
```

## 6.6 Trust Operations

### 6.6.1 Get Trust Level

```
trustLevel(for agent: Agent) → Float32

処理:
1. TrustRecordを取得
2. 時間減衰を適用
3. 現在のTrustを返却
```

### 6.6.2 Record Interaction

```
recordInteraction(with agent: Agent, success: Bool)

処理:
1. TrustRecordを取得または作成
2. Trust値を更新
3. 統計を更新
4. 保存
```

---

# 7. Message Format

## 7.1 Message Structure

```
Message:
  header:    MessageHeader
  payload:   Bytes
  signature: Signature

MessageHeader:
  version:    UInt8       // プロトコルバージョン (0x01)
  type:       MessageType // メッセージタイプ
  id:         MessageID   // メッセージID (16 bytes)
  senderId:   Agent ID    // 送信者ID (32 bytes)
  receiverId: Agent ID    // 受信者ID (32 bytes)
  timestamp:  Timestamp   // タイムスタンプ
  flags:      UInt16      // フラグ
  payloadLen: UInt32      // ペイロード長
```

## 7.2 Message Types

```
MessageType: enum UInt8
  
  // Discovery
  ANNOUNCE       = 0x01  // 存在通知
  QUERY          = 0x02  // Agent検索
  QUERY_RESPONSE = 0x03  // 検索応答
  
  // Communication
  INVOKE         = 0x10  // 機能呼び出し
  INVOKE_RESPONSE = 0x11 // 呼び出し応答
  NOTIFY         = 0x12  // 通知
  
  // Trust
  TRUST_REQUEST  = 0x20  // Trust情報要求
  TRUST_RESPONSE = 0x21  // Trust情報応答
  REFERRAL       = 0x22  // 紹介
  
  // Control
  PING           = 0x30  // 死活確認
  PONG           = 0x31  // 死活応答
  ERROR          = 0x3F  // エラー
```

## 7.3 Message Flags

```
MessageFlags: UInt16 (bitmask)
  
  ENCRYPTED      = 0x0001  // ペイロード暗号化済み
  COMPRESSED     = 0x0002  // ペイロード圧縮済み
  REQUIRES_ACK   = 0x0004  // 応答必須
  PRIORITY_HIGH  = 0x0010  // 高優先度
  PRIORITY_LOW   = 0x0020  // 低優先度
```

## 7.4 Binary Format

```
Message Binary Layout:

Offset  Size   Field
──────────────────────────────────────
0       1      version (0x01)
1       1      type
2       16     messageId
18      32     senderId
50      32     receiverId
82      8      timestamp (big-endian)
90      2      flags (big-endian)
92      4      payloadLen (big-endian)
96      N      payload (N = payloadLen)
96+N    64     signature
──────────────────────────────────────
Total: 160 + N bytes
```

## 7.5 Signature Calculation

```
signatureData = concat(
  header.version,
  header.type,
  header.id,
  header.senderId,
  header.receiverId,
  header.timestamp,
  header.flags,
  header.payloadLen,
  payload
)

signature = Ed25519.sign(signatureData, senderPrivateKey)
```

## 7.6 Payload Formats

### 7.6.1 ANNOUNCE Payload

```
AnnouncePayload:
  publicKey:    PublicKey         // 32 bytes
  aliasCount:   UInt8             // エイリアス数
  aliases:      [AliasEntry]      // エイリアスリスト
  capCount:     UInt16            // Capability数
  capabilities: [CapabilityEntry] // Capabilityリスト

AliasEntry:
  length: UInt8
  name:   String (UTF-8)

CapabilityEntry:
  length: UInt8
  id:     String (ASCII)
```

### 7.6.2 INVOKE Payload

```
InvokePayload:
  capabilityLen: UInt8      // Capability ID長
  capabilityId:  String     // Capability ID
  paramsLen:     UInt32     // パラメータ長
  params:        Bytes      // パラメータ（形式はCapability依存）
```

### 7.6.3 INVOKE_RESPONSE Payload

```
InvokeResponsePayload:
  status:     ResponseStatus  // 応答ステータス
  resultLen:  UInt32          // 結果長
  result:     Bytes           // 結果データ

ResponseStatus: enum UInt8
  SUCCESS           = 0x00
  ERROR             = 0x01
  CAPABILITY_NOT_FOUND = 0x02
  INVALID_PARAMS    = 0x03
  ACCESS_DENIED     = 0x04
  INTERNAL_ERROR    = 0x05
```

### 7.6.4 ERROR Payload

```
ErrorPayload:
  code:       ErrorCode   // エラーコード
  messageLen: UInt16      // メッセージ長
  message:    String      // エラーメッセージ (UTF-8)

ErrorCode: enum UInt16
  (Section 11で定義)
```

---

# 8. Discovery

## 8.1 Discovery Hierarchy

```
Discovery優先順位:

1. Local Cache
   - メモリ内キャッシュ
   - 最速
   
2. Knowledge Base
   - 永続化されたAgent情報
   - 過去に発見したAgent
   
3. Network Discovery
   - mDNS, BLE等による動的発見
   - QuorumSystem実装依存
   
4. Peer Query
   - 他Agentへの問い合わせ
   - Gossipプロトコル
```

## 8.2 Cache Management

### 8.2.1 Cache Entry

```
CacheEntry:
  agent:      Agent
  cachedAt:   Timestamp
  expiresAt:  Timestamp
  hitCount:   UInt32
  source:     DiscoverySource

DiscoverySource: enum
  NETWORK   = 0x01  // ネットワーク発見
  PEER      = 0x02  // ピアからの情報
  MANUAL    = 0x03  // 手動設定
```

### 8.2.2 Cache Policy

```
デフォルトキャッシュポリシー:

TTL (Time To Live):
  NETWORK発見:  5分
  PEER情報:     10分
  MANUAL設定:   無期限

最大エントリ数: 1000

エビクション:
  LRU (Least Recently Used)
```

## 8.3 mDNS Discovery

### 8.3.1 Service Registration

```
Service Type: _sqp._tcp.local

TXT Records:
  id=<Agent ID (Base58)>
  v=<protocol version>
  pk=<PublicKey (Base64)>
  caps=<capability1,capability2,...>
  alias=<alias1,alias2,...>
```

### 8.3.2 Service Query

```
Query: _sqp._tcp.local

応答処理:
1. TXTレコードをパース
2. Agent IDとPublicKeyを抽出
3. Capabilitiesをパース
4. Agentオブジェクトを構築
5. キャッシュに追加
```

## 8.4 Peer Query Protocol

### 8.4.1 Query Message

```
QUERY Payload:
  queryType:   QueryType
  queryData:   Bytes

QueryType: enum UInt8
  BY_CAPABILITY = 0x01
  BY_ALIAS      = 0x02
  ALL           = 0x03

BY_CAPABILITY data:
  patternLen: UInt8
  pattern:    String  // e.g., "cooking.*"

BY_ALIAS data:
  aliasLen: UInt8
  alias:    String    // e.g., "@chef"
```

### 8.4.2 Query Response

```
QUERY_RESPONSE Payload:
  count:   UInt16
  agents:  [AgentInfo]

AgentInfo:
  id:          Agent ID
  publicKey:   PublicKey
  aliasCount:  UInt8
  aliases:     [AliasEntry]
  capCount:    UInt16
  capabilities: [CapabilityEntry]
  endpoint:    EndpointInfo
```

---

# 9. Communication

## 9.1 Connection Management

### 9.1.1 Connection State

```
ConnectionState: enum
  DISCONNECTED
  CONNECTING
  CONNECTED
  DISCONNECTING

Connection:
  remoteAgent:   Agent
  state:         ConnectionState
  localEndpoint: Endpoint
  remoteEndpoint: Endpoint
  createdAt:     Timestamp
  lastActivity:  Timestamp
```

### 9.1.2 Connection Pool

```
ConnectionPool:
  maxConnections: UInt16      // 最大同時接続数
  idleTimeout:    Duration    // アイドルタイムアウト
  connections:    Map<Agent ID, Connection>

推奨設定:
  maxConnections: 100
  idleTimeout: 5分
```

## 9.2 Request-Response Pattern

### 9.2.1 Request

```
Request:
  id:         MessageID
  capability: CapabilityID
  params:     Bytes
  timeout:    Duration
  retries:    UInt8
```

### 9.2.2 Response

```
Response:
  requestId: MessageID
  status:    ResponseStatus
  result:    Bytes
  error:     Error?
```

### 9.2.3 Request Lifecycle

```
1. リクエスト作成
2. Trust確認
3. メッセージ構築・署名
4. 送信
5. タイムアウト付きで応答待機
6. 応答受信・署名検証
7. 結果返却
8. インタラクション記録

タイムアウト時:
- リトライカウントが残っていればリトライ
- 残っていなければTimeoutErrorをthrow
```

## 9.3 Notification Pattern

### 9.3.1 Event Types

```
EventType: enum UInt8
  STATE_CHANGED     = 0x01  // 状態変更
  CAPABILITY_ADDED  = 0x02  // Capability追加
  CAPABILITY_REMOVED = 0x03 // Capability削除
  ALIAS_CHANGED     = 0x04  // エイリアス変更
  CUSTOM            = 0xFF  // カスタムイベント
```

### 9.3.2 Event Payload

```
Event:
  type:      EventType
  source:    Agent ID
  timestamp: Timestamp
  dataLen:   UInt32
  data:      Bytes
```

## 9.4 Flow Control

### 9.4.1 Rate Limiting

```
RateLimiter:
  maxRequestsPerSecond: UInt32
  burstSize:            UInt32

推奨設定:
  maxRequestsPerSecond: 100
  burstSize: 20

制限超過時:
  RateLimitExceededError を返却
```

### 9.4.2 Backpressure

```
受信キュー満杯時:
  - 新規メッセージを拒否
  - BUSYステータスを返却
  - 一定時間後にリトライを期待
```

---

# 10. Security

## 10.1 Cryptographic Requirements

### 10.1.1 Algorithms

```
鍵生成:      Ed25519
署名:        Ed25519
ハッシュ:     SHA-256
乱数:        CSPRNG (Cryptographically Secure PRNG)
暗号化 (オプション): ChaCha20-Poly1305
```

### 10.1.2 Key Management

```
秘密鍵の保管:
- セキュアストレージを使用しなければならない（MUST）
- メモリ上での平文保持を最小化すべき（SHOULD）
- 可能であればハードウェアセキュリティモジュールを使用（RECOMMENDED）

鍵のローテーション:
- 定期的なローテーションを推奨（RECOMMENDED）
- 旧鍵での署名検証を一定期間サポートすべき（SHOULD）
```

## 10.2 Message Security

### 10.2.1 Signature Verification

```
全ての受信メッセージに対して:
1. 署名を検証しなければならない（MUST）
2. 署名が無効な場合、メッセージを破棄しなければならない（MUST）
3. 送信者IDと署名公開鍵の対応を確認しなければならない（MUST）
```

### 10.2.2 Replay Protection

```
リプレイ攻撃対策:
- タイムスタンプを確認しなければならない（MUST）
- 許容時間窓: ±5分（推奨）
- MessageIDの重複を検出すべき（SHOULD）
- 最近のMessageIDをキャッシュすべき（SHOULD）

MessageID キャッシュ:
  サイズ: 10000エントリ
  TTL: 10分
```

### 10.2.3 Optional Encryption

```
暗号化が必要な場合:
1. ENCRYPTEDフラグをセット
2. ChaCha20-Poly1305で暗号化
3. 鍵交換: X25519 (Ed25519鍵から導出)

鍵導出:
  sharedSecret = X25519(localPrivate, remotePublic)
  encryptionKey = SHA-256(sharedSecret || "SQP-ENC")
```

## 10.3 Trust Security

### 10.3.1 Trust Manipulation Prevention

```
Trust値の保護:
- Trust値はローカルでのみ管理
- 外部からのTrust値注入を禁止
- 紹介によるTrustは減衰率を適用
```

### 10.3.2 Sybil Attack Mitigation

```
Sybil攻撃対策:
- 新規Agentの初期Trustを低く設定
- 急激なTrust上昇を制限
- 紹介の連鎖に減衰を適用
- 評判システムとの統合（オプション）
```

## 10.4 Network Security

### 10.4.1 Transport Security

```
トランスポートセキュリティ:
- TLSの使用を推奨（RECOMMENDED）
- 最低TLS 1.2以上を使用すべき（SHOULD）
- 証明書検証を実装すべき（SHOULD）

ローカルネットワーク:
- TLSなしも許容（MAY）
- 署名による認証は必須（MUST）
```

### 10.4.2 DoS Protection

```
DoS対策:
- レート制限を実装しなければならない（MUST）
- 接続数制限を実装すべき（SHOULD）
- 異常トラフィックの検出を推奨（RECOMMENDED）
```

---

# 11. Error Handling

## 11.1 Error Codes

```
ErrorCode: enum UInt16

// General Errors (0x0001 - 0x00FF)
UNKNOWN_ERROR           = 0x0001
INTERNAL_ERROR          = 0x0002
NOT_IMPLEMENTED         = 0x0003
TIMEOUT                 = 0x0004
CANCELLED               = 0x0005

// Identity Errors (0x0100 - 0x01FF)
AGENT_NOT_FOUND         = 0x0100
ALIAS_NOT_FOUND         = 0x0101
INVALID_AGENT_ID        = 0x0102
INVALID_SIGNATURE       = 0x0103
KEY_MISMATCH            = 0x0104

// Capability Errors (0x0200 - 0x02FF)
CAPABILITY_NOT_FOUND    = 0x0200
INVALID_PARAMETERS      = 0x0201
PARAMETER_REQUIRED      = 0x0202
PARAMETER_TYPE_MISMATCH = 0x0203
PARAMETER_OUT_OF_RANGE  = 0x0204

// Trust Errors (0x0300 - 0x03FF)
INSUFFICIENT_TRUST      = 0x0300
TRUST_VERIFICATION_FAILED = 0x0301
REFERRAL_CHAIN_TOO_LONG = 0x0302

// Communication Errors (0x0400 - 0x04FF)
CONNECTION_FAILED       = 0x0400
CONNECTION_TIMEOUT      = 0x0401
CONNECTION_REFUSED      = 0x0402
MESSAGE_TOO_LARGE       = 0x0403
INVALID_MESSAGE         = 0x0404
RATE_LIMITED            = 0x0405
BUSY                    = 0x0406

// Security Errors (0x0500 - 0x05FF)
AUTHENTICATION_FAILED   = 0x0500
ENCRYPTION_FAILED       = 0x0501
DECRYPTION_FAILED       = 0x0502
REPLAY_DETECTED         = 0x0503
```

## 11.2 Error Response Format

```
Error:
  code:      ErrorCode
  message:   String
  details:   Map<String, Bytes>?
  retryable: Bool
  retryAfter: Duration?  // リトライ可能な場合

例:
  Error {
    code: INSUFFICIENT_TRUST
    message: "Trust 0.3 is below required 0.5"
    details: {
      "required": 0.5,
      "actual": 0.3,
      "capability": "cooking.prepare.v1"
    }
    retryable: false
  }
```

## 11.3 Error Handling Guidelines

### 11.3.1 Retry Policy

```
リトライ可能なエラー:
  TIMEOUT
  CONNECTION_FAILED
  CONNECTION_TIMEOUT
  BUSY

リトライ不可なエラー:
  INSUFFICIENT_TRUST
  CAPABILITY_NOT_FOUND
  INVALID_PARAMETERS
  AUTHENTICATION_FAILED

リトライ戦略:
  最大リトライ回数: 3
  初期待機時間: 100ms
  バックオフ: 指数 (×2)
  最大待機時間: 5秒
```

### 11.3.2 Fallback Strategies

```
AGENT_NOT_FOUND:
  1. キャッシュを無効化
  2. Discoveryを再実行
  3. それでも見つからなければエラー

CAPABILITY_NOT_FOUND:
  1. 代替Capabilityを検索
  2. なければエラー

CONNECTION_FAILED:
  1. 代替エンドポイントを試行
  2. なければエラー
```

---

# 12. QuorumSystem Implementations

## 12.1 Implementation Requirements

全てのQuorumSystem実装は以下を満たさなければならない（MUST）:

```
必須要件:
1. QuorumSystemプロトコルの全メソッドを実装
2. メッセージフォーマットに準拠
3. 署名検証を実装
4. Trustモデルをサポート
5. エラーハンドリングを実装

推奨要件:
1. キャッシュを実装
2. レート制限を実装
3. メトリクス収集
4. ロギング
```

## 12.2 LocalMDNSSystem

### 12.2.1 Overview

```
LocalMDNSSystem:
  発見: mDNS/DNS-SD
  通信: TCP直接接続
  対象: ローカルネットワーク

依存:
  - mDNS実装 (Avahi, Bonjour等)
  - TCP/IPスタック
```

### 12.2.2 Configuration

```
LocalMDNSConfig:
  serviceName:     String        // "_sqp._tcp"
  domain:          String        // "local"
  port:            UInt16        // デフォルト: 8420
  announceInterval: Duration     // デフォルト: 30秒
  browseTimeout:   Duration      // デフォルト: 5秒
  tcpTimeout:      Duration      // デフォルト: 10秒
  maxConnections:  UInt16        // デフォルト: 100
```

### 12.2.3 Service Record

```
mDNS Service:
  Name: <Agent ID-short>._sqp._tcp.local
  Type: _sqp._tcp.local
  Port: 8420
  
TXT Records:
  id=<Base58(Agent ID)>
  v=1
  pk=<Base64(PublicKey)>
  caps=cooking.prepare.v1,transport.carry.v1
  alias=@chef,@シェフ
```

### 12.2.4 TCP Message Framing

```
Frame Format:
┌────────────────────────────────────┐
│ Length (4 bytes, big-endian)       │
├────────────────────────────────────┤
│ Message (Length bytes)             │
└────────────────────────────────────┘

最大メッセージサイズ: 1MB
```

## 12.3 BLESystem

### 12.3.1 Overview

```
BLESystem:
  発見: BLE Advertising
  通信: GATT
  対象: 近距離デバイス

依存:
  - BLE 4.0以上
  - GATT実装
```

### 12.3.2 Configuration

```
BLEConfig:
  serviceUUID:      UUID      // SQPサービスUUID
  advertisingInterval: Duration // デフォルト: 100ms
  scanDuration:     Duration   // デフォルト: 5秒
  mtu:              UInt16     // デフォルト: 512
```

### 12.3.3 GATT Service

```
SQP GATT Service:
  UUID: 0xAA01 (短縮) または完全UUID

Characteristics:
  Agent Info (0xAA02):
    Properties: Read
    Value: AgentInfoPayload
    
  Invoke (0xAA03):
    Properties: Write, Notify
    Value: InvokePayload/Response
    
  Notify (0xAA04):
    Properties: Notify
    Value: EventPayload
```

### 12.3.4 Advertising Data

```
Advertising Payload:
  Flags: 0x06 (LE General Discoverable, BR/EDR Not Supported)
  Complete Local Name: <Agent ID-short>
  Service UUIDs: 0xAA01
  
Scan Response:
  Manufacturer Data:
    Company ID: TBD
    Data: <PublicKey (32 bytes)>
```

## 12.4 A2ABridgeSystem

### 12.4.1 Overview

```
A2ABridgeSystem:
  発見: HTTP /.well-known/agent.json
  通信: HTTP JSON-RPC
  対象: A2A互換クラウドエージェント

依存:
  - HTTP/1.1以上
  - JSON実装
```

### 12.4.2 Configuration

```
A2ABridgeConfig:
  httpPort:        UInt16      // デフォルト: 8080
  agentCardPath:   String      // "/.well-known/agent.json"
  jsonRpcPath:     String      // "/"
  timeout:         Duration    // デフォルト: 30秒
  maxBodySize:     UInt32      // デフォルト: 1MB
```

### 12.4.3 AgentCard Generation

```
SQP Agent → A2A AgentCard:

{
  "protocolVersion": "1.0",
  "name": <alias[0] または Agent ID-short>,
  "description": "SQP Agent",
  "url": "http://<host>:<port>",
  "version": "1.0.0",
  
  "capabilities": {
    "streaming": true,
    "pushNotifications": false
  },
  
  "skills": [
    {
      "id": <capability.id>,
      "name": <capability.name>,
      "description": <capability.description>
    }
  ],
  
  "extensions": {
    "sqp:identity": {
      "agentId": <Agent ID>,
      "publicKey": <Base64(PublicKey)>
    },
    "sqp:trust": {
      "minimumTrust": <requiredTrust>
    }
  }
}
```

### 12.4.4 Method Mapping

```
SQP → A2A:
  invoke() → message/send
  discover() → GET /.well-known/agent.json

A2A → SQP:
  message/send → invoke()
  tasks/get → (Task状態管理)
```

---

# 13. Interoperability

## 13.1 Protocol Version Negotiation

```
バージョンヘッダー:
  Message.header.version = 0x01 (現行バージョン)

互換性ルール:
  - 同一メジャーバージョン間は互換
  - マイナーバージョンの違いは許容
  - 未知のフィールドは無視すべき（SHOULD）
```

## 13.2 Capability Namespace Registration

```
標準ネームスペース:
  sqp.*        SQP標準機能
  system.*     システム機能
  
予約ネームスペース:
  com.*        商用
  org.*        組織
  io.*         サービス

カスタムネームスペース:
  reverse domain notation を推奨
  例: com.example.custom
```

## 13.3 Extension Points

### 13.3.1 Custom Message Types

```
カスタムメッセージタイプ:
  範囲: 0x80 - 0xFE
  
登録方法:
  - 非公式: 自由に使用（衝突の可能性あり）
  - 公式: SQP仕様への提案
```

### 13.3.2 Metadata Extensions

```
Metadataフィールドの使用:
  キー: "ext:<extension-name>"
  値: 任意のバイト列
  
例:
  "ext:geolocation": <位置情報>
  "ext:battery": <バッテリー残量>
```

## 13.4 A2A Interoperability

### 13.4.1 Conceptual Mapping

```
SQP                     A2A
───────────────────────────────────
Agent           ←→     Agent (Server)
Agent ID        ←→     AgentCard.id
Alias           ←→     AgentCard.name
Capability      ←→     AgentSkill
invoke()        ←→     message/send
Trust           ←→     (extension)
```

### 13.4.2 Data Format Translation

```
SQP Parameters → A2A Message Parts:
  
SQP:
  capability: cooking.prepare.v1
  params: { recipe: "pasta", servings: 2 }

A2A:
  {
    "message": {
      "role": "user",
      "parts": [
        { "text": "cooking.prepare.v1" },
        { "data": { "recipe": "pasta", "servings": 2 } }
      ],
      "metadata": {
        "sqp:sender_id": "<Agent ID>",
        "sqp:signature": "<Base64(Signature)>"
      }
    }
  }
```

### 13.4.3 Trust Extension for A2A

```
A2A SQP Trust Extension:
  URI: "sqp:extension/trust/v1"
  
Message Metadata:
  "sqp:trust": <Float>
  "sqp:trust_anchor": <String>
  
AgentCard Extension:
  "extensions": {
    "sqp:trust": {
      "minimumTrust": 0.5,
      "trustAnchors": ["owner", "manufacturer"]
    }
  }
```

---

# Appendix

## A. Base58 Encoding

```
Alphabet: 123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz

特徴:
- 0, O, I, l を除外（視覚的な曖昧さを回避）
- URLセーフ
- コピー&ペーストしやすい

Agent ID表現:
  32バイト → 約44文字
```

## B. Well-Known Ports

```
Port     Protocol    Usage
─────────────────────────────────
8420     TCP         SQP default
8421     TCP         SQP secure (TLS)
8080     HTTP        A2A Bridge
```

## C. MIME Types

```
application/sqp+cbor    CBOR形式のSQPメッセージ
application/sqp+json    JSON形式のSQPメッセージ（デバッグ用）
```

## D. Capability Examples

```yaml
# 調理機能
- id: cooking.prepare.v1
  name: Prepare Dish
  requiredTrust: 0.5
  parameters:
    - name: recipe
      type: STRING
      required: true
    - name: servings
      type: INTEGER
      default: 2

# 運搬機能
- id: transport.carry.v1
  name: Carry Object
  requiredTrust: 0.5
  parameters:
    - name: objectId
      type: STRING
      required: true
    - name: destination
      type: OBJECT
      required: true
      properties:
        - name: x
          type: FLOAT
        - name: y
          type: FLOAT
        - name: z
          type: FLOAT

# システム状態
- id: system.status.v1
  name: Get Status
  requiredTrust: 0.1
  parameters: []
  returns:
    type: OBJECT
    properties:
      - name: state
        type: STRING
      - name: battery
        type: FLOAT
      - name: uptime
        type: INTEGER
```

## E. Reference Implementations

```
言語別リファレンス実装（予定）:

Swift:
  - SQPCore: コアライブラリ
  - SQPLocalMDNS: mDNS実装
  - SQPBLE: BLE実装

Rust:
  - sqp-core: コアライブラリ
  - sqp-mdns: mDNS実装

Python:
  - py-sqp: プロトタイピング用

TypeScript:
  - sqp-js: Web/Node.js用
```

## F. Document History

```
Version  Date       Changes
─────────────────────────────────────────
1.0      2024-12    Initial specification
```

---

*End of Technical Specification*
