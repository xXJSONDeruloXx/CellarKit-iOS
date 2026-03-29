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
