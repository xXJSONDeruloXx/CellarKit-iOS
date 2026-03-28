import Foundation

public struct RuntimeCapabilities: Codable, Equatable, Sendable {
    public var distributionChannel: DistributionChannel
    public var jitMode: JITMode
    public var hasIncreasedMemoryLimit: Bool
    public var supportsMoltenVK: Bool
    public var supportsSecurityScopedBookmarks: Bool
    public var supportsBackgroundAssetFetch: Bool
    public var isDebuggerAttached: Bool

    public init(
        distributionChannel: DistributionChannel,
        jitMode: JITMode,
        hasIncreasedMemoryLimit: Bool = false,
        supportsMoltenVK: Bool = true,
        supportsSecurityScopedBookmarks: Bool = true,
        supportsBackgroundAssetFetch: Bool = false,
        isDebuggerAttached: Bool = false
    ) {
        self.distributionChannel = distributionChannel
        self.jitMode = jitMode
        self.hasIncreasedMemoryLimit = hasIncreasedMemoryLimit
        self.supportsMoltenVK = supportsMoltenVK
        self.supportsSecurityScopedBookmarks = supportsSecurityScopedBookmarks
        self.supportsBackgroundAssetFetch = supportsBackgroundAssetFetch
        self.isDebuggerAttached = isDebuggerAttached
    }

    public var canRunDynarec: Bool {
        switch jitMode {
        case .debuggerAttached, .altJIT, .jitStreamer, .jailbreak, .nativeEntitlement:
            return true
        case .none, .threadedInterpreter:
            return false
        }
    }

    public var isPolicyConstrainedChannel: Bool {
        switch distributionChannel {
        case .appStore, .testFlight:
            return true
        case .developerSigned, .altStore, .jailbreak, .simulator:
            return false
        }
    }
}

public struct GameLaunchRequest: Codable, Equatable, Sendable {
    public var title: String
    public var storefront: Storefront
    public var acquisitionMode: AcquisitionMode
    public var guestArchitecture: GuestBinaryArchitecture
    public var requiresGraphicsTranslation: Bool
    public var allowsInterpreterFallback: Bool
    public var allowsDiagnosticVMFallback: Bool

    public init(
        title: String,
        storefront: Storefront,
        acquisitionMode: AcquisitionMode,
        guestArchitecture: GuestBinaryArchitecture,
        requiresGraphicsTranslation: Bool = true,
        allowsInterpreterFallback: Bool = true,
        allowsDiagnosticVMFallback: Bool = false
    ) {
        self.title = title
        self.storefront = storefront
        self.acquisitionMode = acquisitionMode
        self.guestArchitecture = guestArchitecture
        self.requiresGraphicsTranslation = requiresGraphicsTranslation
        self.allowsInterpreterFallback = allowsInterpreterFallback
        self.allowsDiagnosticVMFallback = allowsDiagnosticVMFallback
    }
}

public struct PlanningDecision: Codable, Equatable, Sendable {
    public var backend: ExecutionBackend
    public var policyRisk: PolicyRisk
    public var blockers: [String]
    public var warnings: [String]
    public var rationale: [String]
    public var recommendedNextSteps: [String]

    public init(
        backend: ExecutionBackend,
        policyRisk: PolicyRisk,
        blockers: [String] = [],
        warnings: [String] = [],
        rationale: [String] = [],
        recommendedNextSteps: [String] = []
    ) {
        self.backend = backend
        self.policyRisk = policyRisk
        self.blockers = blockers
        self.warnings = warnings
        self.rationale = rationale
        self.recommendedNextSteps = recommendedNextSteps
    }
}
