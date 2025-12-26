// MARK: - CapabilityError
// Discovery Capability Errors

import Foundation

/// Errors related to capability operations
public enum CapabilityError: Error, Sendable {
    case invalidVersionFormat(String)
    case invalidNamespace(String)
    case invalidName(String)
    case invalidCapabilityIDFormat(String)
    case capabilityNotFound(CapabilityID)
    case incompatibleVersion(required: SemanticVersion, provided: SemanticVersion)
}

extension CapabilityError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidVersionFormat(let string):
            return "Invalid version format: '\(string)' (expected major.minor.patch)"
        case .invalidNamespace(let namespace):
            return "Invalid namespace: '\(namespace)' (must be lowercase dot-separated identifiers)"
        case .invalidName(let name):
            return "Invalid capability name: '\(name)' (must be lowercase with underscores)"
        case .invalidCapabilityIDFormat(let string):
            return "Invalid capability ID format: '\(string)' (expected namespace.name.major.minor.patch)"
        case .capabilityNotFound(let id):
            return "Capability not found: \(id)"
        case .incompatibleVersion(let required, let provided):
            return "Incompatible version: required \(required), provided \(provided)"
        }
    }
}
