import XCTest
@testable import CellarHost
@testable import CellarCore

final class ContentImportCoordinatorTests: XCTestCase {
    func testManagedCopyImportsPayloadIntoContainerScopedDirectory() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let sourceURL = root.appending(path: "Source.exe")
        try Data("demo".utf8).write(to: sourceURL)

        let coordinator = ContentImportCoordinator(
            managedContentRootURL: root.appending(path: "ManagedContent"),
            bookmarkStore: BookmarkStore(rootURL: root.appending(path: "Bookmarks"))
        )

        let containerID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let imported = try coordinator.importManagedCopy(
            from: sourceURL,
            containerID: containerID,
            preferredName: "Game.exe"
        )

        XCTAssertEqual(imported.contentReference.mode, .managedCopy)
        XCTAssertEqual(imported.contentReference.originalFilename, "Source.exe")
        XCTAssertEqual(imported.entryExecutableRelativePath, "Game.exe")
        XCTAssertTrue(imported.contentReference.pathHint?.hasSuffix("Game.exe") == true)
        XCTAssertEqual(try Data(contentsOf: imported.storedURL!), Data("demo".utf8))
    }

    func testSecurityScopedRegistrationStoresResolvableBookmark() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let sourceURL = root.appending(path: "FolderRef")
        try FileManager.default.createDirectory(at: sourceURL, withIntermediateDirectories: true)

        let bookmarkStore = BookmarkStore(rootURL: root.appending(path: "Bookmarks"))
        let coordinator = ContentImportCoordinator(
            managedContentRootURL: root.appending(path: "ManagedContent"),
            bookmarkStore: bookmarkStore
        )

        let imported = try coordinator.registerSecurityScopedReference(for: sourceURL)
        let resolved = try bookmarkStore.resolve(identifier: imported.contentReference.bookmarkIdentifier!)

        XCTAssertEqual(imported.contentReference.mode, .externalSecurityScopedReference)
        XCTAssertNil(imported.entryExecutableRelativePath)
        XCTAssertEqual(resolved.standardizedFileURL.path, sourceURL.standardizedFileURL.path)
    }

    func testBundledSampleRegistrationCreatesReferenceWithoutFilesystemWrite() {
        let coordinator = ContentImportCoordinator(
            managedContentRootURL: URL(fileURLWithPath: "/tmp/ManagedContent", isDirectory: true),
            bookmarkStore: BookmarkStore(rootURL: URL(fileURLWithPath: "/tmp/Bookmarks", isDirectory: true))
        )

        let imported = coordinator.registerBundledSample(
            named: "Probe",
            pathHint: "Samples/Probe/Sample.exe",
            originalFilename: "Sample.exe"
        )

        XCTAssertEqual(imported.contentReference.mode, .bundledSample)
        XCTAssertEqual(imported.contentReference.pathHint, "Samples/Probe/Sample.exe")
        XCTAssertEqual(imported.entryExecutableRelativePath, "Sample.exe")
        XCTAssertNil(imported.storedURL)
    }
}
