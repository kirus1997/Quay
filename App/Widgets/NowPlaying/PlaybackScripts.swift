import Foundation
import QuayCore

enum TransportAction {
    case toggle
    case next
    case previous
}

enum PlaybackScripts {
    static func snapshot(_ source: PlaybackSource) -> String {
        let app = source.scriptingName
        return """
        if application "\(app)" is running then
            tell application "\(app)"
                set playerStateText to player state as string
                set trackName to ""
                set trackArtist to ""
                set trackAlbum to ""
                set trackDuration to 0
                set trackKey to ""
                try
                    set trackName to name of current track
                    set trackArtist to artist of current track
                    set trackAlbum to album of current track
                    set trackDuration to duration of current track
                end try
                try
                    set trackKey to id of current track as string
                end try
                return playerStateText & linefeed & trackName & linefeed & trackArtist & linefeed & trackAlbum & linefeed & trackDuration & linefeed & trackKey
            end tell
        else
            return "not running"
        end if
        """
    }

    static func transport(_ action: TransportAction, source: PlaybackSource) -> String {
        let command: String
        switch action {
        case .toggle:
            command = "playpause"
        case .next:
            command = "next track"
        case .previous:
            command = "previous track"
        }
        return "tell application \"\(source.scriptingName)\" to \(command)"
    }

    static func artwork(_ source: PlaybackSource) -> String {
        let property: String
        switch source {
        case .spotify:
            property = "artwork of current track"
        case .appleMusic:
            property = "data of artwork 1 of current track"
        }
        let app = source.scriptingName
        return """
        if application "\(app)" is running then
            tell application "\(app)"
                try
                    return \(property)
                end try
            end tell
        end if
        return ""
        """
    }

    static func durationUnit(for source: PlaybackSource) -> DurationUnit {
        switch source {
        case .spotify:
            return .milliseconds
        case .appleMusic:
            return .seconds
        }
    }
}
