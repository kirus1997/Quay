import XCTest
import QuayCore

final class PlaybackTests: XCTestCase {
    func testSpotifyNotification() {
        let track = PlaybackNotificationParser.spotify([
            "Player State": "Playing",
            "Name": "Harbor",
            "Artist": "North",
            "Album": "Quay",
            "Duration": "180000",
            "Track ID": "spotify:track:abc",
        ])
        XCTAssertEqual(track?.title, "Harbor")
        XCTAssertEqual(track?.artist, "North")
        XCTAssertEqual(track?.album, "Quay")
        XCTAssertEqual(track?.duration, 180)
        XCTAssertEqual(track?.status, .playing)
        XCTAssertEqual(track?.source, .spotify)
        XCTAssertEqual(track?.trackID, "spotify:track:abc")
    }

    func testAppleMusicNotification() {
        let track = PlaybackNotificationParser.appleMusic([
            "player state": "Paused",
            "Name": "Lamp",
            "Artist": "Pier",
            "Total Time": "210000",
        ])
        XCTAssertEqual(track?.status, .paused)
        XCTAssertEqual(track?.duration, 210)
        XCTAssertEqual(track?.source, .appleMusic)
        XCTAssertNil(PlaybackNotificationParser.appleMusic([:]))
        XCTAssertEqual(
            PlaybackNotificationParser.spotify(["Player State": "Stopped"])?.status,
            .stopped
        )
    }

    func testScriptSnapshotAndPlayerConstants() {
        let output = "playing\nHarbor\nNorth\nQuay\n180000\nspotify:track:abc\n"
        let track = PlaybackScriptParser.parse(source: .spotify, output: output, durationUnit: .milliseconds)
        XCTAssertEqual(track?.duration, 180)
        XCTAssertEqual(track?.trackID, "spotify:track:abc")
        XCTAssertEqual(track?.status, .playing)

        let music = PlaybackScriptParser.parse(
            source: .appleMusic,
            output: "paused\nLamp\nPier\n\n245\n",
            durationUnit: .seconds
        )
        XCTAssertEqual(music?.duration, 245)
        XCTAssertNil(music?.trackID)
        XCTAssertEqual(music?.album, "")

        let idle = PlaybackScriptParser.parse(source: .spotify, output: "not running\n", durationUnit: .milliseconds)
        XCTAssertEqual(idle?.status, .stopped)
        XCTAssertEqual(idle?.title, "")
        XCTAssertNil(PlaybackScriptParser.parse(source: .spotify, output: "\n", durationUnit: .seconds))

        XCTAssertEqual(PlaybackStatus(scriptOrNotification: "«constant ****kPSP»"), .playing)
        XCTAssertEqual(PlaybackStatus(scriptOrNotification: "«constant ****kPSp»"), .paused)
    }

    func testBoardPrefersPlayingThenRecent() {
        var board = NowPlayingBoard()
        let music = Track(
            title: "Lamp",
            artist: "Pier",
            album: "",
            duration: nil,
            source: .appleMusic,
            status: .playing,
            trackID: "1"
        )
        let spotify = Track(
            title: "Harbor",
            artist: "North",
            album: "",
            duration: nil,
            source: .spotify,
            status: .paused,
            trackID: "2"
        )
        board.apply(music, at: Date(timeIntervalSince1970: 10))
        board.apply(spotify, at: Date(timeIntervalSince1970: 20))
        XCTAssertEqual(board.current()?.source, .appleMusic)

        var pausedMusic = music
        pausedMusic.status = .paused
        board.apply(pausedMusic, at: Date(timeIntervalSince1970: 30))
        XCTAssertEqual(board.current()?.title, "Lamp")

        var stopped = spotify
        stopped.status = .stopped
        stopped.title = ""
        board.apply(stopped, at: Date(timeIntervalSince1970: 40))
        XCTAssertEqual(board.current()?.source, .appleMusic)

        board.apply(Track(
            title: "",
            artist: "",
            album: "",
            duration: nil,
            source: .appleMusic,
            status: .stopped,
            trackID: nil
        ), at: Date(timeIntervalSince1970: 50))
        XCTAssertNil(board.current())
        XCTAssertNil(NowPlayingBoard().current())
    }

    func testAppleScriptImageData() {
        XCTAssertEqual(AppleScriptImage.decode("«data JPEGFFD8»"), Data([0xFF, 0xD8]))
        XCTAssertEqual(AppleScriptImage.decode("  «data JPEGFF D8»  "), Data([0xFF, 0xD8]))
        XCTAssertNil(AppleScriptImage.decode("missing value"))
        XCTAssertNil(AppleScriptImage.decode(""))
        XCTAssertNil(AppleScriptImage.decode("«data JPEGXYZ»"))
        XCTAssertNil(AppleScriptImage.decode("«data FF»"))
    }
}
