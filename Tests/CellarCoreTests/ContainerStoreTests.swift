import XCTest
@testable import CellarCore

final class ContainerStoreTests: XCTestCase {
    func testSaveLoadAndDeleteContainerDescriptor() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let store = ContainerStore(rootURL: tempRoot)

        let first = ContainerDescriptor(
            title: "Bravo",
            storefront: .localImport,
            acquisitionMode: .localImport,
            guestArchitecture: .windowsARM64,
            contentReference: ImportedContentReference(mode: .managedCopy, pathHint: "Containers/Bravo"),
            runtimeProfile: RuntimeProfile(
                backendPreference: .wineARM64,
                graphicsBackend: .dxvkMoltenVK
            )
        )
        let second = ContainerDescriptor(
            title: "Alpha",
            storefront: .localImport,
            acquisitionMode: .bundledSample,
            guestArchitecture: .windowsX64,
            contentReference: ImportedContentReference(mode: .bundledSample, originalFilename: "Sample.exe"),
            runtimeProfile: RuntimeProfile(
                backendPreference: .wineThreadedInterpreter,
                graphicsBackend: .diagnosticOnly
            )
        )

        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try store.save(first)
        try store.save(second)

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.map(\.title), ["Alpha", "Bravo"])
        XCTAssertEqual(Set(loaded.map(\.id)), Set([first.id, second.id]))

        try store.delete(id: first.id)
        let afterDelete = try store.loadAll()
        XCTAssertEqual(afterDelete, [second])
    }

    func testLoadByIDAndUpdateLastLaunchedAt() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let store = ContainerStore(rootURL: tempRoot)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let descriptor = ContainerDescriptor(
            title: "Launchable",
            storefront: .localImport,
            acquisitionMode: .localImport,
            guestArchitecture: .windowsARM64,
            runtimeProfile: RuntimeProfile(
                backendPreference: .wineARM64,
                graphicsBackend: .dxvkMoltenVK
            )
        )

        try store.save(descriptor)
        let loaded = try store.load(id: descriptor.id)
        XCTAssertEqual(loaded?.id, descriptor.id)
        XCTAssertNil(loaded?.lastLaunchedAt)

        let launchedAt = Date(timeIntervalSince1970: 1_700_001_000)
        try store.updateLastLaunchedAt(id: descriptor.id, at: launchedAt)

        let updated = try store.load(id: descriptor.id)
        XCTAssertEqual(updated?.lastLaunchedAt, launchedAt)
    }
}
