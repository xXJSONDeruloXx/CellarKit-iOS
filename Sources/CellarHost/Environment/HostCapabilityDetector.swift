import Foundation
import CellarCore

public struct HostCapabilitySnapshot: Codable, Equatable, Sendable {
    public var productLane: ProductLane
    public var capabilities: RuntimeCapabilities
    public var notes: [String]

    public init(
        productLane: ProductLane,
        capabilities: RuntimeCapabilities,
        notes: [String] = []
    ) {
        self.productLane = productLane
        self.capabilities = capabilities
        self.notes = notes
    }
}

public protocol HostCapabilityDetecting: Sendable {
    func detect() -> HostCapabilitySnapshot
}

public struct HostCapabilityDetector: HostCapabilityDetecting, Sendable {
    public let environment: [String: String]

    public init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.environment = environment
    }

    public func detect() -> HostCapabilitySnapshot {
        var notes: [String] = []

        let productLane = override(ProductLane.self, key: "CELLARKIT_PRODUCT_LANE")
            ?? defaultLane(notes: &notes)
        let distributionChannel = override(DistributionChannel.self, key: "CELLARKIT_DISTRIBUTION_CHANNEL")
            ?? inferDistributionChannel(notes: &notes)
        let debuggerAttached = overrideBool(key: "CELLARKIT_DEBUGGER_ATTACHED") ?? false
        let jitMode = override(JITMode.self, key: "CELLARKIT_JIT_MODE")
            ?? inferJITMode(
                distributionChannel: distributionChannel,
                debuggerAttached: debuggerAttached,
                notes: &notes
            )

        if environment["CELLARKIT_PRODUCT_LANE"] != nil {
            notes.append("Product lane overridden from CELLARKIT_PRODUCT_LANE.")
        }
        if environment["CELLARKIT_DISTRIBUTION_CHANNEL"] != nil {
            notes.append("Distribution channel overridden from CELLARKIT_DISTRIBUTION_CHANNEL.")
        }
        if environment["CELLARKIT_JIT_MODE"] != nil {
            notes.append("JIT mode overridden from CELLARKIT_JIT_MODE.")
        }
        if environment["CELLARKIT_DEBUGGER_ATTACHED"] != nil {
            notes.append("Debugger attachment overridden from CELLARKIT_DEBUGGER_ATTACHED.")
        }

        let capabilities = RuntimeCapabilities(
            distributionChannel: distributionChannel,
            jitMode: jitMode,
            hasIncreasedMemoryLimit: overrideBool(key: "CELLARKIT_INCREASED_MEMORY_LIMIT") ?? false,
            supportsMoltenVK: overrideBool(key: "CELLARKIT_SUPPORTS_MOLTENVK") ?? true,
            supportsSecurityScopedBookmarks: overrideBool(key: "CELLARKIT_SUPPORTS_BOOKMARKS") ?? true,
            supportsBackgroundAssetFetch: overrideBool(key: "CELLARKIT_SUPPORTS_BACKGROUND_FETCH")
                ?? productLane.features.allowsStorefrontDownload,
            isDebuggerAttached: debuggerAttached
        )

        return HostCapabilitySnapshot(
            productLane: productLane,
            capabilities: capabilities,
            notes: notes
        )
    }

    private func defaultLane(notes: inout [String]) -> ProductLane {
        notes.append("Defaulted to research lane; set CELLARKIT_PRODUCT_LANE to model constrained builds.")
        return .research
    }

    private func inferDistributionChannel(notes: inout [String]) -> DistributionChannel {
        if environment["SIMULATOR_DEVICE_NAME"] != nil {
            notes.append("Detected simulator environment from SIMULATOR_DEVICE_NAME.")
            return .simulator
        }

        #if targetEnvironment(simulator)
        notes.append("Compiled for simulator target environment.")
        return .simulator
        #else
        notes.append("Assuming developer-signed distribution in the absence of explicit overrides.")
        return .developerSigned
        #endif
    }

    private func inferJITMode(
        distributionChannel: DistributionChannel,
        debuggerAttached: Bool,
        notes: inout [String]
    ) -> JITMode {
        if debuggerAttached {
            notes.append("Debugger attachment implies debugger-assisted JIT access for planning.")
            return .debuggerAttached
        }

        switch distributionChannel {
        case .jailbreak:
            notes.append("Jailbreak distribution implies a jailbreak execution mode.")
            return .jailbreak
        case .simulator:
            notes.append("Simulator is treated as a permissive diagnostic environment.")
            return .nativeEntitlement
        case .appStore, .testFlight, .developerSigned, .altStore:
            notes.append("No permissive JIT mode detected; defaulting to no-JIT assumptions.")
            return .none
        }
    }

    private func override<T: RawRepresentable>(_ type: T.Type, key: String) -> T? where T.RawValue == String {
        guard let rawValue = environment[key] else {
            return nil
        }
        return T(rawValue: rawValue)
    }

    private func overrideBool(key: String) -> Bool? {
        guard let rawValue = environment[key] else {
            return nil
        }

        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "on":
            return true
        case "0", "false", "no", "off":
            return false
        default:
            return nil
        }
    }
}
