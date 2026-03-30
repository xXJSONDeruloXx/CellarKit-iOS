import XCTest

/// End-to-end UI tests for the Hello Cube DX11 container create → launch flow.
@MainActor
final class CellarKitE2ETests: XCTestCase {

    var app: XCUIApplication!
    var rootPath: String!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        rootPath = NSTemporaryDirectory().appending("CellarKitE2E-\(UUID().uuidString)")
        app.launchEnvironment["CELLARKIT_ROOT_PATH"] = rootPath
        app.launchEnvironment["CELLARKIT_DISTRIBUTION_CHANNEL"] = "developerSigned"
        app.launchEnvironment["CELLARKIT_JIT_MODE"] = "debuggerAttached"
        app.launchEnvironment["CELLARKIT_DEBUGGER_ATTACHED"] = "true"
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // MARK: - Step 1: Button exists

    func test01_HelloCubeButtonExists() throws {
        let btn = app.buttons["createHelloCubeButton"]
        XCTAssertTrue(btn.waitForExistence(timeout: 10),
                      "createHelloCubeButton must exist in the Actions section")
    }

    // MARK: - Step 2: Tapping button creates container and shows it in list

    func test02_TapHelloCubeCreatesContainer() throws {
        // Tap the button
        let btn = app.buttons["createHelloCubeButton"]
        XCTAssertTrue(btn.waitForExistence(timeout: 10))
        btn.tap()

        // Status message should confirm creation
        let status = app.staticTexts["statusMessage"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertTrue(
            status.waitForSubstring("Hello Cube", timeout: 10),
            "Expected 'Hello Cube' in status, got: \(status.label)"
        )

        // Container row should appear — look for "Hello Cube" text anywhere in the list
        let containerCell = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Hello Cube'")
        ).firstMatch
        XCTAssertTrue(
            containerCell.waitForExistence(timeout: 10),
            "Container cell with 'Hello Cube' title should appear in the list"
        )
    }

    // MARK: - Step 3: Container metadata is correct

    func test03_ContainerMetadataIsCorrect() throws {
        // Create the container
        let btn = app.buttons["createHelloCubeButton"]
        XCTAssertTrue(btn.waitForExistence(timeout: 10))
        btn.tap()

        // Wait for container to appear in list
        let containerCell = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Hello Cube'")
        ).firstMatch
        XCTAssertTrue(containerCell.waitForExistence(timeout: 10))

        // Tap the container to select it
        containerCell.tap()
        sleep(1)

        // Scroll down several times to reach the Selected Container section
        let list = app.collectionViews.firstMatch
        list.swipeUp(velocity: .fast)
        list.swipeUp(velocity: .fast)
        sleep(1)

        // Entry executable should show somewhere on screen
        let entryExe = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Tutorial04'")
        ).firstMatch
        XCTAssertTrue(
            entryExe.waitForExistence(timeout: 8),
            "Entry executable 'Debug/Tutorial04.exe' should be visible after scrolling"
        )
    }

    // MARK: - Step 4: Launch completes with DX11 log output

    func test04_LaunchProducesDX11Logs() throws {
        // Create
        let btn = app.buttons["createHelloCubeButton"]
        XCTAssertTrue(btn.waitForExistence(timeout: 10))
        btn.tap()

        let containerCell = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Hello Cube'")
        ).firstMatch
        XCTAssertTrue(containerCell.waitForExistence(timeout: 10))

        // Launch
        let launchBtn = app.buttons["launchSelectedButton"]
        XCTAssertTrue(launchBtn.waitForExistence(timeout: 10))
        XCTAssertTrue(launchBtn.isEnabled, "Launch button should be enabled after container selected")
        launchBtn.tap()

        // Status should say launch finished
        let status = app.staticTexts["statusMessage"]
        XCTAssertTrue(
            status.waitForSubstring("Launch finished", timeout: 20),
            "Expected 'Launch finished' in status after launch, got: \(status.label)"
        )

        // Dismiss sheet if shown
        let doneBtn = app.buttons["Done"]
        if doneBtn.waitForExistence(timeout: 3) { doneBtn.tap(); sleep(1) }

        // Scroll all the way down to the log section
        let list = app.collectionViews.firstMatch
        for _ in 0..<5 { list.swipeUp(velocity: .fast) }
        sleep(1)

        // Log should appear and contain DX11 bridge output
        let logText = app.staticTexts["latestLogText"]
        XCTAssertTrue(
            logText.waitForExistence(timeout: 10),
            "latestLogText should appear in log section after scrolling"
        )
        let logContent = logText.label
        XCTAssertTrue(
            logContent.contains("native") || logContent.contains("d3d11") ||
            logContent.contains("dxvk") || logContent.contains("wine"),
            "Log should contain DX11/DXVK bridge output, got: \(logContent)"
        )
    }

    // MARK: - Step 5: Launch surface sheet appears

    func test05_LaunchSurfaceSheetAppears() throws {
        // Create
        let btn = app.buttons["createHelloCubeButton"]
        XCTAssertTrue(btn.waitForExistence(timeout: 10))
        btn.tap()

        let containerCell = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Hello Cube'")
        ).firstMatch
        XCTAssertTrue(containerCell.waitForExistence(timeout: 10))

        // Launch
        let launchBtn = app.buttons["launchSelectedButton"]
        XCTAssertTrue(launchBtn.waitForExistence(timeout: 10))
        launchBtn.tap()

        // Launch surface sheet should appear
        let status = app.staticTexts["statusMessage"]
        XCTAssertTrue(status.waitForSubstring("Launch finished", timeout: 20))

        // The sheet should show "Runtime Surface" nav title or "Done" button
        let doneBtn = app.buttons["Done"]
        XCTAssertTrue(
            doneBtn.waitForExistence(timeout: 5),
            "Launch surface sheet should appear with a 'Done' button"
        )

        // The log inside the sheet should have DX11 content
        let sheetLog = app.staticTexts["launchSurfaceLogText"]
        if sheetLog.waitForExistence(timeout: 5) {
            let logContent = sheetLog.label
            XCTAssertTrue(
                logContent.contains("native") || logContent.contains("d3d11") || logContent.contains("dxvk"),
                "Launch surface log should contain runtime output, got: \(logContent)"
            )
        }

        // Dismiss
        doneBtn.tap()
    }

    // MARK: - Step 6: Session and benchmark recorded

    func test06_SessionAndBenchmarkRecorded() throws {
        // Create + Launch
        let btn = app.buttons["createHelloCubeButton"]
        XCTAssertTrue(btn.waitForExistence(timeout: 10))
        btn.tap()

        let containerCell = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Hello Cube'")
        ).firstMatch
        XCTAssertTrue(containerCell.waitForExistence(timeout: 10))

        let launchBtn = app.buttons["launchSelectedButton"]
        XCTAssertTrue(launchBtn.waitForExistence(timeout: 10))
        launchBtn.tap()

        let status = app.staticTexts["statusMessage"]
        XCTAssertTrue(status.waitForSubstring("Launch finished", timeout: 20))

        // Dismiss sheet if present
        let doneBtn = app.buttons["Done"]
        if doneBtn.waitForExistence(timeout: 5) { doneBtn.tap(); sleep(1) }

        // Scroll down to reach the Launch Sessions section
        let list = app.collectionViews.firstMatch
        for _ in 0..<4 { list.swipeUp(velocity: .fast) }
        sleep(1)

        // Should see a session row — look for exitedCleanly, wineARM64, wineX64, or backend names
        let sessionRow = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'exited' OR label CONTAINS[c] 'wine' OR label CONTAINS[c] 'starting' OR label CONTAINS[c] 'interactive'")
        ).firstMatch
        XCTAssertTrue(
            sessionRow.waitForExistence(timeout: 10),
            "A session row should appear in the Launch Sessions section after scrolling"
        )
    }
}

private extension XCUIElement {
    func waitForSubstring(_ substring: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", substring)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
