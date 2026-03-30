import XCTest
@testable import CellarRuntimeBridge
@testable import CellarHost
@testable import CellarCore

final class NativeRuntimeBridgeTests: XCTestCase {

    // MARK: - Happy path (no runtime binary bundled → legacy fallback)

    func testNativeRuntimeBridgeEmitsExpectedHappyPathEvents() async {
        let bridge = NativeRuntimeBridge(exitCode: 0, emitFailure: false)
        let container = ContainerDescriptor(
            title: "Native Stub Game",
            storefront: .localImport,
            acquisitionMode: .localImport,
            guestArchitecture: .windowsARM64,
            runtimeProfile: RuntimeProfile(
                backendPreference: .wineARM64,
                graphicsBackend: .dxvkMoltenVK
            )
        )
        let decision = PlanningDecision(backend: .wineARM64, policyRisk: .low)
        let capabilities = RuntimeCapabilities(distributionChannel: .developerSigned, jitMode: .none)

        let events = await collect(
            bridge.launch(container: container, decision: decision,
                          capabilities: capabilities, productLane: .research)
        )

        // preparing + LOG(prep mirror) + LOG(no-runtime) + LOG(stub info)
        //   + started + interactive + exited = 7
        XCTAssertEqual(events.count, 7)

        // [0] preparing — must name title and backend
        if case .preparing(let msg) = events[0] {
            XCTAssertTrue(msg.contains("Native Stub Game"), "preparing should contain title")
            XCTAssertTrue(msg.contains("wineARM64"),        "preparing should contain backend")
        } else {
            XCTFail("events[0] should be .preparing, got \(events[0])")
        }

        // [1] LOG mirror of the preparing message (bridge: title=... runtime=(none))
        if case .log(let msg) = events[1] {
            XCTAssertTrue(msg.contains("Native Stub Game"), "log mirror should contain title")
        } else {
            XCTFail("events[1] should be .log (prep mirror), got \(events[1])")
        }

        // [2] first legacy fallback log
        XCTAssertEqual(events[2], .log("[stub] no runtime_binary_path \u{2014} using legacy simulated events"))

        // [3] second log echoes title/backend/graphics
        if case .log(let msg) = events[3] {
            XCTAssertTrue(msg.contains("Native Stub Game"), "stub log should contain title")
            XCTAssertTrue(msg.contains("wineARM64"),        "stub log should contain backend")
        } else {
            XCTFail("events[3] should be .log, got \(events[3])")
        }

        XCTAssertEqual(events[4], .started)
        XCTAssertEqual(events[5], .interactive(message: "legacy stub interactive"))
        XCTAssertEqual(events[6], .exited(exitCode: 0))
    }

    // MARK: - Failure flag

    func testNativeRuntimeBridgeCanEmitFailure() async {
        let bridge = NativeRuntimeBridge(exitCode: 12, emitFailure: true)
        let container = ContainerDescriptor(
            title: "Failure Case",
            storefront: .localImport,
            acquisitionMode: .localImport,
            guestArchitecture: .windowsX64,
            runtimeProfile: RuntimeProfile(
                backendPreference: .wineX64Translator,
                graphicsBackend: .dxvkMoltenVK
            )
        )
        let decision = PlanningDecision(backend: .wineX64Translator, policyRisk: .low)
        let capabilities = RuntimeCapabilities(distributionChannel: .developerSigned,
                                               jitMode: .debuggerAttached)

        let events = await collect(
            bridge.launch(container: container, decision: decision,
                          capabilities: capabilities, productLane: .research)
        )

        XCTAssertEqual(events.last, .failed(message: "legacy stub failure"))
    }

    // MARK: - Missing executable validation

    func testNativeRuntimeBridgeFailsWhenManagedPayloadExecutableCannotBeResolved() async {
        let bridge = NativeRuntimeBridge(exitCode: 0, emitFailure: false)
        let container = ContainerDescriptor(
            title: "Broken Payload",
            storefront: .localImport,
            acquisitionMode: .localImport,
            guestArchitecture: .windowsARM64,
            importPath: "/tmp/CellarKit/MissingPayload",
            contentReference: ImportedContentReference(
                mode: .managedCopy,
                pathHint: "/tmp/CellarKit/MissingPayload",
                originalFilename: "MissingPayload"
            ),
            runtimeProfile: RuntimeProfile(
                backendPreference: .wineARM64,
                graphicsBackend: .diagnosticOnly
            )
        )
        let decision = PlanningDecision(backend: .wineARM64, policyRisk: .low)
        let capabilities = RuntimeCapabilities(distributionChannel: .developerSigned, jitMode: .none)

        let events = await collect(
            bridge.launch(container: container, decision: decision,
                          capabilities: capabilities, productLane: .research)
        )

        XCTAssertEqual(
            events.last,
            .failed(message: "native bootstrap could not find launch executable at /tmp/CellarKit/MissingPayload")
        )
    }

    // MARK: - Helper

    private func collect(_ stream: AsyncStream<RuntimeBridgeEvent>) async -> [RuntimeBridgeEvent] {
        var events: [RuntimeBridgeEvent] = []
        for await event in stream { events.append(event) }
        return events
    }
}
