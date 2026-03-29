import XCTest
@testable import CellarRuntimeBridge
@testable import CellarHost
@testable import CellarCore

final class NativeRuntimeBridgeTests: XCTestCase {
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
        let decision = PlanningDecision(
            backend: .wineARM64,
            policyRisk: .low
        )
        let capabilities = RuntimeCapabilities(
            distributionChannel: .developerSigned,
            jitMode: .none
        )

        let events = await collect(
            bridge.launch(
                container: container,
                decision: decision,
                capabilities: capabilities,
                productLane: .research
            )
        )

        XCTAssertEqual(events.count, 6)
        XCTAssertEqual(events[0], .preparing(message: "native stub preparing title=Native Stub Game backend=wineARM64 lane=research"))
        XCTAssertEqual(events[1], .started)
        XCTAssertEqual(events[2], .log("native backend=wineARM64"))
        XCTAssertEqual(events[3], .log("native lane=research"))
        XCTAssertEqual(events[4], .interactive(message: "native stub interactive"))
        XCTAssertEqual(events[5], .exited(exitCode: 0))
    }

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
        let decision = PlanningDecision(
            backend: .wineX64Translator,
            policyRisk: .low
        )
        let capabilities = RuntimeCapabilities(
            distributionChannel: .developerSigned,
            jitMode: .debuggerAttached
        )

        let events = await collect(
            bridge.launch(
                container: container,
                decision: decision,
                capabilities: capabilities,
                productLane: .research
            )
        )

        XCTAssertEqual(events.last, .failed(message: "native stub failure"))
    }

    private func collect(_ stream: AsyncStream<RuntimeBridgeEvent>) async -> [RuntimeBridgeEvent] {
        var events: [RuntimeBridgeEvent] = []
        for await event in stream {
            events.append(event)
        }
        return events
    }
}
