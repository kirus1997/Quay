import Foundation

public struct DockApp: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var bundleIdentifier: String?
    public var path: String

    public init(id: UUID = UUID(), name: String, bundleIdentifier: String?, path: String) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.path = path
    }

    public static func samePath(_ lhs: String, _ rhs: String) -> Bool {
        Self.normalize(lhs) == Self.normalize(rhs)
    }

    public static func normalize(_ path: String) -> String {
        var text = URL(fileURLWithPath: path).standardizedFileURL.path
        if text.count > 1, text.hasSuffix("/") {
            text.removeLast()
        }
        return text
    }
}

public struct AppCollection: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var apps: [DockApp]

    public init(id: UUID = UUID(), name: String, apps: [DockApp]) {
        self.id = id
        self.name = name
        self.apps = apps
    }
}

public enum WidgetKind: String, Codable, CaseIterable, Sendable {
    case nowPlaying
    case timer
    case upcomingEvents

    public var title: String {
        switch self {
        case .nowPlaying: return "Now Playing"
        case .timer: return "Timer"
        case .upcomingEvents: return "Upcoming"
        }
    }

    public var summary: String {
        switch self {
        case .nowPlaying:
            return "Shows the current Spotify or Music track, with play, pause, and skip."
        case .timer:
            return "A countdown with quick presets and a custom length, plus a stopwatch."
        case .upcomingEvents:
            return "Shows the next calendar events and reminders that are due."
        }
    }
}

public enum SlotContent: Equatable, Sendable {
    case app(DockApp)
    case collection(AppCollection)
    case widget(WidgetKind)
}

public struct DockSlot: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var content: SlotContent

    public init(id: UUID = UUID(), content: SlotContent) {
        self.id = id
        self.content = content
    }

    public var title: String {
        switch content {
        case .app(let app): return app.name
        case .collection(let collection): return collection.name
        case .widget(let kind): return kind.title
        }
    }

    public var widgetKind: WidgetKind? {
        if case .widget(let kind) = content { return kind }
        return nil
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, app, collection, widget
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        switch content {
        case .app(let app):
            try container.encode("app", forKey: .type)
            try container.encode(app, forKey: .app)
        case .collection(let collection):
            try container.encode("collection", forKey: .type)
            try container.encode(collection, forKey: .collection)
        case .widget(let kind):
            try container.encode("widget", forKey: .type)
            try container.encode(kind, forKey: .widget)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "app":
            let app = try container.decode(DockApp.self, forKey: .app)
            content = .app(app)
        case "collection":
            let collection = try container.decode(AppCollection.self, forKey: .collection)
            content = .collection(collection)
        case "widget":
            let kind = try container.decode(WidgetKind.self, forKey: .widget)
            content = .widget(kind)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown dock slot type \(type)."
            )
        }
    }
}

public struct DockConfiguration: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var slots: [DockSlot]
    /// When true, the dock slides off the main display until the pointer hits the bottom edge.
    public var autoHides: Bool

    public init(
        schemaVersion: Int = DockConfiguration.currentSchemaVersion,
        slots: [DockSlot],
        autoHides: Bool = true
    ) {
        self.schemaVersion = schemaVersion
        self.slots = slots
        self.autoHides = autoHides
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case slots
        case autoHides
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        slots = try container.decode([DockSlot].self, forKey: .slots)
        // Files saved before 0.1.1 omit the key. Auto-hide is the default.
        autoHides = try container.decodeIfPresent(Bool.self, forKey: .autoHides) ?? true
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(slots, forKey: .slots)
        try container.encode(autoHides, forKey: .autoHides)
    }

    public static func freshDefault() -> DockConfiguration {
        DockConfiguration(
            slots: [
                DockSlot(content: .widget(.nowPlaying)),
                DockSlot(content: .widget(.timer)),
                DockSlot(content: .widget(.upcomingEvents)),
            ],
            autoHides: true
        )
    }

    public func hasWidget(_ kind: WidgetKind) -> Bool {
        slots.contains { $0.widgetKind == kind }
    }

    public func containsApp(path: String) -> Bool {
        slots.contains { slot in
            guard case .app(let app) = slot.content else { return false }
            return DockApp.samePath(app.path, path)
        }
    }

    public func removingDuplicateWidgets() -> DockConfiguration {
        var seen = Set<WidgetKind>()
        var copy = self
        copy.slots = slots.filter { slot in
            guard let kind = slot.widgetKind else { return true }
            return seen.insert(kind).inserted
        }
        return copy
    }

    @discardableResult
    public mutating func addApp(_ app: DockApp) -> Bool {
        guard !containsApp(path: app.path) else { return false }
        slots.append(DockSlot(content: .app(app)))
        return true
    }

    @discardableResult
    public mutating func addWidget(_ kind: WidgetKind) -> UUID? {
        guard !hasWidget(kind) else { return nil }
        let slot = DockSlot(content: .widget(kind))
        slots.append(slot)
        return slot.id
    }

    @discardableResult
    public mutating func addCollection(named name: String = "Collection") -> UUID {
        let slotID = UUID()
        let collection = AppCollection(id: UUID(), name: Self.collectionName(name), apps: [])
        slots.append(DockSlot(id: slotID, content: .collection(collection)))
        return slotID
    }

    @discardableResult
    public mutating func removeSlot(id: UUID) -> Bool {
        guard let index = slots.firstIndex(where: { $0.id == id }) else { return false }
        slots.remove(at: index)
        return true
    }

    @discardableResult
    public mutating func moveSlot(id: UUID, direction: Int) -> Bool {
        guard direction != 0, let index = slots.firstIndex(where: { $0.id == id }) else { return false }
        let target = index + direction
        guard slots.indices.contains(target) else { return false }
        slots.swapAt(index, target)
        return true
    }

    public mutating func moveSlots(fromOffsets source: IndexSet, toOffset destination: Int) {
        let indexes = source.filter { slots.indices.contains($0) }.sorted()
        guard !indexes.isEmpty else { return }
        let moving = indexes.map { slots[$0] }
        for index in indexes.reversed() {
            slots.remove(at: index)
        }
        let removedBefore = indexes.filter { $0 < destination }.count
        let insertAt = min(max(destination - removedBefore, 0), slots.count)
        slots.insert(contentsOf: moving, at: insertAt)
    }

    @discardableResult
    public mutating func renameCollection(slotID: UUID, to name: String) -> Bool {
        guard let index = collectionIndex(slotID) else { return false }
        guard case .collection(var collection) = slots[index].content else { return false }
        collection.name = Self.collectionName(name)
        slots[index].content = .collection(collection)
        return true
    }

    @discardableResult
    public mutating func addApp(_ app: DockApp, toCollectionSlot slotID: UUID) -> Bool {
        guard let index = collectionIndex(slotID) else { return false }
        guard case .collection(var collection) = slots[index].content else { return false }
        guard !collection.apps.contains(where: { DockApp.samePath($0.path, app.path) }) else { return false }
        collection.apps.append(app)
        slots[index].content = .collection(collection)
        return true
    }

    @discardableResult
    public mutating func removeApp(appID: UUID, fromCollectionSlot slotID: UUID) -> Bool {
        guard let index = collectionIndex(slotID) else { return false }
        guard case .collection(var collection) = slots[index].content else { return false }
        let before = collection.apps.count
        collection.apps.removeAll { $0.id == appID }
        guard collection.apps.count != before else { return false }
        slots[index].content = .collection(collection)
        return true
    }

    public mutating func moveApps(inCollectionSlot slotID: UUID, fromOffsets source: IndexSet, toOffset destination: Int) -> Bool {
        guard let index = collectionIndex(slotID) else { return false }
        guard case .collection(var collection) = slots[index].content else { return false }
        let indexes = source.filter { collection.apps.indices.contains($0) }.sorted()
        guard !indexes.isEmpty else { return false }
        let moving = indexes.map { collection.apps[$0] }
        for appIndex in indexes.reversed() {
            collection.apps.remove(at: appIndex)
        }
        let removedBefore = indexes.filter { $0 < destination }.count
        let insertAt = min(max(destination - removedBefore, 0), collection.apps.count)
        collection.apps.insert(contentsOf: moving, at: insertAt)
        slots[index].content = .collection(collection)
        return true
    }

    public static func collectionName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Collection" : trimmed
    }

    private func collectionIndex(_ slotID: UUID) -> Int? {
        guard let index = slots.firstIndex(where: { $0.id == slotID }) else { return nil }
        guard case .collection = slots[index].content else { return nil }
        return index
    }
}
