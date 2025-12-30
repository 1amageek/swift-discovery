# Repository Guidelines

## Project Structure & Module Organization
`swift-discovery` is a Swift Package Manager (SPM) library. Key paths:
- `Package.swift`: SPM manifest and target definitions.
- `Sources/`: Source modules.
  - `DiscoveryCore`: protocols, identifiers, capability types.
  - `LocalNetworkTransport`, `NearbyTransport`, `RemoteNetworkTransport`: transport implementations.
  - `Discovery`: umbrella module that re-exports the core and transports.
- `Tests/DiscoveryCoreTests`: Swift Testing suites for core types.
- `README.md`: conceptual overview, usage examples, and platform requirements.

## Build, Test, and Development Commands
Use standard SPM commands from the repo root:
- `swift build` — builds all targets.
- `swift test` — runs the full test suite.
- `swift test --filter "PeerID Tests"` — runs a specific `@Suite` (example).

## Coding Style & Naming Conventions
- Indentation: 4 spaces, no tabs (matches existing Swift files).
- Naming: types in `UpperCamelCase`, functions/vars in `lowerCamelCase`.
- Files: one primary type per file; filenames match the main type (e.g., `PeerID.swift`).
- Prefer `// MARK:` sections and doc comments for public API clarity.
- No formatter/linter is configured; keep style consistent with nearby code.

## Testing Guidelines
- Framework: Swift Testing (`import Testing`) with `@Suite`, `@Test`, and `#expect`.
- Location: `Tests/<ModuleName>Tests/`.
- Naming: `SomethingTests.swift` for files; `@Suite("…")` for logical groupings.
- Add tests for new public API, edge cases, and serialization behavior when relevant.

## Commit & Pull Request Guidelines
- Git history is minimal (`first commit`), so no formal convention is established.
- Use concise, imperative commit messages (e.g., “Add capability validation”).
- PRs should include: a short summary, rationale, tests run (`swift test`), and any
  platform-specific notes (macOS/iOS/tvOS/watchOS/visionOS).

## Architecture Overview
This library provides transport-agnostic peer discovery. The application layer
interacts with `TransportCoordinator` and `PeerID/Capability` types, while
transport modules encapsulate discovery and communication details.
