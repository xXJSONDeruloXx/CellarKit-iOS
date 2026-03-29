import Foundation

public enum ProductLane: String, Codable, CaseIterable, Sendable {
    case research
    case constrainedPublic
}

public struct LaneFeatureSet: Codable, Equatable, Sendable {
    public var allowsStorefrontAuthentication: Bool
    public var allowsStorefrontDownload: Bool
    public var allowsDynarecBackends: Bool
    public var allowsInterpreterBackends: Bool
    public var allowsDiagnosticVM: Bool

    public init(
        allowsStorefrontAuthentication: Bool,
        allowsStorefrontDownload: Bool,
        allowsDynarecBackends: Bool,
        allowsInterpreterBackends: Bool,
        allowsDiagnosticVM: Bool
    ) {
        self.allowsStorefrontAuthentication = allowsStorefrontAuthentication
        self.allowsStorefrontDownload = allowsStorefrontDownload
        self.allowsDynarecBackends = allowsDynarecBackends
        self.allowsInterpreterBackends = allowsInterpreterBackends
        self.allowsDiagnosticVM = allowsDiagnosticVM
    }
}

public extension ProductLane {
    var features: LaneFeatureSet {
        switch self {
        case .research:
            return LaneFeatureSet(
                allowsStorefrontAuthentication: true,
                allowsStorefrontDownload: true,
                allowsDynarecBackends: true,
                allowsInterpreterBackends: true,
                allowsDiagnosticVM: true
            )
        case .constrainedPublic:
            return LaneFeatureSet(
                allowsStorefrontAuthentication: false,
                allowsStorefrontDownload: false,
                allowsDynarecBackends: false,
                allowsInterpreterBackends: true,
                allowsDiagnosticVM: false
            )
        }
    }
}
