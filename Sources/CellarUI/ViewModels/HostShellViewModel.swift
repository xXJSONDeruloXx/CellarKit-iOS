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
    @Published public private(set) var selectedSessionID: UUID?
    @Published public private(set) var selectedBenchmarkID: UUID?
    @Published public private(set) var resolvedContentPath: String?
    @Published public private(set) var benchmarkResults: [BenchmarkRecord] = []
    @Published public private(set) var latestLog: String = ""
    @Published public private(set) var activeSession: LaunchSessionRecord?
    @Published public private(set) var isPresentingLaunchSurface = false
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

    public var selectedSession: LaunchSessionRecord? {
        guard let selectedSessionID else {
            return sessions.first
        }
        return sessions.first { $0.id == selectedSessionID } ?? sessions.first
    }

    public var selectedBenchmark: BenchmarkRecord? {
        guard let selectedBenchmarkID else {
            return benchmarkResults.first
        }
        return benchmarkResults.first { $0.id == selectedBenchmarkID } ?? benchmarkResults.first
    }

    public func selectContainer(id: UUID?) async {
        selectedContainerID = id
        do {
            try await reloadSelectionDetails()
        } catch {
            statusMessage = "Failed to load container details: \(error.localizedDescription)"
        }
    }

    public func selectSession(id: UUID?) {
        selectedSessionID = id
    }

    public func selectBenchmark(id: UUID?) {
        selectedBenchmarkID = id
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
                contentReference: contentReference,
                entryExecutableRelativePath: contentReference.originalFilename
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

    public func createHelloCubeContainer() async {
        isBusy = true
        defer { isBusy = false }

        capabilitySnapshot = capabilityDetector.detect()
        let request = GameLaunchRequest(
            title: "Hello Cube (DX11)",
            storefront: .localImport,
            acquisitionMode: .bundledSample,
            guestArchitecture: .windowsX64,
            requiresGraphicsTranslation: true,
            allowsInterpreterFallback: true,
            allowsDiagnosticVMFallback: false
        )
        let contentReference = ImportedContentReference(
            mode: .bundledSample,
            pathHint: "Samples/HelloCubeWindows",
            originalFilename: "Tutorial04.exe"
        )

        do {
            let created = try await coordinator.createContainer(
                request: request,
                capabilities: capabilitySnapshot.capabilities,
                productLane: capabilitySnapshot.productLane,
                contentReference: contentReference,
                entryExecutableRelativePath: "Debug/Tutorial04.exe"
            )
            selectedContainerID = created.descriptor.id
            planningDecision = created.planningDecision
            await refresh()
            statusMessage = "Created Hello Cube (DX11 Win32 sample)."
            if shouldAutoLaunchAfterCreate {
                await launchSelectedContainer()
            }
        } catch {
            statusMessage = "Create failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Stage 2: Hello Win32 console preset

    /// Creates a container for the bundled hello-win32.exe test payload.
    /// This uses real Wine (wine64) when available and produces real Windows
    /// CRT output in the runtime log surface.
    public func createHelloWin32Container() async {
        isBusy = true
        defer { isBusy = false }

        capabilitySnapshot = capabilityDetector.detect()

        // Resolve the exe path inside the app bundle so wine64 can find it.
        let exePath = Bundle.main.bundlePath
            .appending("/Payloads/hello-win32.exe")

        let request = GameLaunchRequest(
            title: "Hello Win32 (Console)",
            storefront: .localImport,
            acquisitionMode: .bundledSample,
            guestArchitecture: .windowsX64,
            requiresGraphicsTranslation: false,
            allowsInterpreterFallback: true,
            allowsDiagnosticVMFallback: false
        )
        let contentReference = ImportedContentReference(
            mode: .bundledSample,
            pathHint: exePath,
            originalFilename: "hello-win32.exe"
        )

        do {
            let created = try await coordinator.createContainer(
                request: request,
                capabilities: capabilitySnapshot.capabilities,
                productLane: capabilitySnapshot.productLane,
                contentReference: contentReference,
                entryExecutableRelativePath: nil  // pathHint IS the exe
            )
            selectedContainerID = created.descriptor.id
            planningDecision = created.planningDecision
            await refresh()
            statusMessage = "Created Hello Win32 (Stage-2 real Wine payload)."
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

    public func saveRuntimeProfile(
        backendPreference: ExecutionBackend,
        graphicsBackend: GraphicsBackend,
        touchOverlayEnabled: Bool,
        prefersPhysicalController: Bool,
        memoryBudgetMB: Int,
        shaderCacheBudgetMB: Int
    ) async {
        guard var selectedContainer else {
            statusMessage = "Select a container first."
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            selectedContainer.runtimeProfile = RuntimeProfile(
                backendPreference: backendPreference,
                graphicsBackend: graphicsBackend,
                touchOverlayEnabled: touchOverlayEnabled,
                prefersPhysicalController: prefersPhysicalController,
                memoryBudgetMB: max(256, memoryBudgetMB),
                shaderCacheBudgetMB: max(32, shaderCacheBudgetMB)
            )
            try await coordinator.updateContainer(selectedContainer)
            await refresh()
            self.selectedContainer = try await coordinator.loadContainer(id: selectedContainer.id)
            statusMessage = "Saved runtime settings for \"\(selectedContainer.title)\"."
        } catch {
            statusMessage = "Saving runtime settings failed: \(error.localizedDescription)"
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
            self.selectedSessionID = nil
            self.selectedBenchmarkID = nil
            self.resolvedContentPath = nil
            await refresh()
            statusMessage = "Deleted selected container."
        } catch {
            statusMessage = "Delete failed: \(error.localizedDescription)"
        }
    }

    public func dismissLaunchSurface() {
        isPresentingLaunchSurface = false
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
            activeSession = session
            containers = try await coordinator.listContainers()
            sessions = try await coordinator.sessions(for: selectedContainerID)
            selectedSessionID = sessions.first?.id
            benchmarkResults = try await coordinator.benchmarks(for: selectedContainerID)
            selectedBenchmarkID = benchmarkResults.first?.id
            planningDecision = try await coordinator.planLaunch(
                for: selectedContainerID,
                capabilities: capabilitySnapshot.capabilities,
                productLane: capabilitySnapshot.productLane
            )
            statusMessage = "Launch finished with state \(session.state.rawValue)."
            isPresentingLaunchSurface = true
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
            selectedSessionID = nil
            selectedBenchmarkID = nil
            resolvedContentPath = nil
            sessions = []
            benchmarkResults = []
            planningDecision = nil
            latestLog = ""
            activeSession = nil
            return
        }

        selectedContainer = try await coordinator.loadContainer(id: selectedContainerID)
        resolvedContentPath = try await coordinator.resolvedContentURL(for: selectedContainerID)?.path
        sessions = try await coordinator.sessions(for: selectedContainerID)
        if let selectedSessionID,
           sessions.contains(where: { $0.id == selectedSessionID }) {
            self.selectedSessionID = selectedSessionID
        } else {
            self.selectedSessionID = sessions.first?.id
        }

        benchmarkResults = try await coordinator.benchmarks(for: selectedContainerID)
        if let selectedBenchmarkID,
           benchmarkResults.contains(where: { $0.id == selectedBenchmarkID }) {
            self.selectedBenchmarkID = selectedBenchmarkID
        } else {
            self.selectedBenchmarkID = benchmarkResults.first?.id
        }
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
