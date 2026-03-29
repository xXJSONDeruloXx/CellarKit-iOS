import XCTest
@testable import CellarCore

final class ContainerFactoryTests: XCTestCase {
    private let factory = ContainerFactory()

    func testTranslatorDecisionProducesLargerBudgetProfile() {
        let request = GameLaunchRequest(
            title: "x64 Imported Game",
            storefront: .localImport,
            acquisitionMode: .localImport,
            guestArchitecture: .windowsX64,
            requiresGraphicsTranslation: true
        )
        let decision = PlanningDecision(
            backend: .wineX64Translator,
            policyRisk: .low
        )

        let profile = factory.makeRuntimeProfile(request: request, decision: decision)

        XCTAssertEqual(profile.backendPreference, .wineX64Translator)
        XCTAssertEqual(profile.graphicsBackend, .dxvkMoltenVK)
        XCTAssertEqual(profile.memoryBudgetMB, 2048)
        XCTAssertEqual(profile.shaderCacheBudgetMB, 256)
    }

    func testInterpreterDecisionProducesFallbackGraphicsProfile() {
        let request = GameLaunchRequest(
            title: "Interpreter Game",
            storefront: .localImport,
            acquisitionMode: .localImport,
            guestArchitecture: .windowsX64,
            requiresGraphicsTranslation: true
        )
        let decision = PlanningDecision(
            backend: .wineThreadedInterpreter,
            policyRisk: .medium
        )

        let profile = factory.makeRuntimeProfile(request: request, decision: decision)

        XCTAssertEqual(profile.graphicsBackend, .wined3dFallback)
        XCTAssertEqual(profile.memoryBudgetMB, 1280)
        XCTAssertEqual(profile.shaderCacheBudgetMB, 128)
    }

    func testDescriptorCarriesImportedContentReference() {
        let request = GameLaunchRequest(
            title: "ARM64 Game",
            storefront: .localImport,
            acquisitionMode: .localImport,
            guestArchitecture: .windowsARM64
        )
        let decision = PlanningDecision(
            backend: .wineARM64,
            policyRisk: .low
        )
        let ref = ImportedContentReference(
            mode: .managedCopy,
            pathHint: "Containers/ARM64 Game/GamePayload",
            originalFilename: "Game.exe"
        )

        let descriptor = factory.makeDescriptor(from: request, decision: decision, contentReference: ref)

        XCTAssertEqual(descriptor.title, "ARM64 Game")
        XCTAssertEqual(descriptor.contentReference, ref)
        XCTAssertEqual(descriptor.runtimeProfile.backendPreference, .wineARM64)
    }
}
