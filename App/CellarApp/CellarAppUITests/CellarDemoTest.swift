import XCTest

/// One-shot demo test: creates Hello Cube, launches it, leaves the spinning
/// cube surface open so the user can see it on the simulator screen.
@MainActor
final class CellarDemoTest: XCTestCase {
    func testShowSpinningCubeLive() throws {
        let app = XCUIApplication()
        // Use a clean temp dir — no pre-existing containers, no race conditions
        let rootPath = NSTemporaryDirectory().appending("CellarDemo-Live")
        app.launchEnvironment["CELLARKIT_ROOT_PATH"] = rootPath
        app.launchEnvironment["CELLARKIT_DISTRIBUTION_CHANNEL"] = "developerSigned"
        app.launchEnvironment["CELLARKIT_JIT_MODE"] = "debuggerAttached"
        app.launchEnvironment["CELLARKIT_DEBUGGER_ATTACHED"] = "true"
        app.launch()

        // Wait for app to be ready
        XCTAssertTrue(app.navigationBars["CellarKit"].waitForExistence(timeout: 15))

        // Tap Hello Cube DX11
        let helloCubeBtn = app.buttons["createHelloCubeButton"]
        XCTAssertTrue(helloCubeBtn.waitForExistence(timeout: 10))
        helloCubeBtn.tap()

        // Wait for status to say "Created Hello Cube" — this guarantees isBusy=false
        let status = app.staticTexts["statusMessage"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertTrue(
            status.waitForSubstring("Created Hello Cube", timeout: 15),
            "Expected container created, got: \(status.label)"
        )

        // Wait for launch button to be enabled (isBusy=false and container selected)
        let launchBtn = app.buttons["launchSelectedButton"]
        XCTAssertTrue(launchBtn.waitForExistence(timeout: 5))
        let enabledPredicate = NSPredicate(format: "enabled == true")
        let enabledExp = XCTNSPredicateExpectation(predicate: enabledPredicate, object: launchBtn)
        XCTAssertEqual(XCTWaiter.wait(for: [enabledExp], timeout: 5), .completed,
                       "Launch button should be enabled after container created")

        // Launch it
        launchBtn.tap()

        // Wait for launch to complete
        XCTAssertTrue(
            status.waitForSubstring("Launch finished", timeout: 20),
            "Launch did not finish: \(status.label)"
        )

        // Launch surface sheet should be up — leave it open so user can see spinning cube
        let doneBtn = app.buttons["Done"]
        XCTAssertTrue(
            doneBtn.waitForExistence(timeout: 10),
            "Launch surface sheet did not appear"
        )

        // Hold the launch surface open for 45 seconds
        sleep(45)

        XCTAssertTrue(true)
    }
}

private extension XCUIElement {
    func waitForSubstring(_ substring: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", substring)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
