import XCTest
@testable import CellarHost
@testable import CellarCore

final class BenchmarkStoreTests: XCTestCase {
    func testSaveAndLoadBenchmarkRecords() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let store = BenchmarkStore(rootURL: root)
        defer { try? FileManager.default.removeItem(at: root) }

        let containerID = UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!
        let record = BenchmarkRecord(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            sessionID: UUID(uuidString: "99999999-8888-7777-6666-555555555555")!,
            containerID: containerID,
            containerTitle: "Sample",
            contentMode: .managedCopy,
            backend: .wineARM64,
            productLane: .research,
            distributionChannel: .developerSigned,
            jitMode: .debuggerAttached,
            policyRisk: .low,
            hasIncreasedMemoryLimit: true,
            supportsMoltenVK: true,
            recordedAt: Date(timeIntervalSince1970: 1_700_000_123),
            metrics: LaunchSessionMetrics(
                startupDurationSeconds: 0.4,
                timeToInteractiveSeconds: 1.2,
                totalDurationSeconds: 4.6,
                logLineCount: 3,
                eventCount: 5,
                becameInteractive: true,
                exitedCleanly: true
            ),
            plannerWarnings: ["warning"],
            notes: ["note"]
        )

        try store.save(record)
        let loaded = try store.loadAll(containerID: containerID)

        XCTAssertEqual(loaded, [record])
    }
}
