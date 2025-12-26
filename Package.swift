// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-discovery",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .tvOS(.v18),
        .watchOS(.v11),
        .visionOS(.v2)
    ],
    products: [
        // Umbrella module - includes everything
        .library(
            name: "Discovery",
            targets: ["Discovery"]
        ),
        // Core module - protocols and types only
        .library(
            name: "DiscoveryCore",
            targets: ["DiscoveryCore"]
        ),
        // Individual transports
        .library(
            name: "LocalNetworkTransport",
            targets: ["LocalNetworkTransport"]
        ),
        .library(
            name: "NearbyTransport",
            targets: ["NearbyTransport"]
        ),
        .library(
            name: "RemoteNetworkTransport",
            targets: ["RemoteNetworkTransport"]
        ),
    ],
    targets: [
        // Core protocols and types
        .target(
            name: "DiscoveryCore"
        ),
        // Transport implementations
        .target(
            name: "LocalNetworkTransport",
            dependencies: ["DiscoveryCore"]
        ),
        .target(
            name: "NearbyTransport",
            dependencies: ["DiscoveryCore"]
        ),
        .target(
            name: "RemoteNetworkTransport",
            dependencies: ["DiscoveryCore"]
        ),
        // Umbrella module
        .target(
            name: "Discovery",
            dependencies: [
                "DiscoveryCore",
                "LocalNetworkTransport",
                "NearbyTransport",
                "RemoteNetworkTransport"
            ]
        ),
        // Tests
        .testTarget(
            name: "DiscoveryCoreTests",
            dependencies: ["DiscoveryCore"]
        ),
    ]
)
