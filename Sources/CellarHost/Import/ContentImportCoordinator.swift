import Foundation
import CellarCore

public struct ImportedPayload: Equatable, Sendable {
    public var contentReference: ImportedContentReference
    public var storedURL: URL?

    public init(contentReference: ImportedContentReference, storedURL: URL? = nil) {
        self.contentReference = contentReference
        self.storedURL = storedURL
    }
}

public struct ContentImportCoordinator {
    public let managedContentRootURL: URL
    public let bookmarkStore: BookmarkStore
    private let fileManager: FileManager

    public init(
        managedContentRootURL: URL,
        bookmarkStore: BookmarkStore,
        fileManager: FileManager = .default
    ) {
        self.managedContentRootURL = managedContentRootURL
        self.bookmarkStore = bookmarkStore
        self.fileManager = fileManager
    }

    public func importManagedCopy(
        from sourceURL: URL,
        containerID: UUID,
        preferredName: String? = nil
    ) throws -> ImportedPayload {
        let containerRoot = managedContentRootURL.appending(path: containerID.uuidString)
        let payloadRoot = containerRoot.appending(path: "Payload")
        if !fileManager.fileExists(atPath: payloadRoot.path()) {
            try fileManager.createDirectory(at: payloadRoot, withIntermediateDirectories: true)
        }

        let destinationName = preferredName ?? sourceURL.lastPathComponent
        let destinationURL = payloadRoot.appending(path: destinationName)

        if fileManager.fileExists(atPath: destinationURL.path()) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)

        return ImportedPayload(
            contentReference: ImportedContentReference(
                mode: .managedCopy,
                pathHint: destinationURL.path,
                originalFilename: sourceURL.lastPathComponent
            ),
            storedURL: destinationURL
        )
    }

    public func registerSecurityScopedReference(for url: URL) throws -> ImportedPayload {
        let bookmark = try bookmarkStore.save(url: url)
        return ImportedPayload(
            contentReference: ImportedContentReference(
                mode: .externalSecurityScopedReference,
                pathHint: url.path,
                bookmarkIdentifier: bookmark.identifier,
                originalFilename: url.lastPathComponent
            ),
            storedURL: url
        )
    }

    public func registerBundledSample(
        named _: String,
        pathHint: String,
        originalFilename: String
    ) -> ImportedPayload {
        ImportedPayload(
            contentReference: ImportedContentReference(
                mode: .bundledSample,
                pathHint: pathHint,
                originalFilename: originalFilename
            ),
            storedURL: nil
        )
    }
}
