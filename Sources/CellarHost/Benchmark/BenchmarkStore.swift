import Foundation

public struct BenchmarkStore {
    public let rootURL: URL
    private let fileManager: FileManager

    public init(rootURL: URL, fileManager: FileManager = .default) {
        self.rootURL = rootURL
        self.fileManager = fileManager
    }

    public func save(_ record: BenchmarkRecord) throws {
        let directoryURL = benchmarksDirectory(for: record.containerID)
        if !fileManager.fileExists(atPath: directoryURL.path()) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(record)
        try data.write(to: recordURL(for: record.containerID, benchmarkID: record.id), options: .atomic)
    }

    public func loadAll(containerID: UUID) throws -> [BenchmarkRecord] {
        let directoryURL = benchmarksDirectory(for: containerID)
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
            .map { try decoder.decode(BenchmarkRecord.self, from: Data(contentsOf: $0)) }
            .sorted { $0.recordedAt > $1.recordedAt }
    }

    public func deleteAll(containerID: UUID) throws {
        let directoryURL = benchmarksDirectory(for: containerID)
        guard fileManager.fileExists(atPath: directoryURL.path()) else {
            return
        }
        try fileManager.removeItem(at: directoryURL)
    }

    private func benchmarksDirectory(for containerID: UUID) -> URL {
        rootURL
            .appending(path: containerID.uuidString)
            .appending(path: "Benchmarks")
    }

    private func recordURL(for containerID: UUID, benchmarkID: UUID) -> URL {
        benchmarksDirectory(for: containerID)
            .appending(path: benchmarkID.uuidString)
            .appendingPathExtension("json")
    }
}
