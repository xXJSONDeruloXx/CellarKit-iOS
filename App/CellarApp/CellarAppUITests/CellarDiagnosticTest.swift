import XCTest

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

        // Wait for app to be ready — look for nav bar
        let navBar = app.navigationBars["CellarKit"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 15), "Navigation bar should appear")
        print("Nav bar appeared at \(Date())")

        // Check button states
        let btn = app.buttons["createHelloCubeButton"]
        print("Button exists immediately: \(btn.exists)")
        print("Button enabled: \(btn.isEnabled)")
        print("isBusy (button disabled): \(!btn.isEnabled)")

        // Wait for button to be enabled (isBusy = false)
        let enabledPredicate = NSPredicate(format: "enabled == true")
        let exp = XCTNSPredicateExpectation(predicate: enabledPredicate, object: btn)
        let result = XCTWaiter.wait(for: [exp], timeout: 10)
        print("Button became enabled: \(result == .completed)")

        // All buttons
        print("=== ALL BUTTONS ===")
        for b in app.buttons.allElementsBoundByIndex {
            print("  '\(b.label)' id='\(b.identifier)' enabled=\(b.isEnabled) exists=\(b.exists)")
        }
        XCTAssertTrue(true)
        app.terminate()
    }
}
