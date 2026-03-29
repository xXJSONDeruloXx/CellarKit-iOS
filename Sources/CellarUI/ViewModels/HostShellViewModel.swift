import Foundation
import SwiftUI
import CellarCore
import CellarHost
import CellarRuntimeBridge

@MainActor
public final class HostShellViewModel: ObservableObject {
    @Published public private(set) var capabilitySnapshot: HostCapabilitySnapshot
    @Published public private(set) var containers: [ContainerDescriptor] = []
    @Published public private(set) var sessions: [LaunchSessionRecord] = []
    @Published public private(set) var planningDecision: PlanningDecision?
    @Published public private(set) var selectedContainerID: UUID?
    @Published public private(set) var selectedContainer: ContainerDescriptor?
    @Published public private(set) var resolvedContentPath: String?
    @Published public private(set) var benchmarkResults: [BenchmarkRecord] = []
    @Published public private(set) var latestLog: String = ""
    @Published public private(set) var statusMessage: String = "Ready."
    @Published public private(set) var isBusy = false

    private let coordinator: HostCoordinator
    private let capabilityDetector: any HostCapabilityDetecting
    private let environment: [String: String]

    public init(
        paths: HostShellPaths = HostShellPaths(rootURL: HostShellPaths.defaultRootURL()),
        capabilityDetector: any HostCapabilityDetecting = HostCapabilityDetector(),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        coordinator: HostCoordinator? = nil
    ) {
        self.capabilityDetector = capabilityDetector
        self.environment = environment
        self.capabilitySnapshot = capabilityDetector.detect()
        self.coordinator = coordinator ?? HostCoordinator(
            containerStore: ContainerStore(rootURL: paths.containersURL),
            sessionStore: LaunchSessionStore(rootURL: paths.sessionsURL),
            benchmarkStore: BenchmarkStore(rootURL: paths.benchmarksURL),
            contentImporter: ContentImportCoordinator(
                managedContentRootURL: paths.managedContentURL,
                bookmarkStore: BookmarkStore(rootURL: paths.bookmarksURL)
            ),
            bridge: NativeRuntimeBridge()
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
            let summaryMessage = containers.isEmpty
                ? "No containers yet. Create a sample container to exercise the host flow."
                : "Loaded \(containers.count) container(s)."
            if statusMessage == "Ready."
                || statusMessage.hasPrefix("Loaded ")
                || statusMessage.hasPrefix("No containers") {
                statusMessage = summaryMessage
            }
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
            await refresh()
            statusMessage = "Created sample container \"\(created.descriptor.title)\"."
            if shouldAutoLaunchAfterCreate {
                await launchSelectedContainer()
            }
        } catch {
            statusMessage = "Create failed: \(error.localizedDescription)"
        }
    }

    public func importPayload(
        from sourceURL: URL,
        mode: ImportedContentMode = .managedCopy,
        titleOverride: String? = nil
    ) async {
        isBusy = true
        defer { isBusy = false }

        capabilitySnapshot = capabilityDetector.detect()

        let baseTitle = sourceURL.deletingPathExtension().lastPathComponent
        let inferredTitle = titleOverride ?? (baseTitle.isEmpty ? sourceURL.lastPathComponent : baseTitle)
        let guestArchitecture: GuestBinaryArchitecture = capabilitySnapshot.capabilities.canRunDynarec
            ? .windowsX64
            : .windowsARM64
        let request = GameLaunchRequest(
            title: inferredTitle.isEmpty ? "Imported Payload" : inferredTitle,
            storefront: .localImport,
            acquisitionMode: .localImport,
            guestArchitecture: guestArchitecture
        )

        do {
            let created: CreatedContainerResult
            switch mode {
            case .managedCopy:
                created = try await coordinator.createManagedCopyContainer(
                    sourceURL: sourceURL,
                    request: request,
                    capabilities: capabilitySnapshot.capabilities,
                    productLane: capabilitySnapshot.productLane,
                    preferredFilename: sourceURL.lastPathComponent,
                    titleOverride: inferredTitle.isEmpty ? nil : inferredTitle
                )
            case .externalSecurityScopedReference:
                created = try await coordinator.createExternalReferenceContainer(
                    sourceURL: sourceURL,
                    request: request,
                    capabilities: capabilitySnapshot.capabilities,
                    productLane: capabilitySnapshot.productLane,
                    titleOverride: inferredTitle.isEmpty ? nil : inferredTitle
                )
            case .storefrontManagedDownload, .bundledSample:
                created = try await coordinator.createManagedCopyContainer(
                    sourceURL: sourceURL,
                    request: request,
                    capabilities: capabilitySnapshot.capabilities,
                    productLane: capabilitySnapshot.productLane,
                    preferredFilename: sourceURL.lastPathComponent,
                    titleOverride: inferredTitle.isEmpty ? nil : inferredTitle
                )
            }
            selectedContainerID = created.descriptor.id
            planningDecision = created.planningDecision
            await refresh()
            let action = mode == .externalSecurityScopedReference ? "Linked external payload" : "Imported payload"
            statusMessage = "\(action) into container \"\(created.descriptor.title)\"."
        } catch {
            statusMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    public func renameSelectedContainer(to newTitle: String) async {
        guard var selectedContainer, !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusMessage = "Enter a non-empty title before saving changes."
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            selectedContainer.title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            try await coordinator.updateContainer(selectedContainer)
            await refresh()
            self.selectedContainer = try await coordinator.loadContainer(id: selectedContainer.id)
            statusMessage = "Renamed container to \"\(selectedContainer.title)\"."
        } catch {
            statusMessage = "Rename failed: \(error.localizedDescription)"
        }
    }

    public func deleteSelectedContainer() async {
        guard let selectedContainerID else {
            statusMessage = "Select a container first."
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            try await coordinator.deleteContainer(id: selectedContainerID)
            self.selectedContainerID = nil
            self.selectedContainer = nil
            self.resolvedContentPath = nil
            await refresh()
            statusMessage = "Deleted selected container."
        } catch {
            statusMessage = "Delete failed: \(error.localizedDescription)"
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

    private var shouldAutoLaunchAfterCreate: Bool {
        guard let rawValue = environment["CELLARKIT_AUTOLAUNCH_AFTER_CREATE"] else {
            return false
        }
        return ["1", "true", "yes", "on"].contains(rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    private func reloadSelectionDetails() async throws {
        guard let selectedContainerID else {
            selectedContainer = nil
            resolvedContentPath = nil
            sessions = []
            benchmarkResults = []
            planningDecision = nil
            latestLog = ""
            return
        }

        selectedContainer = try await coordinator.loadContainer(id: selectedContainerID)
        resolvedContentPath = try await coordinator.resolvedContentURL(for: selectedContainerID)?.path
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
