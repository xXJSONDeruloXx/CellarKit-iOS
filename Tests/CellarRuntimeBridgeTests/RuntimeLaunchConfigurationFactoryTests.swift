import XCTest
@testable import CellarRuntimeBridge
@testable import CellarCore

final class RuntimeLaunchConfigurationFactoryTests: XCTestCase {
    func testFactoryBuildsConfigurationFromContainerDecisionAndCapabilities() {
        let factory = RuntimeLaunchConfigurationFactory()
        let container = ContainerDescriptor(
            title: "Configured Game",
            storefront: .localImport,
            acquisitionMode: .localImport,
            guestArchitecture: .windowsX64,
            importPath: "/tmp/ConfiguredGame/Game.exe",
            contentReference: ImportedContentReference(
                mode: .externalSecurityScopedReference,
                pathHint: "/tmp/ConfiguredGame",
                bookmarkIdentifier: "bookmark-123",
                originalFilename: "Game.exe"
            ),
            runtimeProfile: RuntimeProfile(
                backendPreference: .wineX64Translator,
                graphicsBackend: .dxvkMoltenVK,
                memoryBudgetMB: 2048,
                shaderCacheBudgetMB: 256
            )
        )
        let decision = PlanningDecision(
            backend: .wineX64Translator,
            policyRisk: .low
        )
        let capabilities = RuntimeCapabilities(
            distributionChannel: .developerSigned,
            jitMode: .debuggerAttached,
            hasIncreasedMemoryLimit: true
        )

        let configuration = factory.makeConfiguration(
            container: container,
            decision: decision,
            capabilities: capabilities,
            productLane: .research
        )

        XCTAssertEqual(configuration.title, "Configured Game")
        XCTAssertEqual(configuration.backend, .wineX64Translator)
        XCTAssertEqual(configuration.graphicsBackend, .dxvkMoltenVK)
        XCTAssertEqual(configuration.distributionChannel, .developerSigned)
        XCTAssertEqual(configuration.jitMode, .debuggerAttached)
        XCTAssertEqual(configuration.contentMode, .externalSecurityScopedReference)
        XCTAssertEqual(configuration.contentPath, "/tmp/ConfiguredGame")
        XCTAssertEqual(configuration.bookmarkIdentifier, "bookmark-123")
        XCTAssertEqual(configuration.memoryBudgetMB, 2048)
        XCTAssertEqual(configuration.shaderCacheBudgetMB, 256)
    }
}
