import Foundation

public struct HostShellPaths: Equatable, Sendable {
    public var rootURL: URL

    public init(rootURL: URL) {
        self.rootURL = rootURL
    }

    public var containersURL: URL {
        rootURL.appending(path: "Containers")
    }

    public var sessionsURL: URL {
        rootURL.appending(path: "Sessions")
    }

    public static func defaultRootURL(fileManager: FileManager = .default) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return baseURL.appending(path: "CellarKitPreview")
    }
}
