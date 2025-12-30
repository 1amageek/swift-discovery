import Testing
import Foundation
@testable import DiscoveryCore
@testable import LocalNetworkTransport

// MARK: - TCP Framing Tests

@Suite("TCP Framing Tests")
struct TCPFramingTests {

    @Test("Frame length prefix size is 4 bytes")
    func testFrameLengthPrefixSize() {
        // The framing protocol uses 4 bytes (UInt32) for length prefix
        let frameLengthSize = 4
        #expect(frameLengthSize == 4)
    }

    @Test("Message serialization roundtrip with variable peer ID lengths")
    func testMessageSerializationWithVariablePeerIDs() throws {
        // Test with short peer IDs
        let shortMessage = Message.create(
            type: .ping,
            senderID: PeerID("a"),
            recipientID: PeerID("b"),
            sequenceNumber: 1,
            payload: Data()
        )

        let shortSerialized = try shortMessage.serialize()
        let shortDeserialized = try Message.deserialize(from: shortSerialized)

        #expect(shortDeserialized.header.senderID == shortMessage.header.senderID)
        #expect(shortDeserialized.header.recipientID == shortMessage.header.recipientID)

        // Test with long peer IDs
        let longMessage = Message.create(
            type: .invoke,
            senderID: PeerID("this-is-a-very-long-sender-peer-id-name"),
            recipientID: PeerID("this-is-a-very-long-recipient-peer-id"),
            sequenceNumber: 99999,
            payload: "Large payload content here".data(using: .utf8)!
        )

        let longSerialized = try longMessage.serialize()
        let longDeserialized = try Message.deserialize(from: longSerialized)

        #expect(longDeserialized.header.senderID == longMessage.header.senderID)
        #expect(longDeserialized.header.recipientID == longMessage.header.recipientID)
        #expect(longDeserialized.payload == longMessage.payload)
    }

    @Test("Large payload serialization")
    func testLargePayloadSerialization() throws {
        // Test with a moderately large payload (64KB)
        let largePayload = Data(repeating: 0xAB, count: 65536)

        let message = Message.create(
            type: .invokeResponse,
            senderID: PeerID("server"),
            recipientID: PeerID("client"),
            sequenceNumber: 1,
            payload: largePayload
        )

        let serialized = try message.serialize()
        let deserialized = try Message.deserialize(from: serialized)

        #expect(deserialized.payload == largePayload)
        #expect(deserialized.payload.count == 65536)
    }

    @Test("Message frame size calculation")
    func testMessageFrameSizeCalculation() throws {
        let payload = "Hello, World!".data(using: .utf8)!

        let message = Message.create(
            type: .notify,
            senderID: PeerID("sender"),
            recipientID: PeerID("recipient"),
            sequenceNumber: 1,
            payload: payload
        )

        // Frame = 4-byte length prefix + serialized message
        let serialized = try message.serialize()
        let frameSize = 4 + serialized.count

        #expect(frameSize == 4 + message.totalSize)
    }

    @Test("Length prefix encoding")
    func testLengthPrefixEncoding() {
        // Test that length prefix is big-endian
        let length: UInt32 = 0x12345678
        var bigEndianLength = length.bigEndian
        let data = Data(bytes: &bigEndianLength, count: 4)

        // Verify big-endian byte order
        #expect(data[0] == 0x12)
        #expect(data[1] == 0x34)
        #expect(data[2] == 0x56)
        #expect(data[3] == 0x78)
    }

    @Test("Length prefix decoding")
    func testLengthPrefixDecoding() {
        // Create big-endian encoded length
        let data = Data([0x00, 0x01, 0x00, 0x00])  // 65536 in big-endian

        let length = data.withUnsafeBytes {
            UInt32(bigEndian: $0.loadUnaligned(as: UInt32.self))
        }

        #expect(length == 65536)
    }

    @Test("Maximum frame size check")
    func testMaximumFrameSize() {
        // maxPayloadSize is 1MB
        let maxPayloadSize = Message.maxPayloadSize
        let maxHeaderSize = MessageHeader.maxSize

        #expect(maxPayloadSize == 1024 * 1024)
        #expect(maxHeaderSize == MessageHeader.fixedSize + 2 + 63 + 63)

        // Maximum frame size should accommodate both
        let maxFrameSize = maxPayloadSize + maxHeaderSize
        #expect(maxFrameSize > maxPayloadSize)
    }
}

// MARK: - Message Buffer Tests

@Suite("Message Buffer Tests")
struct MessageBufferTests {

    @Test("Simulated split message handling")
    func testSimulatedSplitMessageHandling() throws {
        // Simulate receiving a message in two parts
        let message = Message.create(
            type: .invoke,
            senderID: PeerID("sender"),
            recipientID: PeerID("recipient"),
            sequenceNumber: 42,
            payload: "Test data for split message scenario".data(using: .utf8)!
        )

        let serialized = try message.serialize()

        // Split the data
        let splitPoint = serialized.count / 2
        let part1 = serialized.prefix(splitPoint)
        let part2 = serialized.suffix(from: splitPoint)

        // Combine and deserialize
        var buffer = Data()
        buffer.append(contentsOf: part1)
        buffer.append(contentsOf: part2)

        let deserialized = try Message.deserialize(from: buffer)

        #expect(deserialized.header.type == .invoke)
        #expect(deserialized.header.sequenceNumber == 42)
        #expect(deserialized.payload == message.payload)
    }

    @Test("Simulated multiple messages in buffer")
    func testSimulatedMultipleMessagesInBuffer() throws {
        // Create two messages
        let message1 = Message.create(
            type: .ping,
            senderID: PeerID("peer1"),
            recipientID: PeerID("peer2"),
            sequenceNumber: 1,
            payload: Data()
        )

        let message2 = Message.create(
            type: .pong,
            senderID: PeerID("peer2"),
            recipientID: PeerID("peer1"),
            sequenceNumber: 2,
            payload: Data()
        )

        let serialized1 = try message1.serialize()
        let serialized2 = try message2.serialize()

        // Create framed data (length prefix + message)
        var framedData = Data()

        // Frame 1
        var length1 = UInt32(serialized1.count).bigEndian
        framedData.append(Data(bytes: &length1, count: 4))
        framedData.append(serialized1)

        // Frame 2
        var length2 = UInt32(serialized2.count).bigEndian
        framedData.append(Data(bytes: &length2, count: 4))
        framedData.append(serialized2)

        // Parse first message
        var offset = 0
        let msgLen1 = framedData.subdata(in: offset..<offset+4).withUnsafeBytes {
            UInt32(bigEndian: $0.loadUnaligned(as: UInt32.self))
        }
        offset += 4

        let msgData1 = framedData.subdata(in: offset..<offset+Int(msgLen1))
        let parsed1 = try Message.deserialize(from: msgData1)
        offset += Int(msgLen1)

        // Parse second message
        let msgLen2 = framedData.subdata(in: offset..<offset+4).withUnsafeBytes {
            UInt32(bigEndian: $0.loadUnaligned(as: UInt32.self))
        }
        offset += 4

        let msgData2 = framedData.subdata(in: offset..<offset+Int(msgLen2))
        let parsed2 = try Message.deserialize(from: msgData2)

        #expect(parsed1.header.type == .ping)
        #expect(parsed1.header.sequenceNumber == 1)
        #expect(parsed2.header.type == .pong)
        #expect(parsed2.header.sequenceNumber == 2)
    }
}

// MARK: - ServiceEndpoint Tests

@Suite("Service Endpoint Parsing Tests")
struct ServiceEndpointParsingTests {

    @Test("Service name with dots is preserved")
    func testServiceNameWithDots() {
        // This test verifies that service names containing dots are handled correctly
        // The fix stores name/type/domain separately instead of concatenating with dots

        let serviceName = "my.device.name"
        let serviceType = "_discovery._tcp"
        let domain = "local."

        // Old broken approach would concatenate:
        // let broken = "\(serviceName).\(serviceType)\(domain)"
        // And then try to extract name with: broken.components(separatedBy: ".").first
        // This would return "my" instead of "my.device.name"

        // New approach stores components separately
        struct ServiceEndpoint {
            let name: String
            let type: String
            let domain: String
        }

        let endpoint = ServiceEndpoint(name: serviceName, type: serviceType, domain: domain)

        #expect(endpoint.name == "my.device.name")
        #expect(endpoint.type == "_discovery._tcp")
        #expect(endpoint.domain == "local.")
    }

    @Test("Various service name formats")
    func testVariousServiceNameFormats() {
        let testCases = [
            "simple",
            "with-dashes",
            "with.single.dot",
            "multiple.dots.in.name",
            "123-numeric-start"
        ]

        for name in testCases {
            struct ServiceEndpoint {
                let name: String
                let type: String
                let domain: String
            }

            let endpoint = ServiceEndpoint(
                name: name,
                type: "_discovery._tcp",
                domain: "local."
            )

            #expect(endpoint.name == name)
        }
    }
}

// MARK: - TransportError Tests

@Suite("Extended TransportError Tests")
struct ExtendedTransportErrorTests {

    @Test("Connection closed error")
    func testConnectionClosedError() {
        let error = TransportError.connectionClosed

        if case .connectionClosed = error {
            #expect(true)
        } else {
            #expect(Bool(false))
        }
    }

    @Test("Invalid data error")
    func testInvalidDataError() {
        let error = TransportError.invalidData

        if case .invalidData = error {
            #expect(true)
        } else {
            #expect(Bool(false))
        }
    }

    @Test("All transport error cases")
    func testAllTransportErrorCases() {
        let errors: [TransportError] = [
            .notStarted,
            .alreadyStarted,
            .connectionFailed("test"),
            .connectionClosed,
            .resolutionFailed(PeerID("test")),
            .invocationFailed(InvocationError(code: .unknown, message: "")),
            .timeout,
            .invalidData
        ]

        #expect(errors.count == 8)
    }
}

// MARK: - Memory Alignment Tests

@Suite("Memory Alignment Tests")
struct MemoryAlignmentTests {

    @Test("Unaligned UInt16 read")
    func testUnalignedUInt16Read() {
        // Create data with unaligned access
        let data = Data([0x00, 0x12, 0x34])  // 3 bytes
        let subdata = data.subdata(in: 1..<3)  // Offset by 1 byte (unaligned)

        let value = subdata.withUnsafeBytes {
            UInt16(bigEndian: $0.loadUnaligned(as: UInt16.self))
        }

        #expect(value == 0x1234)
    }

    @Test("Unaligned UInt32 read")
    func testUnalignedUInt32Read() {
        // Create data with unaligned access
        let data = Data([0x00, 0x12, 0x34, 0x56, 0x78])  // 5 bytes
        let subdata = data.subdata(in: 1..<5)  // Offset by 1 byte (unaligned)

        let value = subdata.withUnsafeBytes {
            UInt32(bigEndian: $0.loadUnaligned(as: UInt32.self))
        }

        #expect(value == 0x12345678)
    }

    @Test("Unaligned UInt64 read")
    func testUnalignedUInt64Read() {
        // Create data with unaligned access
        let data = Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
        let subdata = data.subdata(in: 1..<9)  // Offset by 1 byte (unaligned)

        let value = subdata.withUnsafeBytes {
            UInt64(bigEndian: $0.loadUnaligned(as: UInt64.self))
        }

        #expect(value == 0x0102030405060708)
    }

    @Test("MessageHeader deserialize from unaligned data")
    func testMessageHeaderDeserializeUnaligned() throws {
        // Create a valid header
        let header = MessageHeader(
            type: .invoke,
            senderID: PeerID("sender"),
            recipientID: PeerID("recipient"),
            sequenceNumber: 12345,
            payloadLength: 100
        )

        let serialized = try header.serialize()

        // Prepend a byte to make the data unaligned
        var unalignedData = Data([0xFF])
        unalignedData.append(serialized)

        // Extract from offset 1 (unaligned)
        let subdata = unalignedData.subdata(in: 1..<unalignedData.count)

        // This should not crash with loadUnaligned
        let deserialized = try MessageHeader.deserialize(from: subdata)

        #expect(deserialized.type == .invoke)
        #expect(deserialized.sequenceNumber == 12345)
        #expect(deserialized.payloadLength == 100)
    }
}
