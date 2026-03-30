import XCTest

/// Stage 3 E2E test: D3D11 capability probe via Wine.
///
/// Creates a container backed by `hello-d3d11-probe.exe` (a PE32+ binary that
/// calls D3D11CreateDevice), launches it through the real bridge, and verifies
/// that the probe reports `RESULT: PASS`.
///
/// ## Requirements
/// Same as `CellarWine2Test`: wine64 installed **and** wineserver pre-started.
/// See `CellarWine2Test` for full explanation and setup instructions.
@MainActor
final class D3D11ProbeTest: XCTestCase {

    static let wineSharedPrefix = CellarWine2Test.wineSharedPrefix

    override func setUpWithError() throws {
        try super.setUpWithError()
        let hasWine = FileManager.default.fileExists(atPath: "/opt/homebrew/bin/wine64")
            || FileManager.default.fileExists(atPath: "/usr/local/bin/wine64")
        try XCTSkipUnless(hasWine, "wine64 not installed — skipping D3D11 probe test")

        let pgrep = "/usr/bin/pgrep"
        var pargs: [UnsafeMutablePointer<CChar>?] = [
            strdup(pgrep), strdup("-q"), strdup("wineserver"), nil
        ]
        var ppid: pid_t = 0
        posix_spawn(&ppid, pgrep, nil, nil,
            pargs.withUnsafeBufferPointer { buf in
                UnsafeMutablePointer(mutating: buf.baseAddress!) }, nil)
        pargs.forEach { if let p = $0 { free(p) } }
        var pstat: Int32 = 0; waitpid(ppid, &pstat, 0)
        let hasServer = ((pstat >> 8) & 0xFF) == 0
        try XCTSkipUnless(hasServer,
            "No accessible wineserver. Run scripts/dev/prewarm-wine.sh first.")
    }

    func testD3D11ProbePassesViaWine() throws {
        let app = XCUIApplication()
        let rootPath = NSTemporaryDirectory().appending("CellarD3D11Test")
        app.launchEnvironment["CELLARKIT_ROOT_PATH"]            = rootPath
        app.launchEnvironment["CELLARKIT_DISTRIBUTION_CHANNEL"] = "developerSigned"
        app.launchEnvironment["CELLARKIT_DEBUGGER_ATTACHED"]    = "true"
        app.launchEnvironment["CELLARKIT_WINEPREFIX_OVERRIDE"]  = Self.wineSharedPrefix
        app.launch()

        XCTAssertTrue(app.navigationBars["CellarKit"].waitForExistence(timeout: 15))

        app.buttons["createD3D11ProbeButton"].tap()
        let status = app.staticTexts["statusMessage"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS[c] 'D3D11'"),
            object: status)], timeout: 15), .completed,
            "Create failed: \(status.label)")

        let launchBtn = app.buttons["launchSelectedButton"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == true"),
            object: launchBtn)], timeout: 5), .completed)
        launchBtn.tap()

        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS[c] 'Launch finished'"),
            object: status)], timeout: 90), .completed,
            "Launch timed out: \(status.label)")

        XCTAssertTrue(status.label.contains("exitedCleanly"),
            "Expected exitedCleanly: \(status.label)")

        for _ in 0..<4 { app.collectionViews.firstMatch.swipeUp() }
        sleep(1)

        let allText = app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: "\n")
        print("ALL_TEXT:\n\(allText)")
        XCTAssertTrue(allText.contains("RESULT: PASS"),
            "Expected 'RESULT: PASS' in log. Text:\n\(allText)")
    }
}
