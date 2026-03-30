import XCTest

/// Quick diagnostic: dumps the live accessibility tree so we can see exactly
/// what buttons/texts are reachable from a fresh app launch.
///
/// Run with:
///   xcodebuild test -only-testing:CellarAppUITests/CellarDiagnosticTest/testDumpAccessibilityTree
@MainActor
final class CellarDiagnosticTest: XCTestCase {
    func testDumpAccessibilityTree() throws {
        let app = XCUIApplication()
        let rootPath = NSTemporaryDirectory().appending("CellarDiag-\(UUID().uuidString)")
        app.launchEnvironment["CELLARKIT_ROOT_PATH"] = rootPath
        app.launchEnvironment["CELLARKIT_DISTRIBUTION_CHANNEL"] = "developerSigned"
        app.launchEnvironment["CELLARKIT_JIT_MODE"] = "debuggerAttached"
        app.launchEnvironment["CELLARKIT_DEBUGGER_ATTACHED"] = "true"
        app.launch()

        XCTAssertTrue(app.navigationBars["CellarKit"].waitForExistence(timeout: 15))

        print("=== ALL BUTTONS ===")
        for b in app.buttons.allElementsBoundByIndex {
            print("  '\(b.label)' id='\(b.identifier)' enabled=\(b.isEnabled) exists=\(b.exists)")
        }
        XCTAssertTrue(true)
        app.terminate()
    }
}
