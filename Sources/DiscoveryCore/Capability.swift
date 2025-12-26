// MARK: - Capability
// Discovery Capability

import Foundation

/// A capability that a peer can provide or request
public struct Capability: Sendable, Hashable, Codable {
    /// Unique capability identifier
    public let id: CapabilityID

    /// Human-readable description
    public let description: String

    /// Input schema (JSON Schema format)
    public let inputSchema: CapabilitySchema?

    /// Output schema (JSON Schema format)
    public let outputSchema: CapabilitySchema?

    /// Additional metadata
    public let metadata: [String: String]

    public init(
        id: CapabilityID,
        description: String,
        inputSchema: CapabilitySchema? = nil,
        outputSchema: CapabilitySchema? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.description = description
        self.inputSchema = inputSchema
        self.outputSchema = outputSchema
        self.metadata = metadata
    }

    /// Convenience initializer with string parsing
    public init(
        _ capabilityString: String,
        description: String,
        inputSchema: CapabilitySchema? = nil,
        outputSchema: CapabilitySchema? = nil,
        metadata: [String: String] = [:]
    ) throws {
        let id = try CapabilityID(parsing: capabilityString)
        self.init(
            id: id,
            description: description,
            inputSchema: inputSchema,
            outputSchema: outputSchema,
            metadata: metadata
        )
    }
}
