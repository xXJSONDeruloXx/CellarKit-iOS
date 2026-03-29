import XCTest
@testable import CellarCore

final class ContainerModelsTests: XCTestCase {
    func testContainerDescriptorRoundTripsThroughJSON() throws {
        let descriptor = ContainerDescriptor(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            title: "Sample Game",
            storefront: .localImport,
            acquisitionMode: .localImport,
            guestArchitecture: .windowsARM64,
            importPath: "/private/var/mobile/Documents/Sample Game",
            contentReference: ImportedContentReference(
                mode: .managedCopy,
                pathHint: "Containers/Sample Game/GamePayload",
                originalFilename: "Sample Game.exe"
            ),
            entryExecutableRelativePath: "Sample Game.exe",
            runtimeProfile: RuntimeProfile(
                backendPreference: .wineARM64,
                graphicsBackend: .dxvkMoltenVK,
                touchOverlayEnabled: true,
                prefersPhysicalController: false,
                memoryBudgetMB: 1024,
                shaderCacheBudgetMB: 128
            ),
            lastLaunchedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(descriptor)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(ContainerDescriptor.self, from: data)

        XCTAssertEqual(decoded, descriptor)
    }

    func testRuntimeProfileDefaultsArePhoneReasonable() {
        let profile = RuntimeProfile(
            backendPreference: .wineThreadedInterpreter,
            graphicsBackend: .diagnosticOnly
        )

        XCTAssertTrue(profile.touchOverlayEnabled)
        XCTAssertTrue(profile.prefersPhysicalController)
        XCTAssertEqual(profile.memoryBudgetMB, 1536)
        XCTAssertEqual(profile.shaderCacheBudgetMB, 256)
    }
}
