import XCTest

@MainActor
final class CellarAppUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCreateAndLaunchSampleFlow() throws {
        let app = XCUIApplication()
        let rootPath = NSTemporaryDirectory().appending("CellarAppUITests-\(UUID().uuidString)")
        app.launchEnvironment["CELLARKIT_ROOT_PATH"] = rootPath
        app.launchEnvironment["CELLARKIT_DISTRIBUTION_CHANNEL"] = "developerSigned"
        app.launchEnvironment["CELLARKIT_JIT_MODE"] = "debuggerAttached"
        app.launchEnvironment["CELLARKIT_DEBUGGER_ATTACHED"] = "true"
        app.launch()

        let createButton = app.buttons["createSampleButton"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 10))
        createButton.tap()

        let statusMessage = app.staticTexts["statusMessage"]
        XCTAssertTrue(statusMessage.waitForExistence(timeout: 10))
        XCTAssertTrue(
            statusMessage.waitForSubstring("Loaded 1 container", timeout: 10),
            "Expected status message to confirm the created container was reloaded, got: \(statusMessage.label)"
        )

        let launchButton = app.buttons["launchSelectedButton"]
        XCTAssertTrue(launchButton.waitForExistence(timeout: 5))
        launchButton.tap()

        XCTAssertTrue(
            statusMessage.waitForSubstring("Launch finished", timeout: 10),
            "Expected status message to confirm launch completion, got: \(statusMessage.label)"
        )
    }
}

private extension XCUIElement {
    func waitForSubstring(_ substring: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", substring)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
