// MARK: - Message
// Discovery Message

import Foundation

/// Complete Discovery message with header and payload
public struct Message: Sendable, Hashable {
    /// Message header
    public let header: MessageHeader

    /// Message payload (variable length)
    public let payload: Data

    /// Total message size in bytes
    public var totalSize: Int {
        MessageHeader.size + payload.count
    }

    /// Minimum message size (header only, no payload)
    public static let minimumSize = MessageHeader.size

    /// Maximum payload size (1 MB)
    public static let maxPayloadSize = 1024 * 1024

    public init(header: MessageHeader, payload: Data) {
        self.header = header
        self.payload = payload
    }

    // MARK: - Factory Methods

    /// Create a message
    public static func create(
        type: MessageType,
        flags: MessageFlags = [],
        senderID: PeerID,
        recipientID: PeerID,
        sequenceNumber: UInt32,
        payload: Data
    ) -> Message {
        let header = MessageHeader(
            type: type,
            flags: flags,
            senderID: senderID,
            recipientID: recipientID,
            sequenceNumber: sequenceNumber,
            payloadLength: UInt32(payload.count)
        )
        return Message(header: header, payload: payload)
    }

    /// Create a broadcast message
    public static func broadcast(
        type: MessageType,
        senderID: PeerID,
        sequenceNumber: UInt32,
        payload: Data
    ) -> Message {
        create(
            type: type,
            flags: [.broadcast],
            senderID: senderID,
            recipientID: .broadcast,
            sequenceNumber: sequenceNumber,
            payload: payload
        )
    }

    // MARK: - Validation

    /// Basic message validation
    public func validate() -> MessageValidationResult {
        // Check version
        guard header.version == MessageHeader.currentVersion else {
            return .failure(.unsupportedVersion(header.version))
        }

        // Check payload length matches
        guard header.payloadLength == payload.count else {
            return .failure(.payloadLengthMismatch)
        }

        // Check payload size limit
        guard payload.count <= Message.maxPayloadSize else {
            return .failure(.payloadTooLarge)
        }

        return .success
    }
}

// MARK: - Serialization

extension Message {
    /// Serialize complete message to bytes
    public func serialize() throws -> Data {
        var data = Data()
        data.append(try header.serialize())
        data.append(payload)
        return data
    }

    /// Deserialize message from bytes
    public static func deserialize(from data: Data) throws -> Message {
        guard data.count >= MessageHeader.fixedSize + 2 else {
            throw MessageError.insufficientData
        }

        let header = try MessageHeader.deserialize(from: data)

        // Calculate actual header size (variable due to peer ID lengths)
        let payloadStart = header.serializedSize
        let payloadEnd = payloadStart + Int(header.payloadLength)

        guard data.count >= payloadEnd else {
            throw MessageError.insufficientData
        }

        let payload = data.subdata(in: payloadStart..<payloadEnd)

        return Message(header: header, payload: payload)
    }
}
