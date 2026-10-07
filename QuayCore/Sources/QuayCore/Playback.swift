import Foundation

public enum PlaybackSource: String, Codable, CaseIterable, Hashable, Sendable {
    case spotify
    case appleMusic

    public var displayName: String {
        switch self {
        case .spotify: return "Spotify"
        case .appleMusic: return "Music"
        }
    }

    /// Name used by `tell application` in AppleScript.
    public var scriptingName: String { displayName }
}

public enum PlaybackStatus: String, Codable, Equatable, Sendable {
    case playing
    case paused
    case stopped

    public init(scriptOrNotification value: String) {
        if value.contains("kPSP") {
            self = .playing
            return
        }
        if value.contains("kPSp") {
            self = .paused
            return
        }
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "playing", "play":
            self = .playing
        case "paused", "pause":
            self = .paused
        default:
            self = .stopped
        }
    }
}

public enum DurationUnit: Sendable {
    case milliseconds
    case seconds
}

public struct Track: Equatable, Codable, Sendable {
    public var title: String
    public var artist: String
    public var album: String
    public var duration: TimeInterval?
    public var source: PlaybackSource
    public var status: PlaybackStatus
    public var trackID: String?

    public init(
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval?,
        source: PlaybackSource,
        status: PlaybackStatus,
        trackID: String?
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.source = source
        self.status = status
        self.trackID = trackID
    }
}

public enum PlaybackNotificationParser {
    /// `com.spotify.client.PlaybackStateChanged`. Duration is milliseconds.
    public static func spotify(_ fields: [String: String]) -> Track? {
        parse(fields, source: .spotify, durationKey: "Duration", durationUnit: .milliseconds)
    }

    /// `com.apple.Music.playerInfo`. Total Time is milliseconds.
    public static func appleMusic(_ fields: [String: String]) -> Track? {
        parse(fields, source: .appleMusic, durationKey: "Total Time", durationUnit: .milliseconds)
    }

    public static func parseDuration(_ raw: String, unit: DurationUnit) -> TimeInterval? {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(cleaned), value >= 0, value.isFinite else { return nil }
        switch unit {
        case .milliseconds: return value / 1000
        case .seconds: return value
        }
    }

    private static func parse(
        _ fields: [String: String],
        source: PlaybackSource,
        durationKey: String,
        durationUnit: DurationUnit
    ) -> Track? {
        let state = field(fields, "Player State") ?? ""
        let title = field(fields, "Name") ?? field(fields, "Track") ?? ""
        if state.isEmpty, title.isEmpty { return nil }
        let artist = field(fields, "Artist") ?? ""
        let album = field(fields, "Album") ?? ""
        let duration = field(fields, durationKey).flatMap { parseDuration($0, unit: durationUnit) }
        let trackID = nonempty(field(fields, "Track ID") ?? field(fields, "PersistentID"))
        return Track(
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            source: source,
            status: PlaybackStatus(scriptOrNotification: state),
            trackID: trackID
        )
    }

    private static func field(_ fields: [String: String], _ key: String) -> String? {
        if let value = fields[key] { return value }
        let lowered = key.lowercased()
        return fields.first { $0.key.lowercased() == lowered }?.value
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

public enum PlaybackScriptParser {
    /// Parses the line-oriented snapshot returned by Quay's AppleScript.
    /// Lines: state, title, artist, album, duration, track id.
    public static func parse(source: PlaybackSource, output: String, durationUnit: DurationUnit) -> Track? {
        var lines = output
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
        if lines.last?.isEmpty == true {
            lines.removeLast()
        }
        lines = lines.map { $0.trimmingCharacters(in: .whitespaces) }
        guard let first = lines.first, !first.isEmpty else { return nil }
        if first.lowercased() == "not running" {
            return Track(
                title: "",
                artist: "",
                album: "",
                duration: nil,
                source: source,
                status: .stopped,
                trackID: nil
            )
        }
        let title = lines.count > 1 ? lines[1] : ""
        let artist = lines.count > 2 ? lines[2] : ""
        let album = lines.count > 3 ? lines[3] : ""
        let duration = lines.count > 4
            ? PlaybackNotificationParser.parseDuration(lines[4], unit: durationUnit)
            : nil
        let trackID = lines.count > 5 ? nonempty(lines[5]) : nil
        return Track(
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            source: source,
            status: PlaybackStatus(scriptOrNotification: first),
            trackID: trackID
        )
    }

    private static func nonempty(_ value: String) -> String? {
        value.isEmpty ? nil : value
    }
}

public struct NowPlayingBoard: Equatable, Sendable {
    public private(set) var tracks: [PlaybackSource: Track]
    public private(set) var updatedAt: [PlaybackSource: Date]

    public init(
        tracks: [PlaybackSource: Track] = [:],
        updatedAt: [PlaybackSource: Date] = [:]
    ) {
        self.tracks = tracks
        self.updatedAt = updatedAt
    }

    public mutating func apply(_ track: Track, at date: Date) {
        tracks[track.source] = track
        updatedAt[track.source] = date
    }

    /// Prefer a playing source. Otherwise prefer the most recently updated track that still has a title.
    public func current() -> Track? {
        let values = Array(tracks.values)
        if let playing = latest(values.filter { $0.status == .playing }) {
            return playing
        }
        return latest(values.filter { !$0.title.isEmpty })
    }

    private func latest(_ tracks: [Track]) -> Track? {
        tracks.max { lhs, rhs in
            let left = updatedAt[lhs.source] ?? .distantPast
            let right = updatedAt[rhs.source] ?? .distantPast
            if left == right { return lhs.source.rawValue > rhs.source.rawValue }
            return left < right
        }
    }
}
