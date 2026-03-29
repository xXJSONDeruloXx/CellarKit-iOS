import Foundation

public struct ContainerStore {
    public let rootURL: URL
    private let fileManager: FileManager

    public init(rootURL: URL, fileManager: FileManager = .default) {
        self.rootURL = rootURL
        self.fileManager = fileManager
    }

    public func save(_ descriptor: ContainerDescriptor) throws {
        let containerURL = rootURL.appending(path: descriptor.id.uuidString)
        let metadataURL = metadataURL(for: descriptor.id)

        if !fileManager.fileExists(atPath: containerURL.path()) {
            try fileManager.createDirectory(at: containerURL, withIntermediateDirectories: true)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(descriptor)
        try data.write(to: metadataURL, options: .atomic)
    }

    public func load(id: UUID) throws -> ContainerDescriptor? {
        let metadataURL = metadataURL(for: id)
        guard fileManager.fileExists(atPath: metadataURL.path()) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let data = try Data(contentsOf: metadataURL)
        return try decoder.decode(ContainerDescriptor.self, from: data)
    }

    public func loadAll() throws -> [ContainerDescriptor] {
        guard fileManager.fileExists(atPath: rootURL.path()) else {
            return []
        }

        let children = try fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        return try children.compactMap { child in
            let metadataURL = child.appending(path: "Metadata").appendingPathExtension("json")
            guard fileManager.fileExists(atPath: metadataURL.path()) else {
                return nil
            }
            let data = try Data(contentsOf: metadataURL)
            return try decoder.decode(ContainerDescriptor.self, from: data)
        }.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    public func updateLastLaunchedAt(id: UUID, at date: Date) throws {
        guard var descriptor = try load(id: id) else {
            return
        }
        descriptor.lastLaunchedAt = date
        try save(descriptor)
    }

    public func delete(id: UUID) throws {
        let containerURL = rootURL.appending(path: id.uuidString)
        guard fileManager.fileExists(atPath: containerURL.path()) else {
            return
        }
        try fileManager.removeItem(at: containerURL)
    }

    private func metadataURL(for id: UUID) -> URL {
        rootURL
            .appending(path: id.uuidString)
            .appending(path: "Metadata")
            .appendingPathExtension("json")
    }
}
