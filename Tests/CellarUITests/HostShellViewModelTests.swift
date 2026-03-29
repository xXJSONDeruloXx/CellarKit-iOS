import XCTest
@testable import CellarUI
@testable import CellarHost
@testable import CellarCore

@MainActor
final class HostShellViewModelTests: XCTestCase {
    func testViewModelCreatesSampleContainerAndLaunchesIt() async {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }

        let coordinator = HostCoordinator(
            containerStore: ContainerStore(rootURL: root.appending(path: "Containers")),
            sessionStore: LaunchSessionStore(rootURL: root.appending(path: "Sessions")),
            bridge: SimulatedRuntimeBridge(
                startupDelay: .milliseconds(0),
                lineDelay: .milliseconds(0),
                logLines: ["ui boot", "ui frame"],
                interactiveMessage: "UI sample interactive",
                exitCode: 0
            )
        )
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
        XCTAssertEqual(model.latestLog, "ui boot\nui frame")
        XCTAssertTrue(model.statusMessage.contains("Launch finished"))
    }
}
