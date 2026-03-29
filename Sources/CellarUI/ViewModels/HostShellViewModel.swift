import Foundation
import SwiftUI
import CellarCore
import CellarHost

@MainActor
public final class HostShellViewModel: ObservableObject {
    @Published public private(set) var capabilitySnapshot: HostCapabilitySnapshot
    @Published public private(set) var containers: [ContainerDescriptor] = []
    @Published public private(set) var sessions: [LaunchSessionRecord] = []
    @Published public private(set) var planningDecision: PlanningDecision?
    @Published public private(set) var selectedContainerID: UUID?
    @Published public private(set) var benchmarkResults: [BenchmarkRecord] = []
    @Published public private(set) var latestLog: String = ""
    @Published public private(set) var statusMessage: String = "Ready."
    @Published public private(set) var isBusy = false

    private let coordinator: HostCoordinator
    private let capabilityDetector: any HostCapabilityDetecting

    public init(
        paths: HostShellPaths = HostShellPaths(rootURL: HostShellPaths.defaultRootURL()),
        capabilityDetector: any HostCapabilityDetecting = HostCapabilityDetector(),
        coordinator: HostCoordinator? = nil
    ) {
        self.capabilityDetector = capabilityDetector
        self.capabilitySnapshot = capabilityDetector.detect()
        self.coordinator = coordinator ?? HostCoordinator(
            containerStore: ContainerStore(rootURL: paths.containersURL),
            sessionStore: LaunchSessionStore(rootURL: paths.sessionsURL),
            benchmarkStore: BenchmarkStore(rootURL: paths.benchmarksURL),
            contentImporter: ContentImportCoordinator(
                managedContentRootURL: paths.managedContentURL,
                bookmarkStore: BookmarkStore(rootURL: paths.bookmarksURL)
            ),
            bridge: SimulatedRuntimeBridge(
                logLines: [
                    "booting sample runtime",
                    "mounting simulated container",
                    "submitting first frame"
                ]
            )
        )
    }

    public func refresh() async {
        isBusy = true
        defer { isBusy = false }

        capabilitySnapshot = capabilityDetector.detect()

        do {
            containers = try await coordinator.listContainers()
            if let selectedContainerID,
               !containers.contains(where: { $0.id == selectedContainerID }) {
                self.selectedContainerID = nil
            }
            if self.selectedContainerID == nil {
                self.selectedContainerID = containers.first?.id
            }
            try await reloadSelectionDetails()
            statusMessage = containers.isEmpty
                ? "No containers yet. Create a sample container to exercise the host flow."
                : "Loaded \(containers.count) container(s)."
        } catch {
            statusMessage = "Refresh failed: \(error.localizedDescription)"
        }
    }

    public func selectContainer(id: UUID?) async {
        selectedContainerID = id
        do {
            try await reloadSelectionDetails()
        } catch {
            statusMessage = "Failed to load container details: \(error.localizedDescription)"
        }
    }

    public func createSampleContainer(title: String = "Sample Runtime Probe") async {
        isBusy = true
        defer { isBusy = false }

        capabilitySnapshot = capabilityDetector.detect()
        let guestArchitecture: GuestBinaryArchitecture = capabilitySnapshot.capabilities.canRunDynarec
            ? .windowsX64
            : .windowsARM64
        let request = GameLaunchRequest(
            title: title,
            storefront: .localImport,
            acquisitionMode: .bundledSample,
            guestArchitecture: guestArchitecture
        )
        let contentReference = ImportedContentReference(
            mode: .bundledSample,
            pathHint: "Samples/\(title)",
            originalFilename: guestArchitecture == .windowsX64 ? "SampleX64.exe" : "SampleARM64.exe"
        )

        do {
            let created = try await coordinator.createContainer(
                request: request,
                capabilities: capabilitySnapshot.capabilities,
                productLane: capabilitySnapshot.productLane,
                contentReference: contentReference
            )
            selectedContainerID = created.descriptor.id
            planningDecision = created.planningDecision
            statusMessage = "Created sample container \"\(created.descriptor.title)\"."
            await refresh()
        } catch {
            statusMessage = "Create failed: \(error.localizedDescription)"
        }
    }

    public func launchSelectedContainer() async {
        guard let selectedContainerID else {
            statusMessage = "Select or create a container first."
            return
        }

        isBusy = true
        defer { isBusy = false }

        capabilitySnapshot = capabilityDetector.detect()

        do {
            let session = try await coordinator.launch(
                containerID: selectedContainerID,
                capabilities: capabilitySnapshot.capabilities,
                productLane: capabilitySnapshot.productLane
            )
            latestLog = try await coordinator.log(for: session)
            containers = try await coordinator.listContainers()
            sessions = try await coordinator.sessions(for: selectedContainerID)
            benchmarkResults = try await coordinator.benchmarks(for: selectedContainerID)
            planningDecision = try await coordinator.planLaunch(
                for: selectedContainerID,
                capabilities: capabilitySnapshot.capabilities,
                productLane: capabilitySnapshot.productLane
            )
            statusMessage = "Launch finished with state \(session.state.rawValue)."
        } catch {
            statusMessage = "Launch failed: \(error.localizedDescription)"
        }
    }

    private func reloadSelectionDetails() async throws {
        guard let selectedContainerID else {
            sessions = []
            benchmarkResults = []
            planningDecision = nil
            latestLog = ""
            return
        }

        sessions = try await coordinator.sessions(for: selectedContainerID)
        benchmarkResults = try await coordinator.benchmarks(for: selectedContainerID)
        planningDecision = try await coordinator.planLaunch(
            for: selectedContainerID,
            capabilities: capabilitySnapshot.capabilities,
            productLane: capabilitySnapshot.productLane
        )

        if let latestSession = sessions.first {
            latestLog = try await coordinator.log(for: latestSession)
        } else {
            latestLog = ""
        }
    }
}
