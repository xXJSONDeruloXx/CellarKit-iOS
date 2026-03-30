import XCTest

/// Stage 2 real-Wine E2E test.
///
/// Verifies that tapping "Hello Win32" creates a container backed by a real
/// bundled Windows PE binary (hello-win32.exe), launches it via wine64, and
/// that the launch completes cleanly with actual Windows CRT output in the
/// session log.
///
/// Requirements:
/// - wine64 must be installed at a location the bridge can discover
///   (e.g. /opt/homebrew/bin/wine64 via `brew install --cask wine-crossover`).
/// - The app must be built with the "Bundle test payloads" build phase so
///   hello-win32.exe is present at <Bundle>/Payloads/hello-win32.exe.
///
/// This test is intentionally separate from CellarKitE2ETests so it can be
/// skipped on CI environments without Wine installed.
@MainActor
final class CellarWine2Test: XCTestCase {

    override func setUp() {
        super.setUp()
        // Skip immediately on machines without wine64.
        let haswine = FileManager.default.fileExists(atPath: "/opt/homebrew/bin/wine64")
            || FileManager.default.fileExists(atPath: "/usr/local/bin/wine64")
        try XCTSkipUnless(haswine, "wine64 not installed — skipping Stage-2 test")
    }

    func testHelloWin32LaunchesAndExitsCleanly() throws {
        let app = XCUIApplication()
        let rootPath = NSTemporaryDirectory().appending("CellarWine2Test")
        app.launchEnvironment["CELLARKIT_ROOT_PATH"]              = rootPath
        app.launchEnvironment["CELLARKIT_DISTRIBUTION_CHANNEL"]   = "developerSigned"
        app.launchEnvironment["CELLARKIT_DEBUGGER_ATTACHED"]      = "true"
        app.launch()

        XCTAssertTrue(app.navigationBars["CellarKit"].waitForExistence(timeout: 15),
                      "Root nav bar not visible")

        // ── Create ──────────────────────────────────────────────────────────
        let createBtn = app.buttons["createHelloWin32Button"]
        XCTAssertTrue(createBtn.waitForExistence(timeout: 5),
                      "createHelloWin32Button not found")
        createBtn.tap()

        let status = app.staticTexts["statusMessage"]
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label CONTAINS[c] 'Hello Win32'"),
                object: status)], timeout: 15),
            .completed,
            "Container creation did not complete: \(status.label)"
        )

        // ── Launch ──────────────────────────────────────────────────────────
        let launchBtn = app.buttons["launchSelectedButton"]
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "enabled == true"),
                object: launchBtn)], timeout: 5),
            .completed,
            "Launch button never became enabled"
        )
        launchBtn.tap()

        // Wine initializes a prefix on first run — allow up to 60 seconds.
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label CONTAINS[c] 'Launch finished'"),
                object: status)], timeout: 60),
            .completed,
            "Launch timed out: \(status.label)"
        )

        // ── Verify exit state ────────────────────────────────────────────────
        XCTAssertTrue(
            status.label.contains("exitedCleanly"),
            "Expected exitedCleanly but got: \(status.label)"
        )

        // ── Scroll to log section and verify Windows CRT output ──────────────
        let list = app.collectionViews.firstMatch
        for _ in 0..<4 { list.swipeUp() }
        sleep(1)

        // The runtime log text element accumulates all log lines joined by newlines.
        let allText = app.staticTexts.allElementsBoundByIndex
            .map(\.label)
            .joined(separator: "\n")

        XCTAssertTrue(
            allText.contains("Hello from Windows!"),
            "Expected 'Hello from Windows!' in log output.\nVisible text:\n\(allText)"
        )
    }
}
