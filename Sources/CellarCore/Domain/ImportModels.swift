import Foundation

public enum ImportedContentMode: String, Codable, CaseIterable, Sendable {
    case managedCopy
    case externalSecurityScopedReference
    case storefrontManagedDownload
    case bundledSample
}

public struct ImportedContentReference: Codable, Equatable, Sendable {
    public var mode: ImportedContentMode
    public var pathHint: String?
    public var bookmarkIdentifier: String?
    public var originalFilename: String?

    public init(
        mode: ImportedContentMode,
        pathHint: String? = nil,
        bookmarkIdentifier: String? = nil,
        originalFilename: String? = nil
    ) {
        self.mode = mode
        self.pathHint = pathHint
        self.bookmarkIdentifier = bookmarkIdentifier
        self.originalFilename = originalFilename
    }
}
