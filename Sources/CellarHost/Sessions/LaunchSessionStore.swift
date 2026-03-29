import Foundation

public struct LaunchSessionStore {
    public let rootURL: URL
    private let fileManager: FileManager

    public init(rootURL: URL, fileManager: FileManager = .default) {
        self.rootURL = rootURL
        self.fileManager = fileManager
    }

    @discardableResult
    public func save(_ record: LaunchSessionRecord, log: String) throws -> LaunchSessionRecord {
        let directoryURL = sessionsDirectory(for: record.containerID)
        if !fileManager.fileExists(atPath: directoryURL.path()) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        let recordURL = recordURL(for: record.containerID, sessionID: record.id)
        let logURL = logURL(for: record.containerID, sessionID: record.id)

        var persistedRecord = record
        persistedRecord.logRelativePath = rootURL
            .relativePathComponents(to: logURL)
            .joined(separator: "/")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(persistedRecord)
        try data.write(to: recordURL, options: .atomic)
        try log.write(to: logURL, atomically: true, encoding: .utf8)
        return persistedRecord
    }

    public func loadAll(containerID: UUID) throws -> [LaunchSessionRecord] {
        let directoryURL = sessionsDirectory(for: containerID)
        guard fileManager.fileExists(atPath: directoryURL.path()) else {
            return []
        }

        let children = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        return try children
            .filter { $0.pathExtension == "json" }
            .map { try decoder.decode(LaunchSessionRecord.self, from: Data(contentsOf: $0)) }
            .sorted { $0.startedAt > $1.startedAt }
    }

    public func loadLog(for record: LaunchSessionRecord) throws -> String {
        let url: URL
        if let relativePath = record.logRelativePath {
            url = rootURL.appending(path: relativePath)
        } else {
            url = logURL(for: record.containerID, sessionID: record.id)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    public func deleteAll(containerID: UUID) throws {
        let directoryURL = sessionsDirectory(for: containerID)
        guard fileManager.fileExists(atPath: directoryURL.path()) else {
            return
        }
        try fileManager.removeItem(at: directoryURL)
    }

    private func sessionsDirectory(for containerID: UUID) -> URL {
        rootURL
            .appending(path: containerID.uuidString)
            .appending(path: "Launches")
    }

    private func recordURL(for containerID: UUID, sessionID: UUID) -> URL {
        sessionsDirectory(for: containerID)
            .appending(path: sessionID.uuidString)
            .appendingPathExtension("json")
    }

    private func logURL(for containerID: UUID, sessionID: UUID) -> URL {
        sessionsDirectory(for: containerID)
            .appending(path: sessionID.uuidString)
            .appendingPathExtension("log")
    }
}

private extension URL {
    func relativePathComponents(to target: URL) -> [String] {
        let baseComponents = standardizedFileURL.pathComponents
        let targetComponents = target.standardizedFileURL.pathComponents
        return Array(targetComponents.dropFirst(baseComponents.count))
    }
}
