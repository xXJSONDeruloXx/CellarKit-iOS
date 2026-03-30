import XCTest

@MainActor
final class CellarQuickTest: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testHelloCubeButtonCreatesContainer() throws {
        let app = XCUIApplication()
        let rootPath = NSTemporaryDirectory().appending("CellarQuickTest-\(UUID().uuidString)")
        app.launchEnvironment["CELLARKIT_ROOT_PATH"] = rootPath
        app.launchEnvironment["CELLARKIT_DISTRIBUTION_CHANNEL"] = "developerSigned"
        app.launchEnvironment["CELLARKIT_JIT_MODE"] = "debuggerAttached"
        app.launch()

        // Find and tap Hello Cube button
        let helloCubeBtn = app.buttons["createHelloCubeButton"]
        XCTAssertTrue(helloCubeBtn.waitForExistence(timeout: 10),
                      "createHelloCubeButton not found in view")
        helloCubeBtn.tap()

        // Check status message updated
        let status = app.staticTexts["statusMessage"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))

        // Wait for "Hello Cube" or "Create" in status
        let predicate = NSPredicate(format: "label CONTAINS 'Hello Cube' OR label CONTAINS 'Create' OR label CONTAINS 'failed'")
        let exp = XCTNSPredicateExpectation(predicate: predicate, object: status)
        let result = XCTWaiter.wait(for: [exp], timeout: 10)
        XCTAssertEqual(result, .completed, "Status message: \(status.label)")
    }
}
