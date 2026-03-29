import XCTest
@testable import CellarHost
@testable import CellarCore

final class HostCoordinatorTests: XCTestCase {
    func testCoordinatorCreatesContainerLaunchesAndPersistsSession() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }

        let coordinator = HostCoordinator(
            containerStore: ContainerStore(rootURL: root.appending(path: "Containers")),
            sessionStore: LaunchSessionStore(rootURL: root.appending(path: "Sessions")),
            benchmarkStore: BenchmarkStore(rootURL: root.appending(path: "Benchmarks")),
            contentImporter: ContentImportCoordinator(
                managedContentRootURL: root.appending(path: "ManagedContent"),
                bookmarkStore: BookmarkStore(rootURL: root.appending(path: "Bookmarks"))
            ),
            bridge: SimulatedRuntimeBridge(
                startupDelay: .milliseconds(0),
                lineDelay: .milliseconds(0),
                logLines: ["boot", "graphics ready"],
                interactiveMessage: "Interactive frame reached.",
                exitCode: 0
            )
        )

        let capabilities = RuntimeCapabilities(
            distributionChannel: .developerSigned,
            jitMode: .debuggerAttached,
            hasIncreasedMemoryLimit: true,
            isDebuggerAttached: true
        )
        let request = GameLaunchRequest(
            title: "Imported x64 Game",
            storefront: .localImport,
            acquisitionMode: .localImport,
            guestArchitecture: .windowsX64
        )

        let created = try await coordinator.createContainer(
            request: request,
            capabilities: capabilities,
            productLane: .research,
            contentReference: ImportedContentReference(
                mode: .managedCopy,
                pathHint: "Containers/Imported x64 Game",
                originalFilename: "Game.exe"
            )
        )
        let session = try await coordinator.launch(
            containerID: created.descriptor.id,
            capabilities: capabilities,
            productLane: .research
        )
        let loadedContainers = try await coordinator.listContainers()
        let sessions = try await coordinator.sessions(for: created.descriptor.id)
        let benchmarks = try await coordinator.benchmarks(for: created.descriptor.id)
        let log = try await coordinator.log(for: session)

        XCTAssertEqual(created.planningDecision.backend, .wineX64Translator)
        XCTAssertEqual(session.state, .exitedCleanly)
        XCTAssertTrue(session.wasSuccessful)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(benchmarks.count, 1)
        XCTAssertEqual(benchmarks.first?.metrics.logLineCount, 2)
        XCTAssertEqual(log, "boot\ngraphics ready")
        XCTAssertEqual(loadedContainers.count, 1)
        XCTAssertNotNil(loadedContainers.first?.lastLaunchedAt)
    }

    func testCoordinatorCreatesManagedCopyContainer() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let sourceURL = root.appending(path: "Game.exe")
        try Data("payload".utf8).write(to: sourceURL)

        let coordinator = HostCoordinator(
            containerStore: ContainerStore(rootURL: root.appending(path: "Containers")),
            sessionStore: LaunchSessionStore(rootURL: root.appending(path: "Sessions")),
            benchmarkStore: BenchmarkStore(rootURL: root.appending(path: "Benchmarks")),
            contentImporter: ContentImportCoordinator(
                managedContentRootURL: root.appending(path: "ManagedContent"),
                bookmarkStore: BookmarkStore(rootURL: root.appending(path: "Bookmarks"))
            ),
            bridge: SimulatedRuntimeBridge(startupDelay: .milliseconds(0), lineDelay: .milliseconds(0))
        )

        let request = GameLaunchRequest(
            title: "Managed Copy Game",
            storefront: .localImport,
            acquisitionMode: .localImport,
            guestArchitecture: .windowsARM64
        )
        let capabilities = RuntimeCapabilities(
            distributionChannel: .developerSigned,
            jitMode: .none
        )

        let created = try await coordinator.createManagedCopyContainer(
            sourceURL: sourceURL,
            request: request,
            capabilities: capabilities,
            productLane: .research,
            preferredFilename: "Installed.exe"
        )
        let loaded = try await coordinator.loadContainer(id: created.descriptor.id)

        XCTAssertEqual(created.descriptor.contentReference?.mode, .managedCopy)
        XCTAssertTrue(created.descriptor.importPath?.hasSuffix("Installed.exe") == true)
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: created.descriptor.importPath!)), Data("payload".utf8))
        XCTAssertEqual(loaded?.id, created.descriptor.id)
    }

    func testCoordinatorCreatesExternalReferenceContainerAndResolvesURL() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let sourceURL = root.appending(path: "LinkedFolder")
        try FileManager.default.createDirectory(at: sourceURL, withIntermediateDirectories: true)

        let coordinator = HostCoordinator(
            containerStore: ContainerStore(rootURL: root.appending(path: "Containers")),
            sessionStore: LaunchSessionStore(rootURL: root.appending(path: "Sessions")),
            benchmarkStore: BenchmarkStore(rootURL: root.appending(path: "Benchmarks")),
            contentImporter: ContentImportCoordinator(
                managedContentRootURL: root.appending(path: "ManagedContent"),
                bookmarkStore: BookmarkStore(rootURL: root.appending(path: "Bookmarks"))
            ),
            bridge: SimulatedRuntimeBridge(startupDelay: .milliseconds(0), lineDelay: .milliseconds(0))
        )

        let request = GameLaunchRequest(
            title: "Linked Game",
            storefront: .localImport,
            acquisitionMode: .localImport,
            guestArchitecture: .windowsARM64
        )
        let capabilities = RuntimeCapabilities(
            distributionChannel: .developerSigned,
            jitMode: .none
        )

        let created = try await coordinator.createExternalReferenceContainer(
            sourceURL: sourceURL,
            request: request,
            capabilities: capabilities,
            productLane: .research
        )
        let resolvedURL = try await coordinator.resolvedContentURL(for: created.descriptor.id)

        XCTAssertEqual(created.descriptor.contentReference?.mode, .externalSecurityScopedReference)
        XCTAssertNotNil(created.descriptor.contentReference?.bookmarkIdentifier)
        XCTAssertEqual(resolvedURL?.standardizedFileURL.path, sourceURL.standardizedFileURL.path)
    }

    func testCoordinatorDeleteContainerRemovesMetadataAndArtifacts() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let sourceURL = root.appending(path: "DeleteMe.exe")
        try Data("payload".utf8).write(to: sourceURL)

        let coordinator = HostCoordinator(
            containerStore: ContainerStore(rootURL: root.appending(path: "Containers")),
            sessionStore: LaunchSessionStore(rootURL: root.appending(path: "Sessions")),
            benchmarkStore: BenchmarkStore(rootURL: root.appending(path: "Benchmarks")),
            contentImporter: ContentImportCoordinator(
                managedContentRootURL: root.appending(path: "ManagedContent"),
                bookmarkStore: BookmarkStore(rootURL: root.appending(path: "Bookmarks"))
            ),
            bridge: SimulatedRuntimeBridge(startupDelay: .milliseconds(0), lineDelay: .milliseconds(0))
        )

        let capabilities = RuntimeCapabilities(
            distributionChannel: .developerSigned,
            jitMode: .none
        )
        let request = GameLaunchRequest(
            title: "Delete Me",
            storefront: .localImport,
            acquisitionMode: .localImport,
            guestArchitecture: .windowsARM64
        )

        let created = try await coordinator.createManagedCopyContainer(
            sourceURL: sourceURL,
            request: request,
            capabilities: capabilities,
            productLane: .research,
            preferredFilename: "DeleteMe.exe"
        )
        _ = try await coordinator.launch(
            containerID: created.descriptor.id,
            capabilities: capabilities,
            productLane: .research
        )

        try await coordinator.deleteContainer(id: created.descriptor.id)

        let loaded = try await coordinator.loadContainer(id: created.descriptor.id)
        let sessions = try await coordinator.sessions(for: created.descriptor.id)
        let benchmarks = try await coordinator.benchmarks(for: created.descriptor.id)

        XCTAssertNil(loaded)
        XCTAssertTrue(sessions.isEmpty)
        XCTAssertTrue(benchmarks.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: created.descriptor.importPath!))
    }

    func testCoordinatorPersistsPlanningFailureAsSession() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }

        let coordinator = HostCoordinator(
            containerStore: ContainerStore(rootURL: root.appending(path: "Containers")),
            sessionStore: LaunchSessionStore(rootURL: root.appending(path: "Sessions")),
            benchmarkStore: BenchmarkStore(rootURL: root.appending(path: "Benchmarks")),
            contentImporter: ContentImportCoordinator(
                managedContentRootURL: root.appending(path: "ManagedContent"),
                bookmarkStore: BookmarkStore(rootURL: root.appending(path: "Bookmarks"))
            ),
            bridge: SimulatedRuntimeBridge(startupDelay: .milliseconds(0), lineDelay: .milliseconds(0))
        )

        let capabilities = RuntimeCapabilities(
            distributionChannel: .appStore,
            jitMode: .none
        )
        let request = GameLaunchRequest(
            title: "Storefront Game",
            storefront: .steam,
            acquisitionMode: .storefrontDownload,
            guestArchitecture: .windowsX64
        )

        let created = try await coordinator.createContainer(
            request: request,
            capabilities: capabilities,
            productLane: .constrainedPublic
        )
        let session = try await coordinator.launch(
            containerID: created.descriptor.id,
            capabilities: capabilities,
            productLane: .constrainedPublic
        )
        let benchmarks = try await coordinator.benchmarks(for: created.descriptor.id)
        let log = try await coordinator.log(for: session)

        XCTAssertEqual(created.planningDecision.backend, .unsupported)
        XCTAssertEqual(session.state, .planningFailed)
        XCTAssertEqual(benchmarks.count, 1)
        XCTAssertFalse(log.isEmpty)
    }
}
