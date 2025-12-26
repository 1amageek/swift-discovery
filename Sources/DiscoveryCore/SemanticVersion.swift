// MARK: - SemanticVersion
// Discovery Semantic Version

import Foundation

/// Semantic version for capability versioning
public struct SemanticVersion: Sendable, Hashable, Codable, Comparable, CustomStringConvertible {
    public let major: UInt
    public let minor: UInt
    public let patch: UInt

    public init(major: UInt, minor: UInt, patch: UInt) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// Parse from string "major.minor.patch"
    public init(parsing string: String) throws {
        let components = string.split(separator: ".")
        guard components.count == 3,
              let major = UInt(components[0]),
              let minor = UInt(components[1]),
              let patch = UInt(components[2]) else {
            throw CapabilityError.invalidVersionFormat(string)
        }
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public var description: String {
        "\(major).\(minor).\(patch)"
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }

    /// Check if this version is compatible with required version
    /// Compatible if major versions match and this >= required
    public func isCompatible(with required: SemanticVersion) -> Bool {
        major == required.major && self >= required
    }
}
