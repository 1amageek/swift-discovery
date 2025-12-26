// MARK: - CapabilitySchema
// Discovery Capability Schema

import Foundation

/// JSON Schema representation for capability input/output
public struct CapabilitySchema: Sendable, Hashable, Codable {
    /// Schema type
    public let type: SchemaType

    /// Properties for object types
    public let properties: [String: PropertySchema]?

    /// Required property names
    public let required: [String]?

    /// Description
    public let description: String?

    public init(
        type: SchemaType,
        properties: [String: PropertySchema]? = nil,
        required: [String]? = nil,
        description: String? = nil
    ) {
        self.type = type
        self.properties = properties
        self.required = required
        self.description = description
    }

    public enum SchemaType: String, Sendable, Hashable, Codable {
        case string
        case number
        case integer
        case boolean
        case object
        case array
        case null
    }
}

/// Property definition within a schema
public struct PropertySchema: Sendable, Hashable, Codable {
    public let type: CapabilitySchema.SchemaType
    public let description: String?
    public let format: String?
    public let minimum: Double?
    public let maximum: Double?
    public let enumValues: [String]?

    public init(
        type: CapabilitySchema.SchemaType,
        description: String? = nil,
        format: String? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil,
        enumValues: [String]? = nil
    ) {
        self.type = type
        self.description = description
        self.format = format
        self.minimum = minimum
        self.maximum = maximum
        self.enumValues = enumValues
    }

    enum CodingKeys: String, CodingKey {
        case type, description, format, minimum, maximum
        case enumValues = "enum"
    }
}
