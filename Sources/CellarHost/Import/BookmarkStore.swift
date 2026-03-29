import Foundation

public struct StoredBookmark: Equatable, Sendable {
    public var identifier: String
    public var originalPath: String?

    public init(identifier: String, originalPath: String? = nil) {
        self.identifier = identifier
        self.originalPath = originalPath
    }
}

public struct BookmarkStore {
    public let rootURL: URL
    private let fileManager: FileManager

    public init(rootURL: URL, fileManager: FileManager = .default) {
        self.rootURL = rootURL
        self.fileManager = fileManager
    }

    public func save(url: URL, identifier: String = UUID().uuidString) throws -> StoredBookmark {
        if !fileManager.fileExists(atPath: rootURL.path()) {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        }

        let bookmarkData = try url.bookmarkData()
        try bookmarkData.write(to: bookmarkURL(for: identifier), options: .atomic)
        return StoredBookmark(identifier: identifier, originalPath: url.path())
    }

    public func resolve(identifier: String) throws -> URL {
        let data = try Data(contentsOf: bookmarkURL(for: identifier))
        var isStale = false
        return try URL(
            resolvingBookmarkData: data,
            bookmarkDataIsStale: &isStale
        )
    }

    public func delete(identifier: String) throws {
        let url = bookmarkURL(for: identifier)
        guard fileManager.fileExists(atPath: url.path()) else {
            return
        }
        try fileManager.removeItem(at: url)
    }

    private func bookmarkURL(for identifier: String) -> URL {
        rootURL.appending(path: identifier).appendingPathExtension("bookmark")
    }
}
