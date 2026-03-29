import XCTest
@testable import CellarRuntimeBridge
@testable import CellarCore

final class RuntimeLaunchConfigurationFactoryTests: XCTestCase {
    func testFactoryBuildsConfigurationFromContainerDecisionAndCapabilities() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let payloadRoot = root.appending(path: "ConfiguredGame")
        try FileManager.default.createDirectory(at: payloadRoot, withIntermediateDirectories: true)
        let executableURL = payloadRoot.appending(path: "Bin/Game.exe")
        try FileManager.default.createDirectory(at: executableURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("demo".utf8).write(to: executableURL)

        let factory = RuntimeLaunchConfigurationFactory()
        let container = ContainerDescriptor(
            title: "Configured Game",
            storefront: .localImport,
            acquisitionMode: .localImport,
            guestArchitecture: .windowsX64,
            importPath: payloadRoot.path,
            contentReference: ImportedContentReference(
                mode: .externalSecurityScopedReference,
                pathHint: payloadRoot.path,
                bookmarkIdentifier: "bookmark-123",
                originalFilename: "ConfiguredGame"
            ),
            entryExecutableRelativePath: "Bin/Game.exe",
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
        XCTAssertEqual(configuration.contentPath, payloadRoot.path)
        XCTAssertEqual(configuration.entryExecutableRelativePath, "Bin/Game.exe")
        XCTAssertEqual(configuration.resolvedExecutablePath, executableURL.path)
        XCTAssertEqual(configuration.bookmarkIdentifier, "bookmark-123")
        XCTAssertEqual(configuration.memoryBudgetMB, 2048)
        XCTAssertEqual(configuration.shaderCacheBudgetMB, 256)
    }
}
