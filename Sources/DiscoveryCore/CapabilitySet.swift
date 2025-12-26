// MARK: - CapabilitySet
// Discovery Capability Set

import Foundation

/// A collection of capabilities
public struct CapabilitySet: Sendable, Hashable {
    private var capabilities: [CapabilityID: Capability]

    public init() {
        self.capabilities = [:]
    }

    public init(capabilities: [Capability]) {
        self.capabilities = Dictionary(
            capabilities.map { ($0.id, $0) },
            uniquingKeysWith: { _, new in new }
        )
    }

    /// Add a capability
    public mutating func add(_ capability: Capability) {
        capabilities[capability.id] = capability
    }

    /// Remove a capability
    public mutating func remove(_ id: CapabilityID) {
        capabilities.removeValue(forKey: id)
    }

    /// Check if capability exists
    public func contains(_ id: CapabilityID) -> Bool {
        capabilities[id] != nil
    }

    /// Find capability by ID
    public func find(_ id: CapabilityID) -> Capability? {
        capabilities[id]
    }

    /// Find capabilities matching namespace
    public func find(namespace: String) -> [Capability] {
        capabilities.values.filter { $0.id.namespace == namespace }
    }

    /// Find capabilities matching name (any namespace)
    public func find(name: String) -> [Capability] {
        capabilities.values.filter { $0.id.name == name }
    }

    /// Find compatible capability (same namespace.name, compatible version)
    public func findCompatible(_ required: CapabilityID) -> Capability? {
        capabilities.values.first { capability in
            capability.id.namespace == required.namespace &&
            capability.id.name == required.name &&
            capability.id.version.isCompatible(with: required.version)
        }
    }

    /// All capabilities
    public var all: [Capability] {
        Array(capabilities.values)
    }

    /// Number of capabilities
    public var count: Int {
        capabilities.count
    }

    /// Check if empty
    public var isEmpty: Bool {
        capabilities.isEmpty
    }
}

// MARK: - Codable

extension CapabilitySet: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let capabilityArray = try container.decode([Capability].self)
        self.init(capabilities: capabilityArray)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(all)
    }
}
