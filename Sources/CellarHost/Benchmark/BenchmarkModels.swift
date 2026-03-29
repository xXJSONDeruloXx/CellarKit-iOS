import Foundation
import CellarCore

public struct LaunchSessionMetrics: Codable, Equatable, Sendable {
    public var startupDurationSeconds: TimeInterval?
    public var timeToInteractiveSeconds: TimeInterval?
    public var totalDurationSeconds: TimeInterval?
    public var logLineCount: Int
    public var eventCount: Int
    public var becameInteractive: Bool
    public var exitedCleanly: Bool

    public init(
        startupDurationSeconds: TimeInterval?,
        timeToInteractiveSeconds: TimeInterval?,
        totalDurationSeconds: TimeInterval?,
        logLineCount: Int,
        eventCount: Int,
        becameInteractive: Bool,
        exitedCleanly: Bool
    ) {
        self.startupDurationSeconds = startupDurationSeconds
        self.timeToInteractiveSeconds = timeToInteractiveSeconds
        self.totalDurationSeconds = totalDurationSeconds
        self.logLineCount = logLineCount
        self.eventCount = eventCount
        self.becameInteractive = becameInteractive
        self.exitedCleanly = exitedCleanly
    }
}

public struct BenchmarkRecord: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var sessionID: UUID
    public var containerID: UUID
    public var containerTitle: String
    public var contentMode: ImportedContentMode?
    public var backend: ExecutionBackend
    public var productLane: ProductLane
    public var distributionChannel: DistributionChannel
    public var jitMode: JITMode
    public var policyRisk: PolicyRisk
    public var hasIncreasedMemoryLimit: Bool
    public var supportsMoltenVK: Bool
    public var recordedAt: Date
    public var metrics: LaunchSessionMetrics
    public var plannerWarnings: [String]
    public var notes: [String]

    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        containerID: UUID,
        containerTitle: String,
        contentMode: ImportedContentMode?,
        backend: ExecutionBackend,
        productLane: ProductLane,
        distributionChannel: DistributionChannel,
        jitMode: JITMode,
        policyRisk: PolicyRisk,
        hasIncreasedMemoryLimit: Bool,
        supportsMoltenVK: Bool,
        recordedAt: Date,
        metrics: LaunchSessionMetrics,
        plannerWarnings: [String] = [],
        notes: [String] = []
    ) {
        self.id = id
        self.sessionID = sessionID
        self.containerID = containerID
        self.containerTitle = containerTitle
        self.contentMode = contentMode
        self.backend = backend
        self.productLane = productLane
        self.distributionChannel = distributionChannel
        self.jitMode = jitMode
        self.policyRisk = policyRisk
        self.hasIncreasedMemoryLimit = hasIncreasedMemoryLimit
        self.supportsMoltenVK = supportsMoltenVK
        self.recordedAt = recordedAt
        self.metrics = metrics
        self.plannerWarnings = plannerWarnings
        self.notes = notes
    }
}

public struct BenchmarkRecordFactory: Sendable {
    public init() {}

    public func makeRecord(
        session: LaunchSessionRecord,
        container: ContainerDescriptor,
        capabilities: RuntimeCapabilities,
        notes: [String] = []
    ) -> BenchmarkRecord {
        BenchmarkRecord(
            sessionID: session.id,
            containerID: container.id,
            containerTitle: container.title,
            contentMode: container.contentReference?.mode,
            backend: session.backend,
            productLane: session.productLane,
            distributionChannel: capabilities.distributionChannel,
            jitMode: capabilities.jitMode,
            policyRisk: session.policyRisk,
            hasIncreasedMemoryLimit: capabilities.hasIncreasedMemoryLimit,
            supportsMoltenVK: capabilities.supportsMoltenVK,
            recordedAt: session.endedAt ?? session.startedAt,
            metrics: session.metrics,
            plannerWarnings: session.plannerWarnings,
            notes: notes
        )
    }
}
