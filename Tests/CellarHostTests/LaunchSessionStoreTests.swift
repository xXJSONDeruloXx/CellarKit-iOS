import XCTest
@testable import CellarHost
@testable import CellarCore

final class LaunchSessionStoreTests: XCTestCase {
    func testSaveLoadAndReadLog() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let store = LaunchSessionStore(rootURL: tempRoot)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let containerID = UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!
        let sessionID = UUID(uuidString: "11111111-aaaa-bbbb-cccc-222222222222")!
        let startedAt = Date(timeIntervalSince1970: 1_700_000_100)
        let record = LaunchSessionRecord(
            id: sessionID,
            containerID: containerID,
            containerTitle: "Sample Game",
            backend: .wineARM64,
            productLane: .research,
            policyRisk: .low,
            state: .exitedCleanly,
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(3),
            becameInteractiveAt: startedAt.addingTimeInterval(1),
            lastExitCode: 0,
            plannerWarnings: ["warning"],
            plannerRationale: ["rationale"],
            plannerNextSteps: ["next"],
            events: [
                LaunchSessionEvent(timestamp: startedAt, kind: .started, message: "Runtime started")
            ]
        )

        let persisted = try store.save(record, log: "line one\nline two")
        let loaded = try store.loadAll(containerID: containerID)
        let log = try store.loadLog(for: persisted)

        XCTAssertEqual(loaded, [persisted])
        XCTAssertEqual(log, "line one\nline two")
        XCTAssertNotNil(persisted.logRelativePath)
    }
}
