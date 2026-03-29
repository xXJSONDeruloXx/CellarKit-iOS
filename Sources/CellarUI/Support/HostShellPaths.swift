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

    public var managedContentURL: URL {
        rootURL.appending(path: "ManagedContent")
    }

    public var bookmarksURL: URL {
        rootURL.appending(path: "Bookmarks")
    }

    public var benchmarksURL: URL {
        rootURL.appending(path: "Benchmarks")
    }

    public static func defaultRootURL(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        if let override = environment["CELLARKIT_ROOT_PATH"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }

        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return baseURL.appending(path: "CellarKitPreview")
    }
}
