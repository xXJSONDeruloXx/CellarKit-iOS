import XCTest
@testable import CellarHost
@testable import CellarCore

final class HostCapabilityDetectorTests: XCTestCase {
    func testDetectorRespectsEnvironmentOverrides() {
        let detector = HostCapabilityDetector(
            environment: [
                "CELLARKIT_PRODUCT_LANE": "constrainedPublic",
                "CELLARKIT_DISTRIBUTION_CHANNEL": "testFlight",
                "CELLARKIT_JIT_MODE": "threadedInterpreter",
                "CELLARKIT_DEBUGGER_ATTACHED": "true",
                "CELLARKIT_INCREASED_MEMORY_LIMIT": "true",
                "CELLARKIT_SUPPORTS_MOLTENVK": "false",
                "CELLARKIT_SUPPORTS_BOOKMARKS": "false",
                "CELLARKIT_SUPPORTS_BACKGROUND_FETCH": "false"
            ]
        )

        let snapshot = detector.detect()

        XCTAssertEqual(snapshot.productLane, .constrainedPublic)
        XCTAssertEqual(snapshot.capabilities.distributionChannel, .testFlight)
        XCTAssertEqual(snapshot.capabilities.jitMode, .threadedInterpreter)
        XCTAssertTrue(snapshot.capabilities.hasIncreasedMemoryLimit)
        XCTAssertFalse(snapshot.capabilities.supportsMoltenVK)
        XCTAssertFalse(snapshot.capabilities.supportsSecurityScopedBookmarks)
        XCTAssertFalse(snapshot.capabilities.supportsBackgroundAssetFetch)
        XCTAssertTrue(snapshot.capabilities.isDebuggerAttached)
        XCTAssertTrue(snapshot.notes.contains { $0.contains("overridden") })
    }

    func testDetectorInfersSimulatorCapabilities() {
        let detector = HostCapabilityDetector(
            environment: [
                "SIMULATOR_DEVICE_NAME": "iPhone 16 Pro"
            ]
        )

        let snapshot = detector.detect()

        XCTAssertEqual(snapshot.productLane, .research)
        XCTAssertEqual(snapshot.capabilities.distributionChannel, .simulator)
        XCTAssertEqual(snapshot.capabilities.jitMode, .nativeEntitlement)
        XCTAssertTrue(snapshot.notes.contains { $0.contains("simulator") })
    }
}
