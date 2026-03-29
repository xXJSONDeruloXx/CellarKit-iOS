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
        app.launchEnvironment["CELLARKIT_AUTOLAUNCH_AFTER_CREATE"] = "true"
        app.launch()

        let createButton = app.buttons["createSampleButton"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 10))
        createButton.tap()

        let statusMessage = app.staticTexts["statusMessage"]
        XCTAssertTrue(statusMessage.waitForExistence(timeout: 10))
        XCTAssertTrue(
            statusMessage.waitForSubstring("Launch finished", timeout: 20),
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
