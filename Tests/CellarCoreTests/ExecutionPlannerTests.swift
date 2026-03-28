import XCTest
@testable import CellarCore

final class ExecutionPlannerTests: XCTestCase {
    private let planner = ExecutionPlanner()

    func testAppStoreStorefrontDownloadIsBlocked() {
        let capabilities = RuntimeCapabilities(
            distributionChannel: .appStore,
            jitMode: .none
        )
        let request = GameLaunchRequest(
            title: "Storefront x64 Game",
            storefront: .steam,
            acquisitionMode: .storefrontDownload,
            guestArchitecture: .windowsX64
        )

        let decision = planner.plan(request: request, capabilities: capabilities)

        XCTAssertEqual(decision.backend, .unsupported)
        XCTAssertEqual(decision.policyRisk, .blocked)
        XCTAssertFalse(decision.blockers.isEmpty)
    }

    func testDeveloperSignedX64WithDebuggerChoosesTranslator() {
        let capabilities = RuntimeCapabilities(
            distributionChannel: .developerSigned,
            jitMode: .debuggerAttached,
            hasIncreasedMemoryLimit: true,
            isDebuggerAttached: true
        )
        let request = GameLaunchRequest(
            title: "Imported x64 Game",
            storefront: .localImport,
            acquisitionMode: .localImport,
            guestArchitecture: .windowsX64
        )

        let decision = planner.plan(request: request, capabilities: capabilities)

        XCTAssertEqual(decision.backend, .wineX64Translator)
        XCTAssertEqual(decision.policyRisk, .low)
        XCTAssertTrue(decision.blockers.isEmpty)
    }

    func testAppStoreLocalImportArm64ChoosesArm64Backend() {
        let capabilities = RuntimeCapabilities(
            distributionChannel: .appStore,
            jitMode: .none
        )
        let request = GameLaunchRequest(
            title: "Imported ARM64 Game",
            storefront: .localImport,
            acquisitionMode: .localImport,
            guestArchitecture: .windowsARM64
        )

        let decision = planner.plan(request: request, capabilities: capabilities)

        XCTAssertEqual(decision.backend, .wineARM64)
        XCTAssertEqual(decision.policyRisk, .medium)
        XCTAssertTrue(decision.blockers.isEmpty)
    }

    func testNoJITX64FallsBackToInterpreterWhenAllowed() {
        let capabilities = RuntimeCapabilities(
            distributionChannel: .developerSigned,
            jitMode: .none
        )
        let request = GameLaunchRequest(
            title: "No JIT x64 Game",
            storefront: .localImport,
            acquisitionMode: .localImport,
            guestArchitecture: .windowsX64,
            allowsInterpreterFallback: true,
            allowsDiagnosticVMFallback: false
        )

        let decision = planner.plan(request: request, capabilities: capabilities)

        XCTAssertEqual(decision.backend, .wineThreadedInterpreter)
        XCTAssertTrue(decision.warnings.contains { $0.contains("threaded interpreter") })
    }

    func testNoJITX64CanChooseDiagnosticVMFallback() {
        let capabilities = RuntimeCapabilities(
            distributionChannel: .developerSigned,
            jitMode: .none
        )
        let request = GameLaunchRequest(
            title: "Diagnostic VM x64 Game",
            storefront: .localImport,
            acquisitionMode: .localImport,
            guestArchitecture: .windowsX64,
            allowsInterpreterFallback: false,
            allowsDiagnosticVMFallback: true
        )

        let decision = planner.plan(request: request, capabilities: capabilities)

        XCTAssertEqual(decision.backend, .diagnosticVM)
        XCTAssertTrue(decision.blockers.isEmpty)
    }
}
