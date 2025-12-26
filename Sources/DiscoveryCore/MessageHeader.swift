// MARK: - MessageHeader
// Discovery Message Header

import Foundation

/// Discovery message header
public struct MessageHeader: Sendable, Hashable {
    /// Protocol version (1 byte)
    public let version: UInt8

    /// Message type (1 byte)
    public let type: MessageType

    /// Message flags (2 bytes)
    public let flags: MessageFlags

    /// Sender's Peer ID (variable length, max 63 chars)
    public let senderID: PeerID

    /// Recipient's Peer ID or broadcast (variable length, max 63 chars)
    public let recipientID: PeerID

    /// Message sequence number (4 bytes)
    public let sequenceNumber: UInt32

    /// Timestamp in milliseconds since Unix epoch (8 bytes)
    public let timestamp: UInt64

    /// Payload length (4 bytes)
    public let payloadLength: UInt32

    /// Fixed header size (without peer IDs): 20 bytes
    /// version(1) + type(1) + flags(2) + seq(4) + timestamp(8) + payloadLen(4)
    public static let fixedSize = 20

    /// Maximum header size (with max length peer IDs)
    /// fixedSize + 2 length bytes + 63*2 peer name bytes
    public static let maxSize = fixedSize + 2 + 63 + 63

    /// Minimum serialized size (with 1-char peer names)
    public static var size: Int { fixedSize + 4 }  // minimum with empty names

    /// Current protocol version
    public static let currentVersion: UInt8 = 1

    public init(
        version: UInt8 = MessageHeader.currentVersion,
        type: MessageType,
        flags: MessageFlags = [],
        senderID: PeerID,
        recipientID: PeerID,
        sequenceNumber: UInt32,
        timestamp: UInt64 = UInt64(Date().timeIntervalSince1970 * 1000),
        payloadLength: UInt32
    ) {
        self.version = version
        self.type = type
        self.flags = flags
        self.senderID = senderID
        self.recipientID = recipientID
        self.sequenceNumber = sequenceNumber
        self.timestamp = timestamp
        self.payloadLength = payloadLength
    }
}

// MARK: - Serialization

extension MessageHeader {
    /// Serialize header to bytes
    public func serialize() throws -> Data {
        var data = Data()

        // Fixed fields
        data.append(version)
        data.append(type.rawValue)
        data.append(contentsOf: withUnsafeBytes(of: flags.rawValue.bigEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: sequenceNumber.bigEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: timestamp.bigEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: payloadLength.bigEndian) { Array($0) })

        // Variable length peer IDs (length-prefixed)
        let senderData = Data(senderID.name.utf8)
        let recipientData = Data(recipientID.name.utf8)

        guard senderData.count <= 63 && recipientData.count <= 63 else {
            throw MessageError.serializationFailed
        }

        data.append(UInt8(senderData.count))
        data.append(senderData)
        data.append(UInt8(recipientData.count))
        data.append(recipientData)

        return data
    }

    /// Deserialize header from bytes
    public static func deserialize(from data: Data) throws -> MessageHeader {
        guard data.count >= fixedSize + 2 else {  // minimum: fixed + 2 length bytes
            throw MessageError.insufficientData
        }

        var offset = 0

        let version = data[offset]
        offset += 1

        guard let type = MessageType(rawValue: data[offset]) else {
            throw MessageError.invalidMessageType
        }
        offset += 1

        let flags = MessageFlags(rawValue: data.subdata(in: offset..<offset+2).withUnsafeBytes {
            UInt16(bigEndian: $0.load(as: UInt16.self))
        })
        offset += 2

        let sequenceNumber = data.subdata(in: offset..<offset+4).withUnsafeBytes {
            UInt32(bigEndian: $0.load(as: UInt32.self))
        }
        offset += 4

        let timestamp = data.subdata(in: offset..<offset+8).withUnsafeBytes {
            UInt64(bigEndian: $0.load(as: UInt64.self))
        }
        offset += 8

        let payloadLength = data.subdata(in: offset..<offset+4).withUnsafeBytes {
            UInt32(bigEndian: $0.load(as: UInt32.self))
        }
        offset += 4

        // Read sender ID
        guard offset < data.count else { throw MessageError.insufficientData }
        let senderLen = Int(data[offset])
        offset += 1

        guard offset + senderLen <= data.count else { throw MessageError.insufficientData }
        let senderName = String(data: data.subdata(in: offset..<offset+senderLen), encoding: .utf8) ?? ""
        offset += senderLen

        // Read recipient ID
        guard offset < data.count else { throw MessageError.insufficientData }
        let recipientLen = Int(data[offset])
        offset += 1

        guard offset + recipientLen <= data.count else { throw MessageError.insufficientData }
        let recipientName = String(data: data.subdata(in: offset..<offset+recipientLen), encoding: .utf8) ?? ""

        return MessageHeader(
            version: version,
            type: type,
            flags: flags,
            senderID: PeerID(senderName),
            recipientID: PeerID(recipientName),
            sequenceNumber: sequenceNumber,
            timestamp: timestamp,
            payloadLength: payloadLength
        )
    }

    /// Calculate serialized size for this header
    public var serializedSize: Int {
        MessageHeader.fixedSize + 2 + senderID.name.utf8.count + recipientID.name.utf8.count
    }
}
