import XCTest
@testable import CellarUI
@testable import CellarHost
@testable import CellarCore

@MainActor
final class HostShellViewModelTests: XCTestCase {
    func testViewModelCreatesSampleContainerAndLaunchesIt() async {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let coordinator = makeCoordinator(root: root)
        let detector = HostCapabilityDetector(
            environment: [
                "CELLARKIT_DISTRIBUTION_CHANNEL": "developerSigned",
                "CELLARKIT_JIT_MODE": "debuggerAttached",
                "CELLARKIT_DEBUGGER_ATTACHED": "true"
            ]
        )
        let model = HostShellViewModel(
            paths: HostShellPaths(rootURL: root),
            capabilityDetector: detector,
            coordinator: coordinator
        )

        await model.refresh()
        XCTAssertTrue(model.containers.isEmpty)

        await model.createSampleContainer(title: "UI Probe")
        XCTAssertEqual(model.containers.count, 1)
        XCTAssertNotNil(model.planningDecision)
        XCTAssertNotNil(model.selectedContainerID)

        await model.launchSelectedContainer()
        XCTAssertEqual(model.sessions.count, 1)
        XCTAssertEqual(model.benchmarkResults.count, 1)
        XCTAssertNotNil(model.activeSession)
        XCTAssertTrue(model.isPresentingLaunchSurface)
        XCTAssertNotNil(model.selectedSession)
        XCTAssertNotNil(model.selectedBenchmark)
        XCTAssertEqual(model.latestLog, "ui boot\nui frame")
        XCTAssertTrue(model.statusMessage.contains("Launch finished"))
    }

    func testViewModelImportsManagedCopyPayload() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let sourceURL = root.appending(path: "ImportedGame.exe")
        try Data("payload".utf8).write(to: sourceURL)

        let model = HostShellViewModel(
            paths: HostShellPaths(rootURL: root),
            capabilityDetector: HostCapabilityDetector(
                environment: [
                    "CELLARKIT_DISTRIBUTION_CHANNEL": "developerSigned",
                    "CELLARKIT_JIT_MODE": "none"
                ]
            ),
            coordinator: makeCoordinator(root: root)
        )

        await model.refresh()
        await model.importPayload(from: sourceURL)

        XCTAssertEqual(model.containers.count, 1)
        XCTAssertEqual(model.containers.first?.contentReference?.mode, .managedCopy)
        XCTAssertTrue(model.containers.first?.importPath?.hasSuffix("ImportedGame.exe") == true)
        XCTAssertTrue(model.statusMessage.contains("Imported payload"))
    }

    func testViewModelRenamesAndDeletesSelectedContainer() async {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let model = HostShellViewModel(
            paths: HostShellPaths(rootURL: root),
            capabilityDetector: HostCapabilityDetector(
                environment: [
                    "CELLARKIT_DISTRIBUTION_CHANNEL": "developerSigned",
                    "CELLARKIT_JIT_MODE": "debuggerAttached",
                    "CELLARKIT_DEBUGGER_ATTACHED": "true"
                ]
            ),
            coordinator: makeCoordinator(root: root)
        )

        await model.refresh()
        await model.createSampleContainer(title: "Before Rename")
        XCTAssertEqual(model.containers.first?.title, "Before Rename")

        await model.renameSelectedContainer(to: "After Rename")
        XCTAssertEqual(model.selectedContainer?.title, "After Rename")

        await model.deleteSelectedContainer()
        XCTAssertTrue(model.containers.isEmpty)
        XCTAssertNil(model.selectedContainer)
        XCTAssertTrue(model.statusMessage.contains("Deleted selected container"))
    }

    func testViewModelSavesRuntimeProfileChanges() async {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let model = HostShellViewModel(
            paths: HostShellPaths(rootURL: root),
            capabilityDetector: HostCapabilityDetector(
                environment: [
                    "CELLARKIT_DISTRIBUTION_CHANNEL": "developerSigned",
                    "CELLARKIT_JIT_MODE": "none"
                ]
            ),
            coordinator: makeCoordinator(root: root)
        )

        await model.refresh()
        await model.createSampleContainer(title: "Settings Target")
        await model.saveRuntimeProfile(
            backendPreference: .wineThreadedInterpreter,
            graphicsBackend: .wined3dFallback,
            touchOverlayEnabled: false,
            prefersPhysicalController: false,
            memoryBudgetMB: 1024,
            shaderCacheBudgetMB: 128
        )

        XCTAssertEqual(model.selectedContainer?.runtimeProfile.backendPreference, .wineThreadedInterpreter)
        XCTAssertEqual(model.selectedContainer?.runtimeProfile.graphicsBackend, .wined3dFallback)
        XCTAssertEqual(model.selectedContainer?.runtimeProfile.memoryBudgetMB, 1024)
        XCTAssertEqual(model.selectedContainer?.runtimeProfile.shaderCacheBudgetMB, 128)
        XCTAssertEqual(model.selectedContainer?.runtimeProfile.touchOverlayEnabled, false)
        XCTAssertEqual(model.selectedContainer?.runtimeProfile.prefersPhysicalController, false)
        XCTAssertTrue(model.statusMessage.contains("Saved runtime settings"))
    }

    func testViewModelLinksExternalPayload() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let sourceURL = root.appending(path: "LinkedFolder")
        try FileManager.default.createDirectory(at: sourceURL, withIntermediateDirectories: true)

        let model = HostShellViewModel(
            paths: HostShellPaths(rootURL: root),
            capabilityDetector: HostCapabilityDetector(
                environment: [
                    "CELLARKIT_DISTRIBUTION_CHANNEL": "developerSigned",
                    "CELLARKIT_JIT_MODE": "none"
                ]
            ),
            coordinator: makeCoordinator(root: root)
        )

        await model.refresh()
        await model.importPayload(from: sourceURL, mode: .externalSecurityScopedReference)

        XCTAssertEqual(model.containers.count, 1)
        XCTAssertEqual(model.containers.first?.contentReference?.mode, .externalSecurityScopedReference)
        XCTAssertNotNil(model.containers.first?.contentReference?.bookmarkIdentifier)
        XCTAssertTrue(model.statusMessage.contains("Linked external payload"))
    }

    private func makeCoordinator(root: URL) -> HostCoordinator {
        HostCoordinator(
            containerStore: ContainerStore(rootURL: root.appending(path: "Containers")),
            sessionStore: LaunchSessionStore(rootURL: root.appending(path: "Sessions")),
            benchmarkStore: BenchmarkStore(rootURL: root.appending(path: "Benchmarks")),
            contentImporter: ContentImportCoordinator(
                managedContentRootURL: root.appending(path: "ManagedContent"),
                bookmarkStore: BookmarkStore(rootURL: root.appending(path: "Bookmarks"))
            ),
            bridge: SimulatedRuntimeBridge(
                startupDelay: .milliseconds(0),
                lineDelay: .milliseconds(0),
                logLines: ["ui boot", "ui frame"],
                interactiveMessage: "UI sample interactive",
                exitCode: 0
            )
        )
    }
}
