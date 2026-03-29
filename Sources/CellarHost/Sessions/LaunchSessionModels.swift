import Foundation
import CellarCore

public enum LaunchSessionState: String, Codable, CaseIterable, Sendable {
    case planningFailed
    case preparing
    case starting
    case interactive
    case exitedCleanly
    case exitedWithError
    case failedToStart
}

public enum LaunchSessionEventKind: String, Codable, CaseIterable, Sendable {
    case planningCompleted
    case planningBlocked
    case preparing
    case started
    case log
    case interactive
    case stopped
    case failed
}

public struct LaunchSessionEvent: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var timestamp: Date
    public var kind: LaunchSessionEventKind
    public var message: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date,
        kind: LaunchSessionEventKind,
        message: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.message = message
    }
}

public struct LaunchSessionRecord: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var containerID: UUID
    public var containerTitle: String
    public var backend: ExecutionBackend
    public var productLane: ProductLane
    public var policyRisk: PolicyRisk
    public var state: LaunchSessionState
    public var startedAt: Date
    public var endedAt: Date?
    public var becameInteractiveAt: Date?
    public var lastExitCode: Int?
    public var plannerWarnings: [String]
    public var plannerRationale: [String]
    public var plannerNextSteps: [String]
    public var events: [LaunchSessionEvent]
    public var logRelativePath: String?

    public init(
        id: UUID = UUID(),
        containerID: UUID,
        containerTitle: String,
        backend: ExecutionBackend,
        productLane: ProductLane,
        policyRisk: PolicyRisk,
        state: LaunchSessionState,
        startedAt: Date,
        endedAt: Date? = nil,
        becameInteractiveAt: Date? = nil,
        lastExitCode: Int? = nil,
        plannerWarnings: [String] = [],
        plannerRationale: [String] = [],
        plannerNextSteps: [String] = [],
        events: [LaunchSessionEvent] = [],
        logRelativePath: String? = nil
    ) {
        self.id = id
        self.containerID = containerID
        self.containerTitle = containerTitle
        self.backend = backend
        self.productLane = productLane
        self.policyRisk = policyRisk
        self.state = state
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.becameInteractiveAt = becameInteractiveAt
        self.lastExitCode = lastExitCode
        self.plannerWarnings = plannerWarnings
        self.plannerRationale = plannerRationale
        self.plannerNextSteps = plannerNextSteps
        self.events = events
        self.logRelativePath = logRelativePath
    }

    public var wasSuccessful: Bool {
        becameInteractiveAt != nil || state == .exitedCleanly
    }
}
