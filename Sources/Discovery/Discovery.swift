// MARK: - Discovery
// Discovery Over Transport - Umbrella Module
// Transport-agnostic peer discovery protocol

@_exported import DiscoveryCore
@_exported import LocalNetworkTransport
@_exported import NearbyTransport
@_exported import RemoteNetworkTransport

/// Discovery version
public let DiscoveryVersion = "1.0.0"
