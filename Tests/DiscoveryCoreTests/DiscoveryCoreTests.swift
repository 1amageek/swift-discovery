import Testing
import Foundation
@testable import DiscoveryCore

// MARK: - PeerID Tests

@Suite("PeerID Tests")
struct PeerIDTests {

    @Test("Create PeerID from name")
    func testPeerIDCreation() {
        let peerID = PeerID("my-robot")

        #expect(peerID.name == "my-robot")
        #expect(peerID.localName == "my-robot.local")
    }

    @Test("PeerID sanitizes input")
    func testPeerIDSanitization() {
        let peerID = PeerID("My Robot 123")

        #expect(peerID.name == "my-robot-123")
    }

    @Test("PeerID truncates long names")
    func testPeerIDTruncation() {
        let longName = String(repeating: "a", count: 100)
        let peerID = PeerID(longName)

        #expect(peerID.name.count == 63)
    }

    @Test("PeerID equality")
    func testPeerIDEquality() {
        let id1 = PeerID("robot-1")
        let id2 = PeerID("robot-1")
        let id3 = PeerID("robot-2")

        #expect(id1 == id2)
        #expect(id1 != id3)
    }

    @Test("PeerID broadcast")
    func testPeerIDBroadcast() {
        let broadcast = PeerID.broadcast

        #expect(broadcast.isBroadcast)
        #expect(broadcast.name.isEmpty)
    }

    @Test("PeerID codable")
    func testPeerIDCodable() throws {
        let original = PeerID("test-peer")

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PeerID.self, from: encoded)

        #expect(decoded == original)
    }
}

// MARK: - Capability Tests

@Suite("Capability Tests")
struct CapabilityTests {

    @Test("Parse semantic version")
    func testSemanticVersionParsing() throws {
        let version = try SemanticVersion(parsing: "1.2.3")

        #expect(version.major == 1)
        #expect(version.minor == 2)
        #expect(version.patch == 3)
    }

    @Test("Semantic version comparison")
    func testSemanticVersionComparison() throws {
        let v1 = try SemanticVersion(parsing: "1.0.0")
        let v2 = try SemanticVersion(parsing: "1.0.1")
        let v3 = try SemanticVersion(parsing: "1.1.0")
        let v4 = try SemanticVersion(parsing: "2.0.0")

        #expect(v1 < v2)
        #expect(v2 < v3)
        #expect(v3 < v4)
    }

    @Test("Semantic version compatibility")
    func testSemanticVersionCompatibility() throws {
        let required = try SemanticVersion(parsing: "1.2.0")
        let compatible = try SemanticVersion(parsing: "1.3.0")
        let incompatible = try SemanticVersion(parsing: "2.0.0")

        #expect(compatible.isCompatible(with: required))
        #expect(!incompatible.isCompatible(with: required))
    }

    @Test("Parse capability ID")
    func testCapabilityIDParsing() throws {
        let capID = try CapabilityID(parsing: "robot.mobility.move.1.0.0")

        #expect(capID.namespace == "robot.mobility")
        #expect(capID.name == "move")
        #expect(capID.version == SemanticVersion(major: 1, minor: 0, patch: 0))
    }

    @Test("Capability ID string representation")
    func testCapabilityIDStringRepresentation() throws {
        let capID = try CapabilityID(
            namespace: "robot.mobility",
            name: "move",
            version: SemanticVersion(major: 1, minor: 0, patch: 0)
        )

        #expect(capID.fullString == "robot.mobility.move.1.0.0")
    }

    @Test("Invalid namespace format")
    func testInvalidNamespace() throws {
        #expect(throws: CapabilityError.self) {
            try CapabilityID(
                namespace: "Invalid.Namespace",
                name: "test",
                version: SemanticVersion(major: 1, minor: 0, patch: 0)
            )
        }
    }

    @Test("Invalid name format")
    func testInvalidName() throws {
        #expect(throws: CapabilityError.self) {
            try CapabilityID(
                namespace: "valid.namespace",
                name: "Invalid-Name",
                version: SemanticVersion(major: 1, minor: 0, patch: 0)
            )
        }
    }

    @Test("Capability set operations")
    func testCapabilitySet() throws {
        var set = CapabilitySet()

        let cap1 = try Capability(
            "robot.mobility.move.1.0.0",
            description: "Move the robot"
        )
        let cap2 = try Capability(
            "robot.sensors.camera.2.0.0",
            description: "Access camera"
        )

        set.add(cap1)
        set.add(cap2)

        #expect(set.count == 2)
        #expect(set.contains(cap1.id))
        #expect(set.find(namespace: "robot.mobility").count == 1)
        #expect(set.find(name: "camera").count == 1)
    }

    @Test("Find compatible capability")
    func testFindCompatibleCapability() throws {
        var set = CapabilitySet()

        let cap = try Capability(
            "robot.mobility.move.1.5.0",
            description: "Move the robot"
        )
        set.add(cap)

        let requiredOld = try CapabilityID(parsing: "robot.mobility.move.1.2.0")
        let requiredNew = try CapabilityID(parsing: "robot.mobility.move.2.0.0")

        #expect(set.findCompatible(requiredOld) != nil)
        #expect(set.findCompatible(requiredNew) == nil)
    }
}

// MARK: - Message Tests

@Suite("Message Tests")
struct MessageTests {

    @Test("Create message")
    func testCreateMessage() {
        let senderID = PeerID("sender")
        let recipientID = PeerID("recipient")
        let payload = "Hello, World!".data(using: .utf8)!

        let message = Message.create(
            type: .notify,
            senderID: senderID,
            recipientID: recipientID,
            sequenceNumber: 1,
            payload: payload
        )

        #expect(message.header.type == .notify)
        #expect(message.header.senderID == senderID)
        #expect(message.header.recipientID == recipientID)
        #expect(message.payload == payload)
    }

    @Test("Message validation")
    func testMessageValidation() {
        let message = Message.create(
            type: .ping,
            senderID: PeerID("sender"),
            recipientID: PeerID("recipient"),
            sequenceNumber: 1,
            payload: Data()
        )

        let result = message.validate()
        #expect(result.isValid)
    }

    @Test("Message serialization roundtrip")
    func testMessageSerializationRoundtrip() throws {
        let senderID = PeerID("test-sender")
        let recipientID = PeerID("test-recipient")
        let payload = "Test payload data".data(using: .utf8)!

        let original = Message.create(
            type: .invoke,
            flags: [.requiresAck],
            senderID: senderID,
            recipientID: recipientID,
            sequenceNumber: 12345,
            payload: payload
        )

        let serialized = try original.serialize()
        let deserialized = try Message.deserialize(from: serialized)

        #expect(deserialized.header.type == original.header.type)
        #expect(deserialized.header.flags == original.header.flags)
        #expect(deserialized.header.senderID == original.header.senderID)
        #expect(deserialized.header.recipientID == original.header.recipientID)
        #expect(deserialized.header.sequenceNumber == original.header.sequenceNumber)
        #expect(deserialized.payload == original.payload)
    }

    @Test("Broadcast message creation")
    func testBroadcastMessage() {
        let senderID = PeerID("broadcaster")

        let message = Message.broadcast(
            type: .announce,
            senderID: senderID,
            sequenceNumber: 1,
            payload: Data()
        )

        #expect(message.header.flags.contains(.broadcast))
        #expect(message.header.recipientID.isBroadcast)
    }

    @Test("Message type names")
    func testMessageTypeNames() {
        #expect(MessageType.announce.name == "ANNOUNCE")
        #expect(MessageType.query.name == "QUERY")
        #expect(MessageType.invoke.name == "INVOKE")
        #expect(MessageType.error.name == "ERROR")
    }

    @Test("All message types have names")
    func testAllMessageTypesHaveNames() {
        for type in MessageType.allCases {
            #expect(!type.name.isEmpty)
        }
    }
}

// MARK: - Local Peer Tests

@Suite("Local Peer Tests")
struct LocalPeerTests {

    @Test("Create local peer")
    func testCreateLocalPeer() {
        let peer = LocalPeer(name: "test-peer", displayName: "Test Peer")

        #expect(peer.displayName == "Test Peer")
        #expect(peer.peerID.name == "test-peer")
    }

    @Test("Local peer message creation")
    func testLocalPeerMessageCreation() async {
        let peer = LocalPeer(name: "sender")
        let recipientID = PeerID("recipient")

        let message = await peer.createMessage(
            type: .ping,
            to: recipientID,
            payload: Data()
        )

        #expect(message.header.senderID == peer.peerID)
        #expect(message.header.recipientID == recipientID)
    }

    @Test("Local peer broadcast creation")
    func testLocalPeerBroadcast() async {
        let peer = LocalPeer(name: "broadcaster")

        let message = await peer.createBroadcast(
            type: .announce,
            payload: Data()
        )

        #expect(message.header.flags.contains(.broadcast))
        #expect(message.header.senderID == peer.peerID)
    }

    @Test("Sequence number increments")
    func testSequenceNumberIncrements() async {
        let peer = LocalPeer(name: "counter")

        let seq1 = await peer.nextSequenceNumber()
        let seq2 = await peer.nextSequenceNumber()
        let seq3 = await peer.nextSequenceNumber()

        #expect(seq2 == seq1 + 1)
        #expect(seq3 == seq2 + 1)
    }
}

// MARK: - Resolved Peer Tests

@Suite("Resolved Peer Tests")
struct ResolvedPeerTests {

    @Test("Create resolved peer")
    func testCreateResolvedPeer() throws {
        let cap = try CapabilityID(parsing: "robot.arm.grab.1.0.0")

        let peer = ResolvedPeer(
            name: "robot-arm",
            provides: [cap],
            metadata: ["model": "v2"]
        )

        #expect(peer.peerID.name == "robot-arm")
        #expect(peer.provides.count == 1)
        #expect(peer.capabilities.count == 1)  // backward compatibility
        #expect(peer.isValid)
    }

    @Test("Resolved peer TTL expiration")
    func testResolvedPeerTTL() throws {
        let peer = ResolvedPeer(
            name: "temp-peer",
            provides: [],
            ttl: .seconds(-1)  // Already expired
        )

        #expect(!peer.isValid)
    }

    @Test("Resolved peer with accepts")
    func testResolvedPeerWithAccepts() throws {
        let provideCap = try CapabilityID(parsing: "robot.arm.grab.1.0.0")
        let acceptCap = try CapabilityID(parsing: "robot.command.move.1.0.0")

        let peer = ResolvedPeer(
            name: "robot-arm",
            provides: [provideCap],
            accepts: [acceptCap]
        )

        #expect(peer.provides.count == 1)
        #expect(peer.accepts.count == 1)
    }
}

// MARK: - Discovered Peer Tests

@Suite("Discovered Peer Tests")
struct DiscoveredPeerTests {

    @Test("Create discovered peer")
    func testCreateDiscoveredPeer() throws {
        let cap = try CapabilityID(parsing: "sensor.temperature.read.1.0.0")

        let peer = DiscoveredPeer(
            name: "temp-sensor",
            capability: cap,
            quality: 0.9
        )

        #expect(peer.peerID.name == "temp-sensor")
        #expect(peer.quality == 0.9)
    }

    @Test("Quality clamping")
    func testQualityClamping() throws {
        let cap = try CapabilityID(parsing: "test.test.test.1.0.0")

        let tooHigh = DiscoveredPeer(name: "a", capability: cap, quality: 1.5)
        let tooLow = DiscoveredPeer(name: "b", capability: cap, quality: -0.5)

        #expect(tooHigh.quality == 1.0)
        #expect(tooLow.quality == 0.0)
    }
}

// MARK: - MessageFlags Tests

@Suite("MessageFlags Tests")
struct MessageFlagsTests {

    @Test("Create individual flags")
    func testIndividualFlags() {
        let requiresAck = MessageFlags.requiresAck
        let encrypted = MessageFlags.encrypted
        let compressed = MessageFlags.compressed
        let broadcast = MessageFlags.broadcast

        #expect(requiresAck.rawValue == 1 << 0)
        #expect(encrypted.rawValue == 1 << 1)
        #expect(compressed.rawValue == 1 << 2)
        #expect(broadcast.rawValue == 1 << 3)
    }

    @Test("Combine flags")
    func testCombineFlags() {
        let flags: MessageFlags = [.requiresAck, .encrypted]

        #expect(flags.contains(.requiresAck))
        #expect(flags.contains(.encrypted))
        #expect(!flags.contains(.broadcast))
    }

    @Test("All flag values are unique")
    func testUniqueFlags() {
        let allFlags: [MessageFlags] = [
            .requiresAck, .encrypted, .compressed, .broadcast,
            .urgent, .response, .streaming, .final
        ]

        var seenRawValues = Set<UInt16>()
        for flag in allFlags {
            #expect(!seenRawValues.contains(flag.rawValue))
            seenRawValues.insert(flag.rawValue)
        }

        #expect(seenRawValues.count == 8)
    }

    @Test("Insert and remove flags")
    func testInsertRemoveFlags() {
        var flags = MessageFlags()

        flags.insert(.urgent)
        #expect(flags.contains(.urgent))

        flags.insert(.streaming)
        #expect(flags.contains(.streaming))

        flags.remove(.urgent)
        #expect(!flags.contains(.urgent))
        #expect(flags.contains(.streaming))
    }

    @Test("Empty flags")
    func testEmptyFlags() {
        let flags = MessageFlags()

        #expect(flags.isEmpty)
        #expect(flags.rawValue == 0)
    }

    @Test("Flags equality")
    func testFlagsEquality() {
        let flags1: MessageFlags = [.requiresAck, .encrypted]
        let flags2: MessageFlags = [.encrypted, .requiresAck]
        let flags3: MessageFlags = [.requiresAck]

        #expect(flags1 == flags2)
        #expect(flags1 != flags3)
    }
}

// MARK: - Payload Tests

@Suite("Payload Tests")
struct PayloadTests {

    @Test("Query payload encoding")
    func testQueryPayloadEncoding() throws {
        let capability = try CapabilityID(parsing: "test.capability.example.1.0.0")

        let payload = QueryPayload(capability: capability, filter: ["type": "robot"])

        let encoded = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(QueryPayload.self, from: encoded)

        #expect(decoded.capability == payload.capability)
        #expect(decoded.filter == payload.filter)
    }

    @Test("Invoke response payload encoding")
    func testInvokeResponsePayloadEncoding() throws {
        let successPayload = InvokeResponsePayload(
            invocationID: "test-123",
            success: true,
            result: "OK".data(using: .utf8)
        )

        let errorPayload = InvokeResponsePayload(
            invocationID: "test-456",
            success: false,
            errorCode: DiscoveryErrorCode.capabilityNotFound.rawValue,
            errorMessage: "Not found"
        )

        let successEncoded = try JSONEncoder().encode(successPayload)
        let errorEncoded = try JSONEncoder().encode(errorPayload)

        let successDecoded = try JSONDecoder().decode(InvokeResponsePayload.self, from: successEncoded)
        let errorDecoded = try JSONDecoder().decode(InvokeResponsePayload.self, from: errorEncoded)

        #expect(successDecoded.success == true)
        #expect(errorDecoded.success == false)
        #expect(errorDecoded.errorCode == DiscoveryErrorCode.capabilityNotFound.rawValue)
    }

    @Test("Invoke payload encoding")
    func testInvokePayloadEncoding() throws {
        let capability = try CapabilityID(parsing: "robot.arm.move.1.0.0")

        let payload = InvokePayload(
            capability: capability,
            invocationID: "inv-001",
            arguments: "{\"x\": 10}".data(using: .utf8)!
        )

        let encoded = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(InvokePayload.self, from: encoded)

        #expect(decoded.capability == payload.capability)
        #expect(decoded.invocationID == payload.invocationID)
    }
}

// MARK: - MessageError Tests

@Suite("MessageError Tests")
struct MessageErrorTests {

    @Test("MessageError localized descriptions")
    func testLocalizedDescriptions() {
        let errors: [MessageError] = [
            .serializationFailed,
            .insufficientData,
            .invalidMessageType,
            .invalidPeerID
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("MessageError serialization failed description")
    func testSerializationFailedDescription() {
        let error = MessageError.serializationFailed
        #expect(error.errorDescription == "Failed to serialize message")
    }

    @Test("MessageError insufficient data description")
    func testInsufficientDataDescription() {
        let error = MessageError.insufficientData
        #expect(error.errorDescription == "Insufficient data for message deserialization")
    }

    @Test("MessageError invalid message type description")
    func testInvalidMessageTypeDescription() {
        let error = MessageError.invalidMessageType
        #expect(error.errorDescription == "Invalid message type")
    }

    @Test("MessageError invalid peer ID description")
    func testInvalidPeerIDDescription() {
        let error = MessageError.invalidPeerID
        #expect(error.errorDescription == "Invalid peer ID in message")
    }

    @Test("MessageValidationResult success")
    func testValidationResultSuccess() {
        let result = MessageValidationResult.success
        #expect(result.isValid)
    }

    @Test("MessageValidationResult failure")
    func testValidationResultFailure() {
        let result = MessageValidationResult.failure(.payloadTooLarge)
        #expect(!result.isValid)
    }

    @Test("MessageValidationError types")
    func testValidationErrorTypes() {
        let errors: [MessageValidationError] = [
            .unsupportedVersion(99),
            .payloadLengthMismatch,
            .payloadTooLarge,
            .malformedHeader,
            .malformedPayload
        ]

        #expect(errors.count == 5)
    }
}

// MARK: - DiscoveryErrorCode Tests

@Suite("DiscoveryErrorCode Tests")
struct DiscoveryErrorCodeTests {

    @Test("Error code raw values")
    func testErrorCodeRawValues() {
        #expect(DiscoveryErrorCode.unknown.rawValue == 0)
        #expect(DiscoveryErrorCode.invalidMessage.rawValue == 1001)
        #expect(DiscoveryErrorCode.invalidSignature.rawValue == 1002)
        #expect(DiscoveryErrorCode.timestampExpired.rawValue == 1003)
    }

    @Test("Capability error codes")
    func testCapabilityErrorCodes() {
        #expect(DiscoveryErrorCode.capabilityNotFound.rawValue == 2001)
        #expect(DiscoveryErrorCode.capabilityNotAvailable.rawValue == 2002)
        #expect(DiscoveryErrorCode.incompatibleVersion.rawValue == 2003)
    }

    @Test("Invocation error codes")
    func testInvocationErrorCodes() {
        #expect(DiscoveryErrorCode.invocationFailed.rawValue == 3001)
        #expect(DiscoveryErrorCode.invocationTimeout.rawValue == 3002)
        #expect(DiscoveryErrorCode.invocationDenied.rawValue == 3003)
    }

    @Test("Trust error codes")
    func testTrustErrorCodes() {
        #expect(DiscoveryErrorCode.trustInsufficient.rawValue == 4001)
        #expect(DiscoveryErrorCode.trustExpired.rawValue == 4002)
    }

    @Test("Resource error codes")
    func testResourceErrorCodes() {
        #expect(DiscoveryErrorCode.rateLimitExceeded.rawValue == 5001)
        #expect(DiscoveryErrorCode.resourceUnavailable.rawValue == 5002)
    }

    @Test("Error code uniqueness")
    func testErrorCodeUniqueness() {
        let allCodes: [DiscoveryErrorCode] = [
            .unknown, .invalidMessage, .invalidSignature, .timestampExpired,
            .capabilityNotFound, .capabilityNotAvailable, .incompatibleVersion,
            .invocationFailed, .invocationTimeout, .invocationDenied,
            .trustInsufficient, .trustExpired,
            .rateLimitExceeded, .resourceUnavailable
        ]

        var seenRawValues = Set<UInt32>()
        for code in allCodes {
            #expect(!seenRawValues.contains(code.rawValue))
            seenRawValues.insert(code.rawValue)
        }

        #expect(seenRawValues.count == 14)
    }

    @Test("Error code from raw value")
    func testErrorCodeFromRawValue() {
        #expect(DiscoveryErrorCode(rawValue: 0) == .unknown)
        #expect(DiscoveryErrorCode(rawValue: 2001) == .capabilityNotFound)
        #expect(DiscoveryErrorCode(rawValue: 9999) == nil)
    }
}

// MARK: - CapabilitySchema Tests

@Suite("CapabilitySchema Tests")
struct CapabilitySchemaTests {

    @Test("Create simple schema")
    func testCreateSimpleSchema() {
        let schema = CapabilitySchema(
            type: .string,
            description: "A simple string value"
        )

        #expect(schema.type == .string)
        #expect(schema.description == "A simple string value")
        #expect(schema.properties == nil)
        #expect(schema.required == nil)
    }

    @Test("Create object schema")
    func testCreateObjectSchema() {
        let properties: [String: PropertySchema] = [
            "name": PropertySchema(type: .string, description: "User name"),
            "age": PropertySchema(type: .integer, description: "User age", minimum: 0, maximum: 150)
        ]

        let schema = CapabilitySchema(
            type: .object,
            properties: properties,
            required: ["name"],
            description: "User object"
        )

        #expect(schema.type == .object)
        #expect(schema.properties?.count == 2)
        #expect(schema.required?.contains("name") == true)
    }

    @Test("Schema type values")
    func testSchemaTypeValues() {
        let types: [CapabilitySchema.SchemaType] = [
            .string, .number, .integer, .boolean, .object, .array, .null
        ]

        #expect(types.count == 7)
        #expect(CapabilitySchema.SchemaType.string.rawValue == "string")
        #expect(CapabilitySchema.SchemaType.number.rawValue == "number")
        #expect(CapabilitySchema.SchemaType.object.rawValue == "object")
    }

    @Test("PropertySchema creation")
    func testPropertySchemaCreation() {
        let property = PropertySchema(
            type: .number,
            description: "Temperature in Celsius",
            format: "float",
            minimum: -273.15,
            maximum: 1000.0
        )

        #expect(property.type == .number)
        #expect(property.description == "Temperature in Celsius")
        #expect(property.format == "float")
        #expect(property.minimum == -273.15)
        #expect(property.maximum == 1000.0)
    }

    @Test("PropertySchema with enum values")
    func testPropertySchemaWithEnum() {
        let property = PropertySchema(
            type: .string,
            description: "Status",
            enumValues: ["active", "inactive", "pending"]
        )

        #expect(property.enumValues?.count == 3)
        #expect(property.enumValues?.contains("active") == true)
    }

    @Test("CapabilitySchema JSON encoding")
    func testSchemaJSONEncoding() throws {
        let schema = CapabilitySchema(
            type: .object,
            properties: [
                "x": PropertySchema(type: .number, description: "X coordinate"),
                "y": PropertySchema(type: .number, description: "Y coordinate")
            ],
            required: ["x", "y"],
            description: "2D Point"
        )

        let encoded = try JSONEncoder().encode(schema)
        let decoded = try JSONDecoder().decode(CapabilitySchema.self, from: encoded)

        #expect(decoded.type == schema.type)
        #expect(decoded.properties?.count == 2)
        #expect(decoded.required == schema.required)
        #expect(decoded.description == schema.description)
    }

    @Test("PropertySchema JSON encoding with enum key")
    func testPropertySchemaEnumKeyEncoding() throws {
        let property = PropertySchema(
            type: .string,
            enumValues: ["red", "green", "blue"]
        )

        let encoded = try JSONEncoder().encode(property)
        let jsonString = String(data: encoded, encoding: .utf8)!

        // Verify "enum" key is used instead of "enumValues"
        #expect(jsonString.contains("\"enum\""))
        #expect(!jsonString.contains("\"enumValues\""))
    }

    @Test("Schema equality")
    func testSchemaEquality() {
        let schema1 = CapabilitySchema(type: .string, description: "Test")
        let schema2 = CapabilitySchema(type: .string, description: "Test")
        let schema3 = CapabilitySchema(type: .number, description: "Test")

        #expect(schema1 == schema2)
        #expect(schema1 != schema3)
    }

    @Test("Schema hashable")
    func testSchemaHashable() {
        let schema1 = CapabilitySchema(type: .string)
        let schema2 = CapabilitySchema(type: .string)

        var set = Set<CapabilitySchema>()
        set.insert(schema1)
        set.insert(schema2)

        #expect(set.count == 1)
    }
}

// MARK: - TransportEvent Tests

@Suite("TransportEvent Tests")
struct TransportEventTests {

    @Test("Started event")
    func testStartedEvent() {
        let event = TransportEvent.started

        if case .started = event {
            #expect(true)
        } else {
            #expect(Bool(false))
        }
    }

    @Test("Stopped event")
    func testStoppedEvent() {
        let event = TransportEvent.stopped

        if case .stopped = event {
            #expect(true)
        } else {
            #expect(Bool(false))
        }
    }

    @Test("Peer discovered event")
    func testPeerDiscoveredEvent() throws {
        let capID = try CapabilityID(parsing: "test.cap.test.1.0.0")
        let discoveredPeer = DiscoveredPeer(
            name: "test-peer",
            capability: capID,
            quality: 0.8
        )

        let event = TransportEvent.peerDiscovered(discoveredPeer)

        if case .peerDiscovered(let peer) = event {
            #expect(peer.peerID.name == "test-peer")
            #expect(peer.quality == 0.8)
        } else {
            #expect(Bool(false))
        }
    }

    @Test("Peer lost event")
    func testPeerLostEvent() {
        let peerID = PeerID("lost-peer")
        let event = TransportEvent.peerLost(peerID)

        if case .peerLost(let id) = event {
            #expect(id == peerID)
        } else {
            #expect(Bool(false))
        }
    }

    @Test("Message received event")
    func testMessageReceivedEvent() {
        let senderID = PeerID("sender")
        let recipientID = PeerID("recipient")
        let message = Message.create(
            type: .ping,
            senderID: senderID,
            recipientID: recipientID,
            sequenceNumber: 1,
            payload: Data()
        )

        let event = TransportEvent.messageReceived(message, from: senderID)

        if case .messageReceived(let msg, let from) = event {
            #expect(msg.header.type == .ping)
            #expect(from == senderID)
        } else {
            #expect(Bool(false))
        }
    }

    @Test("Message sent event")
    func testMessageSentEvent() {
        let senderID = PeerID("sender")
        let recipientID = PeerID("recipient")
        let message = Message.create(
            type: .notify,
            senderID: senderID,
            recipientID: recipientID,
            sequenceNumber: 1,
            payload: Data()
        )

        let event = TransportEvent.messageSent(message, to: recipientID)

        if case .messageSent(let msg, let to) = event {
            #expect(msg.header.type == .notify)
            #expect(to == recipientID)
        } else {
            #expect(Bool(false))
        }
    }

    @Test("Error event")
    func testErrorEvent() {
        let error = TransportError.timeout
        let event = TransportEvent.error(error)

        if case .error(let err) = event {
            if case .timeout = err {
                #expect(true)
            } else {
                #expect(Bool(false))
            }
        } else {
            #expect(Bool(false))
        }
    }
}

// MARK: - TransportError Tests

@Suite("TransportError Tests")
struct TransportErrorTests {

    @Test("Not started error")
    func testNotStartedError() {
        let error = TransportError.notStarted

        if case .notStarted = error {
            #expect(true)
        } else {
            #expect(Bool(false))
        }
    }

    @Test("Already started error")
    func testAlreadyStartedError() {
        let error = TransportError.alreadyStarted

        if case .alreadyStarted = error {
            #expect(true)
        } else {
            #expect(Bool(false))
        }
    }

    @Test("Connection failed error")
    func testConnectionFailedError() {
        let error = TransportError.connectionFailed("Network unreachable")

        if case .connectionFailed(let reason) = error {
            #expect(reason == "Network unreachable")
        } else {
            #expect(Bool(false))
        }
    }

    @Test("Resolution failed error")
    func testResolutionFailedError() {
        let peerID = PeerID("unknown-peer")
        let error = TransportError.resolutionFailed(peerID)

        if case .resolutionFailed(let id) = error {
            #expect(id == peerID)
        } else {
            #expect(Bool(false))
        }
    }

    @Test("Invocation failed error")
    func testInvocationFailedError() {
        let invocationError = InvocationError(
            code: .capabilityNotFound,
            message: "Capability not available"
        )
        let error = TransportError.invocationFailed(invocationError)

        if case .invocationFailed(let invErr) = error {
            #expect(invErr.code == .capabilityNotFound)
            #expect(invErr.message == "Capability not available")
        } else {
            #expect(Bool(false))
        }
    }

    @Test("Timeout error")
    func testTimeoutError() {
        let error = TransportError.timeout

        if case .timeout = error {
            #expect(true)
        } else {
            #expect(Bool(false))
        }
    }

    @Test("Transport error is Error")
    func testTransportErrorConformsToError() {
        let error: Error = TransportError.timeout
        #expect(error is TransportError)
    }
}

// MARK: - InvocationResult Tests

@Suite("InvocationResult Tests")
struct InvocationResultTests {

    @Test("Create successful result")
    func testCreateSuccessfulResult() {
        let data = "Success data".data(using: .utf8)!
        let peerID = PeerID("responder")

        let result = InvocationResult.success(
            data: data,
            roundTripTime: .milliseconds(50),
            sourcePeerID: peerID
        )

        #expect(result.success)
        #expect(result.data == data)
        #expect(result.error == nil)
        #expect(result.sourcePeerID == peerID)
    }

    @Test("Create failed result")
    func testCreateFailedResult() {
        let peerID = PeerID("responder")
        let error = InvocationError(
            code: .invocationFailed,
            message: "Something went wrong"
        )

        let result = InvocationResult.failure(
            error: error,
            roundTripTime: .milliseconds(100),
            sourcePeerID: peerID
        )

        #expect(!result.success)
        #expect(result.data == nil)
        #expect(result.error?.code == .invocationFailed)
        #expect(result.error?.message == "Something went wrong")
    }

    @Test("Result with custom initializer")
    func testResultWithCustomInitializer() {
        let peerID = PeerID("peer")

        let result = InvocationResult(
            success: true,
            data: Data([1, 2, 3]),
            error: nil,
            roundTripTime: .seconds(1),
            sourcePeerID: peerID
        )

        #expect(result.success)
        #expect(result.data?.count == 3)
        #expect(result.roundTripTime == .seconds(1))
    }

    @Test("Round trip time tracking")
    func testRoundTripTimeTracking() {
        let peerID = PeerID("peer")
        let rtt = Duration.milliseconds(250)

        let result = InvocationResult.success(
            data: Data(),
            roundTripTime: rtt,
            sourcePeerID: peerID
        )

        #expect(result.roundTripTime == rtt)
    }
}

// MARK: - InvocationError Tests

@Suite("InvocationError Tests")
struct InvocationErrorTests {

    @Test("Create invocation error")
    func testCreateInvocationError() {
        let error = InvocationError(
            code: .capabilityNotFound,
            message: "The requested capability was not found"
        )

        #expect(error.code == .capabilityNotFound)
        #expect(error.message == "The requested capability was not found")
        #expect(error.details == nil)
    }

    @Test("Create invocation error with details")
    func testCreateInvocationErrorWithDetails() {
        let error = InvocationError(
            code: .invocationDenied,
            message: "Access denied",
            details: ["reason": "insufficient permissions", "required": "admin"]
        )

        #expect(error.code == .invocationDenied)
        #expect(error.details?["reason"] == "insufficient permissions")
        #expect(error.details?["required"] == "admin")
    }

    @Test("Invocation error is Error")
    func testInvocationErrorConformsToError() {
        let error: Error = InvocationError(code: .unknown, message: "Unknown error")
        #expect(error is InvocationError)
    }

    @Test("Different error codes")
    func testDifferentErrorCodes() {
        let errors = [
            InvocationError(code: .capabilityNotFound, message: ""),
            InvocationError(code: .capabilityNotAvailable, message: ""),
            InvocationError(code: .invocationFailed, message: ""),
            InvocationError(code: .invocationTimeout, message: ""),
            InvocationError(code: .invocationDenied, message: ""),
            InvocationError(code: .resourceUnavailable, message: "")
        ]

        let codes = errors.map { $0.code }
        let uniqueCodes = Set(codes.map { $0.rawValue })

        #expect(uniqueCodes.count == 6)
    }
}

// MARK: - Duration Extension Tests

@Suite("Duration Extension Tests")
struct DurationExtensionTests {

    @Test("Convert seconds to TimeInterval")
    func testSecondsToTimeInterval() {
        let duration = Duration.seconds(5)
        let interval = duration.timeInterval

        #expect(abs(interval - 5.0) < 0.001)
    }

    @Test("Convert milliseconds to TimeInterval")
    func testMillisecondsToTimeInterval() {
        let duration = Duration.milliseconds(500)
        let interval = duration.timeInterval

        #expect(abs(interval - 0.5) < 0.001)
    }

    @Test("Convert zero duration")
    func testZeroDuration() {
        let duration = Duration.zero
        let interval = duration.timeInterval

        #expect(interval == 0.0)
    }

    @Test("Convert fractional seconds")
    func testFractionalSeconds() {
        let duration = Duration.seconds(1) + .milliseconds(250)
        let interval = duration.timeInterval

        #expect(abs(interval - 1.25) < 0.001)
    }
}

// MARK: - Mock Transport for Testing

actor MockTransportState {
    var isActive: Bool = false
    var resolvedPeers: [PeerID: ResolvedPeer] = [:]
    var discoveredPeers: [DiscoveredPeer] = []
    var eventContinuation: AsyncStream<TransportEvent>.Continuation?

    func setActive(_ active: Bool) {
        isActive = active
    }

    func addPeer(_ peer: ResolvedPeer) {
        resolvedPeers[peer.peerID] = peer
    }

    func addDiscovered(_ peer: DiscoveredPeer) {
        discoveredPeers.append(peer)
    }

    func setEventContinuation(_ continuation: AsyncStream<TransportEvent>.Continuation?) {
        eventContinuation = continuation
    }

    func yieldEvent(_ event: TransportEvent) {
        eventContinuation?.yield(event)
    }
}

final class MockTransport: Transport, Sendable {
    let transportID: String
    let displayName: String
    private let state = MockTransportState()

    var isActive: Bool {
        get async {
            await state.isActive
        }
    }

    var events: AsyncStream<TransportEvent> {
        get async {
            AsyncStream { continuation in
                Task {
                    await self.state.setEventContinuation(continuation)
                }
            }
        }
    }

    init(transportID: String = "mock-transport", displayName: String = "Mock Transport") {
        self.transportID = transportID
        self.displayName = displayName
    }

    func start() async throws {
        let active = await state.isActive
        guard !active else { throw TransportError.alreadyStarted }
        await state.setActive(true)
        await state.yieldEvent(.started)
    }

    func stop() async throws {
        let active = await state.isActive
        guard active else { throw TransportError.notStarted }
        await state.setActive(false)
        await state.yieldEvent(.stopped)
    }

    func resolve(_ peerID: PeerID) async throws -> ResolvedPeer? {
        await state.resolvedPeers[peerID]
    }

    func discover(provides: CapabilityID, timeout: Duration) -> AsyncThrowingStream<DiscoveredPeer, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let peers = await self.state.discoveredPeers
                for peer in peers {
                    if peer.capability == provides {
                        continuation.yield(peer)
                    }
                }
                continuation.finish()
            }
        }
    }

    func discover(accepts: CapabilityID, timeout: Duration) -> AsyncThrowingStream<DiscoveredPeer, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let peers = await self.state.discoveredPeers
                for peer in peers {
                    if peer.capability == accepts {
                        continuation.yield(peer)
                    }
                }
                continuation.finish()
            }
        }
    }

    func discoverAll(timeout: Duration) -> AsyncThrowingStream<DiscoveredPeer, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let peers = await self.state.discoveredPeers
                for peer in peers {
                    continuation.yield(peer)
                }
                continuation.finish()
            }
        }
    }

    func invoke(
        _ capability: CapabilityID,
        on peerID: PeerID,
        arguments: Data,
        timeout: Duration
    ) async throws -> InvocationResult {
        let active = await state.isActive
        guard active else { throw TransportError.notStarted }
        return InvocationResult.success(
            data: "mock-result".data(using: .utf8)!,
            roundTripTime: .milliseconds(10),
            sourcePeerID: peerID
        )
    }

    // Test helpers
    func addResolvedPeer(_ peer: ResolvedPeer) async {
        await state.addPeer(peer)
    }

    func addDiscoveredPeer(_ peer: DiscoveredPeer) async {
        await state.addDiscovered(peer)
    }
}

// MARK: - TransportCoordinator Tests

@Suite("TransportCoordinator Tests")
struct TransportCoordinatorTests {

    @Test("Create coordinator")
    func testCreateCoordinator() async {
        let localPeer = LocalPeer(name: "test-peer")
        let coordinator = TransportCoordinator(localPeer: localPeer)

        let transports = await coordinator.allTransports
        #expect(transports.isEmpty)
    }

    @Test("Register transport")
    func testRegisterTransport() async {
        let localPeer = LocalPeer(name: "test-peer")
        let coordinator = TransportCoordinator(localPeer: localPeer)
        let mockTransport = MockTransport()

        await coordinator.register(mockTransport)

        let transports = await coordinator.allTransports
        #expect(transports.count == 1)
    }

    @Test("Unregister transport")
    func testUnregisterTransport() async {
        let localPeer = LocalPeer(name: "test-peer")
        let coordinator = TransportCoordinator(localPeer: localPeer)
        let mockTransport = MockTransport(transportID: "test-id")

        await coordinator.register(mockTransport)
        await coordinator.unregister("test-id")

        let transports = await coordinator.allTransports
        #expect(transports.isEmpty)
    }

    @Test("Get transport by ID")
    func testGetTransportByID() async {
        let localPeer = LocalPeer(name: "test-peer")
        let coordinator = TransportCoordinator(localPeer: localPeer)
        let mockTransport = MockTransport(transportID: "my-transport")

        await coordinator.register(mockTransport)

        let retrieved = await coordinator.transport("my-transport")
        #expect(retrieved != nil)
        #expect(retrieved?.transportID == "my-transport")

        let notFound = await coordinator.transport("non-existent")
        #expect(notFound == nil)
    }

    @Test("Start all transports")
    func testStartAllTransports() async throws {
        let localPeer = LocalPeer(name: "test-peer")
        let coordinator = TransportCoordinator(localPeer: localPeer)
        let mockTransport = MockTransport()

        await coordinator.register(mockTransport)
        try await coordinator.startAll()

        let isActive = await mockTransport.isActive
        #expect(isActive)
    }

    @Test("Stop all transports")
    func testStopAllTransports() async throws {
        let localPeer = LocalPeer(name: "test-peer")
        let coordinator = TransportCoordinator(localPeer: localPeer)
        let mockTransport = MockTransport()

        await coordinator.register(mockTransport)
        try await coordinator.startAll()
        try await coordinator.stopAll()

        let isActive = await mockTransport.isActive
        #expect(!isActive)
    }

    @Test("Resolve peer across transports")
    func testResolvePeerAcrossTransports() async throws {
        let localPeer = LocalPeer(name: "test-peer")
        let coordinator = TransportCoordinator(localPeer: localPeer)

        let mockTransport = MockTransport()
        let capID = try CapabilityID(parsing: "test.cap.test.1.0.0")
        let resolvedPeer = ResolvedPeer(
            name: "remote-peer",
            provides: [capID],
            metadata: [:]
        )
        await mockTransport.addResolvedPeer(resolvedPeer)

        await coordinator.register(mockTransport)

        let found = try await coordinator.resolve(PeerID("remote-peer"))
        #expect(found != nil)
        #expect(found?.peerID.name == "remote-peer")

        let notFound = try await coordinator.resolve(PeerID("unknown-peer"))
        #expect(notFound == nil)
    }

    @Test("Set and get invocation handler")
    func testInvocationHandler() async {
        let localPeer = LocalPeer(name: "test-peer")
        let coordinator = TransportCoordinator(localPeer: localPeer)

        // Initially no handler
        let initialHandler = await coordinator.getIncomingInvocationHandler()
        #expect(initialHandler == nil)

        // Set handler
        await coordinator.setIncomingInvocationHandler { payload, senderID in
            return InvokeResponsePayload(
                invocationID: payload.invocationID,
                success: true,
                result: nil
            )
        }

        let handler = await coordinator.getIncomingInvocationHandler()
        #expect(handler != nil)

        // Remove handler
        await coordinator.removeIncomingInvocationHandler()
        let removedHandler = await coordinator.getIncomingInvocationHandler()
        #expect(removedHandler == nil)
    }

    @Test("Register multiple transports")
    func testRegisterMultipleTransports() async {
        let localPeer = LocalPeer(name: "test-peer")
        let coordinator = TransportCoordinator(localPeer: localPeer)

        let transport1 = MockTransport(transportID: "transport-1")
        let transport2 = MockTransport(transportID: "transport-2")
        let transport3 = MockTransport(transportID: "transport-3")

        await coordinator.register(transport1)
        await coordinator.register(transport2)
        await coordinator.register(transport3)

        let transports = await coordinator.allTransports
        #expect(transports.count == 3)
    }

    @Test("Discover peers that provide capability")
    func testDiscoverPeersThatProvide() async throws {
        let localPeer = LocalPeer(name: "test-peer")
        let coordinator = TransportCoordinator(localPeer: localPeer)

        let mockTransport = MockTransport()
        let capID = try CapabilityID(parsing: "robot.arm.move.1.0.0")

        let peer1 = DiscoveredPeer(name: "robot-1", capability: capID, quality: 0.9)
        let peer2 = DiscoveredPeer(name: "robot-2", capability: capID, quality: 0.8)

        await mockTransport.addDiscoveredPeer(peer1)
        await mockTransport.addDiscoveredPeer(peer2)
        await coordinator.register(mockTransport)
        try await coordinator.startAll()

        var discoveredPeers: [DiscoveredPeer] = []
        let stream = await coordinator.discover(provides: capID, timeout: .seconds(1))
        for try await peer in stream {
            discoveredPeers.append(peer)
        }

        #expect(discoveredPeers.count == 2)
    }

    @Test("Discover peers that accept capability")
    func testDiscoverPeersThatAccept() async throws {
        let localPeer = LocalPeer(name: "test-peer")
        let coordinator = TransportCoordinator(localPeer: localPeer)

        let mockTransport = MockTransport()
        let capID = try CapabilityID(parsing: "robot.command.move.1.0.0")

        let peer1 = DiscoveredPeer(name: "controller-1", capability: capID, quality: 0.95)

        await mockTransport.addDiscoveredPeer(peer1)
        await coordinator.register(mockTransport)
        try await coordinator.startAll()

        var discoveredPeers: [DiscoveredPeer] = []
        let stream = await coordinator.discover(accepts: capID, timeout: .seconds(1))
        for try await peer in stream {
            discoveredPeers.append(peer)
        }

        #expect(discoveredPeers.count == 1)
    }
}
