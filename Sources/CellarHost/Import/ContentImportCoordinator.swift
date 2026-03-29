import Foundation
import CellarCore

public struct ImportedPayload: Equatable, Sendable {
    public var contentReference: ImportedContentReference
    public var storedURL: URL?
    public var entryExecutableRelativePath: String?

    public init(
        contentReference: ImportedContentReference,
        storedURL: URL? = nil,
        entryExecutableRelativePath: String? = nil
    ) {
        self.contentReference = contentReference
        self.storedURL = storedURL
        self.entryExecutableRelativePath = entryExecutableRelativePath
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
            storedURL: destinationURL,
            entryExecutableRelativePath: inferEntryExecutableRelativePath(from: destinationURL)
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
            storedURL: url,
            entryExecutableRelativePath: inferEntryExecutableRelativePath(from: url)
        )
    }

    public func resolveImportedPayloadURL(for reference: ImportedContentReference?) throws -> URL? {
        guard let reference else {
            return nil
        }

        switch reference.mode {
        case .managedCopy, .bundledSample, .storefrontManagedDownload:
            guard let pathHint = reference.pathHint else {
                return nil
            }
            return URL(fileURLWithPath: pathHint)
        case .externalSecurityScopedReference:
            guard let bookmarkIdentifier = reference.bookmarkIdentifier else {
                return nil
            }
            return try bookmarkStore.resolve(identifier: bookmarkIdentifier)
        }
    }

    public func deleteImportedPayload(for reference: ImportedContentReference?) throws {
        guard let reference else {
            return
        }

        switch reference.mode {
        case .managedCopy:
            guard let pathHint = reference.pathHint else {
                return
            }
            let payloadURL = URL(fileURLWithPath: pathHint)
            let containerRoot = payloadURL.deletingLastPathComponent().deletingLastPathComponent()
            if fileManager.fileExists(atPath: containerRoot.path()) {
                try fileManager.removeItem(at: containerRoot)
            } else if fileManager.fileExists(atPath: payloadURL.path()) {
                try fileManager.removeItem(at: payloadURL)
            }
        case .externalSecurityScopedReference:
            if let bookmarkIdentifier = reference.bookmarkIdentifier {
                try bookmarkStore.delete(identifier: bookmarkIdentifier)
            }
        case .bundledSample, .storefrontManagedDownload:
            break
        }
    }

    public func registerBundledSample(
        named _: String,
        pathHint: String,
        originalFilename: String,
        entryExecutableRelativePath: String? = nil
    ) -> ImportedPayload {
        ImportedPayload(
            contentReference: ImportedContentReference(
                mode: .bundledSample,
                pathHint: pathHint,
                originalFilename: originalFilename
            ),
            storedURL: nil,
            entryExecutableRelativePath: entryExecutableRelativePath ?? originalFilename
        )
    }

    private func inferEntryExecutableRelativePath(from sourceURL: URL) -> String? {
        let lowercasePath = sourceURL.path.lowercased()
        if lowercasePath.hasSuffix(".exe") {
            return sourceURL.lastPathComponent
        }

        guard let enumerator = fileManager.enumerator(
            at: sourceURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        var matches: [String] = []
        while let candidate = enumerator.nextObject() as? URL {
            guard candidate.path.lowercased().hasSuffix(".exe") else {
                continue
            }

            let prefix = sourceURL.path.hasSuffix("/") ? sourceURL.path : sourceURL.path + "/"
            let relativePath = candidate.path.replacingOccurrences(of: prefix, with: "")
            matches.append(relativePath)
        }

        return matches.sorted().first
    }
}
