import XCTest

/// Stage 2 real-Wine E2E test.
///
/// Verifies that tapping "Hello Win32" creates a container backed by a real
/// bundled Windows PE binary (hello-win32.exe), launches it via wine64, and
/// that the launch completes cleanly with actual Windows CRT output in the
/// session log.
///
/// ## Requirements
/// Wine64 (CrossOver or WineHQ) must be installed **and a wineserver must be
/// running from outside the iOS simulator's bootstrap namespace** before this
/// test runs.
///
/// ### Why a pre-started wineserver?
/// CrossOver Wine uses Mach port IPC for wineserver ↔ client communication.
/// The iOS simulator creates a separate launchd bootstrap namespace; processes
/// spawned inside it (including wine64 from the bridge) cannot register or
/// look up Mach services in the host bootstrap.  A wineserver started from
/// the macOS terminal (or a CI pre-step) has the host bootstrap port and can
/// register its service; the in-sim wine64 client then connects successfully.
///
/// ### How to pre-start the wineserver
/// ```bash
/// scripts/dev/prewarm-wine.sh   # starts wineserver for 120 s
/// ```
/// or from any macOS terminal:
/// ```bash
/// WINEPREFIX=/private/tmp/cellarkit-wine/shared \
///   wine64 wineboot --init
/// ```
/// The test automatically skips when wine64 is not installed or when the
/// server cannot be reached.
@MainActor
final class CellarWine2Test: XCTestCase {

    /// Shared WINEPREFIX used by both the pre-warm helper and the app-under-test.
    static let wineSharedPrefix = "/private/tmp/cellarkit-wine/shared"

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Skip on machines without wine64.
        let wine64  = "/opt/homebrew/bin/wine64"
        let wine64b = "/usr/local/bin/wine64"
        let haswine = FileManager.default.fileExists(atPath: wine64)
            || FileManager.default.fileExists(atPath: wine64b)
        try XCTSkipUnless(haswine, "wine64 not installed — skipping Stage-2 test")

        // Skip if there is no accessible wineserver.
        // The bridge spawns wine64 inside the iOS simulator's launchd bootstrap
        // namespace, which prevents CrossOver's wineserver from registering its
        // Mach port.  A wineserver started from the macOS host (terminal, CI
        // script, or `scripts/dev/prewarm-wine.sh`) works fine.
        let hasServer = wineserverIsAccessible()
        try XCTSkipUnless(hasServer,
            "No accessible wineserver. Run scripts/dev/prewarm-wine.sh first.")
    }

    /// Returns true if a wineserver process is currently running.
    nonisolated private func wineserverIsAccessible() -> Bool {
        // Use `pgrep -q wineserver` — a simple macOS process search that
        // works even from within the iOS simulator's process context.
        let pgrep = "/usr/bin/pgrep"
        guard FileManager.default.fileExists(atPath: pgrep) else { return false }
        var args: [UnsafeMutablePointer<CChar>?] = [
            strdup(pgrep), strdup("-q"), strdup("wineserver"), nil
        ]
        defer { args.forEach { if let p = $0 { free(p) } } }
        var pid: pid_t = 0
        let spawnRC = posix_spawn(&pid, pgrep, nil, nil,
            args.withUnsafeBufferPointer { buf in
                UnsafeMutablePointer(mutating: buf.baseAddress!) }, nil)
        guard spawnRC == 0 else { return false }
        var status: Int32 = 0
        waitpid(pid, &status, 0)
        // pgrep exit code 0 = found, 1 = not found
        // status layout: (exit_code << 8) | signal
        let exitCode = (status >> 8) & 0xFF
        return exitCode == 0
    }

    func testHelloWin32LaunchesAndExitsCleanly() throws {
        let app = XCUIApplication()
        let rootPath = NSTemporaryDirectory().appending("CellarWine2Test")
        app.launchEnvironment["CELLARKIT_ROOT_PATH"]             = rootPath
        app.launchEnvironment["CELLARKIT_DISTRIBUTION_CHANNEL"]  = "developerSigned"
        app.launchEnvironment["CELLARKIT_DEBUGGER_ATTACHED"]     = "true"
        // Point the app to the pre-warmed prefix so wine64 reuses the server.
        app.launchEnvironment["CELLARKIT_WINEPREFIX_OVERRIDE"]   = Self.wineSharedPrefix
        app.launch()

        XCTAssertTrue(app.navigationBars["CellarKit"].waitForExistence(timeout: 15),
                      "Root nav bar not visible")

        // ── Create ──────────────────────────────────────────────────────────
        let createBtn = app.buttons["createHelloWin32Button"]
        XCTAssertTrue(createBtn.waitForExistence(timeout: 5),
                      "createHelloWin32Button not found")
        createBtn.tap()

        let status = app.staticTexts["statusMessage"]
        let createPredicate = NSPredicate(format: "label CONTAINS[c] 'Hello Win32'")
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: createPredicate,
                                                            object: status)],
                           timeout: 15), .completed,
            "Create status never showed 'Hello Win32': \(status.label)")

        // ── Launch ──────────────────────────────────────────────────────────
        let launchBtn = app.buttons["launchSelectedButton"]
        let enabledPred = NSPredicate(format: "enabled == true")
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: enabledPred,
                                                            object: launchBtn)],
                           timeout: 5), .completed,
            "launchSelectedButton never enabled")
        launchBtn.tap()

        // ── Wait for exit ────────────────────────────────────────────────────
        // Wine prefix initialisation + hello-win32.exe ≈ 5-25 s
        let finishPredicate = NSPredicate(format: "label CONTAINS[c] 'Launch finished'")
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: finishPredicate,
                                                            object: status)],
                           timeout: 90), .completed,
            "Launch never finished: \(status.label)")

        XCTAssertTrue(status.label.contains("exitedCleanly"),
            "Expected exitedCleanly but got: \(status.label)")

        // ── Verify log output ────────────────────────────────────────────────
        for _ in 0..<4 { app.collectionViews.firstMatch.swipeUp() }
        sleep(1)
        let allText = app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: "\n")
        XCTAssertTrue(allText.contains("Hello from Windows!"),
            "Expected 'Hello from Windows!' in log output. Text:\n\(allText)")
    }
}
