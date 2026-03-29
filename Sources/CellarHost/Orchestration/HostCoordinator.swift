import Foundation
import CellarCore

public enum HostCoordinatorError: Error, Equatable, Sendable {
    case containerNotFound(UUID)
    case importerUnavailable
}

public struct CreatedContainerResult: Equatable, Sendable {
    public var descriptor: ContainerDescriptor
    public var planningDecision: PlanningDecision

    public init(descriptor: ContainerDescriptor, planningDecision: PlanningDecision) {
        self.descriptor = descriptor
        self.planningDecision = planningDecision
    }
}

public actor HostCoordinator {
    private let containerStore: ContainerStore
    private let sessionStore: LaunchSessionStore
    private let benchmarkStore: BenchmarkStore?
    private let benchmarkFactory: BenchmarkRecordFactory
    private let contentImporter: ContentImportCoordinator?
    private let planner: ExecutionPlanner
    private let factory: ContainerFactory
    private let bridge: any RuntimeBridging

    public init(
        containerStore: ContainerStore,
        sessionStore: LaunchSessionStore,
        benchmarkStore: BenchmarkStore? = nil,
        contentImporter: ContentImportCoordinator? = nil,
        planner: ExecutionPlanner = ExecutionPlanner(),
        factory: ContainerFactory = ContainerFactory(),
        benchmarkFactory: BenchmarkRecordFactory = BenchmarkRecordFactory(),
        bridge: any RuntimeBridging = SimulatedRuntimeBridge()
    ) {
        self.containerStore = containerStore
        self.sessionStore = sessionStore
        self.benchmarkStore = benchmarkStore
        self.benchmarkFactory = benchmarkFactory
        self.contentImporter = contentImporter
        self.planner = planner
        self.factory = factory
        self.bridge = bridge
    }

    public func listContainers() throws -> [ContainerDescriptor] {
        try containerStore.loadAll()
    }

    public func loadContainer(id: UUID) throws -> ContainerDescriptor? {
        try containerStore.load(id: id)
    }

    public func createContainer(
        request: GameLaunchRequest,
        capabilities: RuntimeCapabilities,
        productLane: ProductLane,
        contentReference: ImportedContentReference? = nil,
        titleOverride: String? = nil
    ) throws -> CreatedContainerResult {
        let decision = planner.plan(
            request: request,
            capabilities: capabilities,
            productLane: productLane
        )
        let descriptor = factory.makeDescriptor(
            from: request,
            decision: decision,
            contentReference: contentReference,
            titleOverride: titleOverride
        )
        try containerStore.save(descriptor)
        return CreatedContainerResult(descriptor: descriptor, planningDecision: decision)
    }

    public func createManagedCopyContainer(
        sourceURL: URL,
        request: GameLaunchRequest,
        capabilities: RuntimeCapabilities,
        productLane: ProductLane,
        preferredFilename: String? = nil,
        titleOverride: String? = nil
    ) throws -> CreatedContainerResult {
        guard let contentImporter else {
            throw HostCoordinatorError.importerUnavailable
        }

        let containerID = UUID()
        let imported = try contentImporter.importManagedCopy(
            from: sourceURL,
            containerID: containerID,
            preferredName: preferredFilename
        )

        let decision = planner.plan(
            request: request,
            capabilities: capabilities,
            productLane: productLane
        )

        var descriptor = factory.makeDescriptor(
            from: request,
            decision: decision,
            contentReference: imported.contentReference,
            titleOverride: titleOverride
        )
        descriptor.id = containerID
        descriptor.importPath = imported.contentReference.pathHint
        descriptor.contentReference = imported.contentReference

        try containerStore.save(descriptor)
        return CreatedContainerResult(descriptor: descriptor, planningDecision: decision)
    }

    public func createExternalReferenceContainer(
        sourceURL: URL,
        request: GameLaunchRequest,
        capabilities: RuntimeCapabilities,
        productLane: ProductLane,
        titleOverride: String? = nil
    ) throws -> CreatedContainerResult {
        guard let contentImporter else {
            throw HostCoordinatorError.importerUnavailable
        }

        let imported = try contentImporter.registerSecurityScopedReference(for: sourceURL)
        let decision = planner.plan(
            request: request,
            capabilities: capabilities,
            productLane: productLane
        )

        var descriptor = factory.makeDescriptor(
            from: request,
            decision: decision,
            contentReference: imported.contentReference,
            titleOverride: titleOverride
        )
        descriptor.importPath = imported.contentReference.pathHint
        descriptor.contentReference = imported.contentReference

        try containerStore.save(descriptor)
        return CreatedContainerResult(descriptor: descriptor, planningDecision: decision)
    }

    public func resolvedContentURL(for containerID: UUID) throws -> URL? {
        guard let descriptor = try containerStore.load(id: containerID) else {
            throw HostCoordinatorError.containerNotFound(containerID)
        }

        guard let contentImporter else {
            return descriptor.contentReference?.pathHint.map { URL(fileURLWithPath: $0) }
        }

        return try contentImporter.resolveImportedPayloadURL(for: descriptor.contentReference)
    }

    public func planLaunch(
        for containerID: UUID,
        capabilities: RuntimeCapabilities,
        productLane: ProductLane
    ) throws -> PlanningDecision {
        guard let descriptor = try containerStore.load(id: containerID) else {
            throw HostCoordinatorError.containerNotFound(containerID)
        }

        return planner.plan(
            request: descriptor.launchRequest,
            capabilities: capabilities,
            productLane: productLane
        )
    }

    public func launch(
        containerID: UUID,
        capabilities: RuntimeCapabilities,
        productLane: ProductLane
    ) async throws -> LaunchSessionRecord {
        guard let descriptor = try containerStore.load(id: containerID) else {
            throw HostCoordinatorError.containerNotFound(containerID)
        }

        let decision = planner.plan(
            request: descriptor.launchRequest,
            capabilities: capabilities,
            productLane: productLane
        )

        let startedAt = Date()
        var record = LaunchSessionRecord(
            containerID: descriptor.id,
            containerTitle: descriptor.title,
            backend: decision.backend,
            productLane: productLane,
            policyRisk: decision.policyRisk,
            state: .preparing,
            startedAt: startedAt,
            plannerWarnings: decision.warnings,
            plannerRationale: decision.rationale,
            plannerNextSteps: decision.recommendedNextSteps,
            events: [
                LaunchSessionEvent(
                    timestamp: startedAt,
                    kind: .planningCompleted,
                    message: "Planner selected \(decision.backend.rawValue)."
                )
            ]
        )

        if decision.backend == .unsupported {
            let blockerMessage = decision.blockers.isEmpty
                ? "Launch is unsupported under the current configuration."
                : decision.blockers.joined(separator: " ")
            record.state = .planningFailed
            record.endedAt = startedAt
            record.events.append(
                LaunchSessionEvent(
                    timestamp: startedAt,
                    kind: .planningBlocked,
                    message: blockerMessage
                )
            )
            let persisted = try sessionStore.save(record, log: blockerMessage)
            try persistBenchmarkIfConfigured(
                session: persisted,
                container: descriptor,
                capabilities: capabilities,
                notes: ["Planning failed before runtime bootstrap."]
            )
            return persisted
        }

        var logLines: [String] = []

        for await event in bridge.launch(
            container: descriptor,
            decision: decision,
            capabilities: capabilities,
            productLane: productLane
        ) {
            let timestamp = Date()
            switch event {
            case .preparing(let message):
                record.state = .preparing
                record.events.append(
                    LaunchSessionEvent(
                        timestamp: timestamp,
                        kind: .preparing,
                        message: message
                    )
                )
            case .started:
                record.state = .starting
                record.events.append(
                    LaunchSessionEvent(
                        timestamp: timestamp,
                        kind: .started,
                        message: "Runtime process started."
                    )
                )
            case .log(let line):
                logLines.append(line)
                record.events.append(
                    LaunchSessionEvent(
                        timestamp: timestamp,
                        kind: .log,
                        message: line
                    )
                )
            case .interactive(let message):
                record.state = .interactive
                if record.becameInteractiveAt == nil {
                    record.becameInteractiveAt = timestamp
                }
                record.events.append(
                    LaunchSessionEvent(
                        timestamp: timestamp,
                        kind: .interactive,
                        message: message ?? "Runtime became interactive."
                    )
                )
            case .exited(let exitCode):
                record.lastExitCode = Int(exitCode)
                record.endedAt = timestamp
                record.state = exitCode == 0 ? .exitedCleanly : .exitedWithError
                record.events.append(
                    LaunchSessionEvent(
                        timestamp: timestamp,
                        kind: .stopped,
                        message: "Runtime exited with code \(exitCode)."
                    )
                )
            case .failed(let message):
                record.endedAt = timestamp
                record.state = record.becameInteractiveAt == nil ? .failedToStart : .exitedWithError
                record.events.append(
                    LaunchSessionEvent(
                        timestamp: timestamp,
                        kind: .failed,
                        message: message
                    )
                )
            }
        }

        if record.endedAt == nil {
            let fallbackEnd = Date()
            record.endedAt = fallbackEnd
            if record.state == .interactive || record.state == .starting || record.state == .preparing {
                record.state = .exitedCleanly
            }
        }

        let persisted = try sessionStore.save(record, log: logLines.joined(separator: "\n"))
        try persistBenchmarkIfConfigured(
            session: persisted,
            container: descriptor,
            capabilities: capabilities,
            notes: []
        )
        if persisted.wasSuccessful {
            try containerStore.updateLastLaunchedAt(
                id: descriptor.id,
                at: persisted.becameInteractiveAt ?? persisted.endedAt ?? persisted.startedAt
            )
        }
        return persisted
    }

    public func sessions(for containerID: UUID) throws -> [LaunchSessionRecord] {
        try sessionStore.loadAll(containerID: containerID)
    }

    public func benchmarks(for containerID: UUID) throws -> [BenchmarkRecord] {
        guard let benchmarkStore else {
            return []
        }
        return try benchmarkStore.loadAll(containerID: containerID)
    }

    public func log(for session: LaunchSessionRecord) throws -> String {
        try sessionStore.loadLog(for: session)
    }

    private func persistBenchmarkIfConfigured(
        session: LaunchSessionRecord,
        container: ContainerDescriptor,
        capabilities: RuntimeCapabilities,
        notes: [String]
    ) throws {
        guard let benchmarkStore else {
            return
        }

        let benchmark = benchmarkFactory.makeRecord(
            session: session,
            container: container,
            capabilities: capabilities,
            notes: notes
        )
        try benchmarkStore.save(benchmark)
    }
}
