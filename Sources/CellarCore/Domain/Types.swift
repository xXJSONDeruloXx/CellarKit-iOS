import Foundation

public enum DistributionChannel: String, Codable, CaseIterable, Sendable {
    case appStore
    case testFlight
    case developerSigned
    case altStore
    case jailbreak
    case simulator
}

public enum JITMode: String, Codable, CaseIterable, Sendable {
    case none
    case threadedInterpreter
    case debuggerAttached
    case altJIT
    case jitStreamer
    case jailbreak
    case nativeEntitlement
}

public enum GuestBinaryArchitecture: String, Codable, CaseIterable, Sendable {
    case windowsARM64
    case windowsARM64EC
    case windowsX64
    case windowsX86
}

public enum AcquisitionMode: String, Codable, CaseIterable, Sendable {
    case localImport
    case bundledSample
    case storefrontDownload
}

public enum Storefront: String, Codable, CaseIterable, Sendable {
    case localImport
    case steam
    case epic
    case gog
    case amazon
}

public enum ExecutionBackend: String, Codable, CaseIterable, Sendable {
    case wineARM64
    case wineARM64EC
    case wineX64Translator
    case wineThreadedInterpreter
    case diagnosticVM
    case unsupported
}

public enum PolicyRisk: String, Codable, CaseIterable, Sendable {
    case low
    case medium
    case high
    case blocked
}
