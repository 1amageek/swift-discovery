// MARK: - CapabilityID
// Discovery Capability Identifier

import Foundation

/// Unique identifier for a capability
/// Format: namespace.name.version
public struct CapabilityID: Sendable, Hashable, Codable, CustomStringConvertible {
    /// Namespace (e.g., "com.example", "robot.mobility")
    public let namespace: String

    /// Capability name (e.g., "move", "speak", "sense")
    public let name: String

    /// Capability version
    public let version: SemanticVersion

    public init(namespace: String, name: String, version: SemanticVersion) throws {
        guard Self.isValidNamespace(namespace) else {
            throw CapabilityError.invalidNamespace(namespace)
        }
        guard Self.isValidName(name) else {
            throw CapabilityError.invalidName(name)
        }
        self.namespace = namespace
        self.name = name
        self.version = version
    }

    /// Parse from string "namespace.name.major.minor.patch"
    public init(parsing string: String) throws {
        let components = string.split(separator: ".")
        guard components.count >= 5 else {
            throw CapabilityError.invalidCapabilityIDFormat(string)
        }

        // Find where version starts (last 3 components)
        let versionComponents = components.suffix(3)
        let nameComponents = components.dropLast(3)

        guard nameComponents.count >= 2 else {
            throw CapabilityError.invalidCapabilityIDFormat(string)
        }

        // Last component before version is the name
        let name = String(nameComponents.last!)
        // Everything before that is the namespace
        let namespace = nameComponents.dropLast().map(String.init).joined(separator: ".")

        let versionString = versionComponents.map(String.init).joined(separator: ".")
        let version = try SemanticVersion(parsing: versionString)

        try self.init(namespace: namespace, name: name, version: version)
    }

    public var description: String {
        "\(namespace).\(name).\(version)"
    }

    /// Full identifier string
    public var fullString: String {
        description
    }

    // MARK: - Validation

    private static func isValidNamespace(_ namespace: String) -> Bool {
        let pattern = "^[a-z][a-z0-9]*(\\.[a-z][a-z0-9]*)*$"
        return namespace.range(of: pattern, options: .regularExpression) != nil
    }

    private static func isValidName(_ name: String) -> Bool {
        let pattern = "^[a-z][a-z0-9_]*$"
        return name.range(of: pattern, options: .regularExpression) != nil
    }
}
