import Foundation

public enum QuayStoreError: Error, Equatable {
    case corrupt
    case unsupportedSchema
}

public enum QuayJSON {
    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }
}

public enum QuayFiles {
    public static let dockFileName = "dock.json"
    public static let activityFileName = "activity.json"

    public static func supportDirectory(fileManager: FileManager = .default) throws -> URL {
        let root = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = root.appendingPathComponent("Quay", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

public struct JSONFileStore<Value: Codable> {
    public var fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() throws -> Value? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        if data.isEmpty { throw QuayStoreError.corrupt }
        do {
            return try QuayJSON.makeDecoder().decode(Value.self, from: data)
        } catch let error as QuayStoreError {
            throw error
        } catch {
            throw QuayStoreError.corrupt
        }
    }

    public func save(_ value: Value) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try QuayJSON.makeEncoder().encode(value)
        try data.write(to: fileURL, options: .atomic)
    }
}
