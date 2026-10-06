import Foundation

public struct DockStore {
    public var fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() throws -> DockConfiguration? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        if data.isEmpty { throw QuayStoreError.corrupt }
        let configuration: DockConfiguration
        do {
            configuration = try QuayJSON.makeDecoder().decode(DockConfiguration.self, from: data)
        } catch let error as QuayStoreError {
            throw error
        } catch {
            throw QuayStoreError.corrupt
        }
        if configuration.schemaVersion > DockConfiguration.currentSchemaVersion {
            throw QuayStoreError.unsupportedSchema
        }
        if configuration.schemaVersion < 1 {
            throw QuayStoreError.corrupt
        }
        return configuration.removingDuplicateWidgets()
    }

    public func save(_ configuration: DockConfiguration) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try QuayJSON.makeEncoder().encode(configuration)
        try data.write(to: fileURL, options: .atomic)
    }

    /// Moves a damaged dock file aside so the next save can write a fresh one.
    public func quarantine() throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        let backup = fileURL.deletingLastPathComponent()
            .appendingPathComponent(fileURL.lastPathComponent + ".bad")
        if fileManager.fileExists(atPath: backup.path) {
            try fileManager.removeItem(at: backup)
        }
        try fileManager.moveItem(at: fileURL, to: backup)
    }

    public func loadOrCreate() -> DockConfiguration {
        do {
            if let loaded = try load() {
                return loaded
            }
        } catch {
            try? quarantine()
        }
        let created = DockConfiguration.freshDefault()
        try? save(created)
        return created
    }
}
