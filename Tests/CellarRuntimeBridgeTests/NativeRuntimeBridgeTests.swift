import XCTest
@testable import CellarRuntimeBridge
@testable import CellarHost
@testable import CellarCore

final class NativeRuntimeBridgeTests: XCTestCase {

    // MARK: - Happy path (no runtime binary bundled → legacy fallback)

    // All tests use allowSystemWine: false so results don't depend on whether
    // wine64 is installed on the host machine.
    private func makeBridge(exitCode: Int32 = 0, emitFailure: Bool = false) -> NativeRuntimeBridge {
        NativeRuntimeBridge(
            exitCode: exitCode,
            emitFailure: emitFailure,
            configurationFactory: RuntimeLaunchConfigurationFactory(allowSystemWine: false)
        )
    }

    func testNativeRuntimeBridgeEmitsExpectedHappyPathEvents() async {
        let bridge = makeBridge()
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

        // preparing + LOG(prep mirror) + started
        //   + 5× DX11/DXVK log lines + interactive + exited = 10
        XCTAssertEqual(events.count, 10)

        // [0] preparing — must name title and backend
        if case .preparing(let msg) = events[0] {
            XCTAssertTrue(msg.contains("Native Stub Game"), "preparing should contain title")
            XCTAssertTrue(msg.contains("wineARM64"),        "preparing should contain backend")
        } else {
            XCTFail("events[0] should be .preparing, got \(events[0])")
        }

        // [1] LOG mirror of the preparing message
        if case .log(let msg) = events[1] {
            XCTAssertTrue(msg.contains("Native Stub Game"), "log mirror should contain title")
        } else {
            XCTFail("events[1] should be .log (prep mirror), got \(events[1])")
        }

        // [2] started
        XCTAssertEqual(events[2], .started)

        // [3..7] DX11/DXVK simulated log lines (dxvkMoltenVK graphics triggers is_dx11)
        if case .log(let msg) = events[3] {
            XCTAssertTrue(msg.contains("D3D11CreateDevice"), "should mention D3D11CreateDevice")
        } else { XCTFail("events[3] should be .log, got \(events[3])") }

        if case .log(let msg) = events[7] {
            XCTAssertTrue(msg.contains("Native Stub Game"), "last dx11 log should contain title")
        } else { XCTFail("events[7] should be .log, got \(events[7])") }

        XCTAssertEqual(events[8], .interactive(message: "process interactive"))
        XCTAssertEqual(events[9], .exited(exitCode: 0))
    }

    // MARK: - Failure flag

    func testNativeRuntimeBridgeCanEmitFailure() async {
        let bridge = makeBridge(exitCode: 12, emitFailure: true)
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

        XCTAssertEqual(events.last, .failed(message: "process failed"))
    }

    // MARK: - Missing executable validation

    func testNativeRuntimeBridgeFailsWhenManagedPayloadExecutableCannotBeResolved() async {
        let bridge = makeBridge()
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
