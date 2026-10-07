import Combine
import Foundation
import QuayCore

@MainActor
final class NowPlayingModel: ObservableObject {
    @Published private(set) var track: Track?
    @Published private(set) var artwork: Data?
    @Published private(set) var automationDenied = false

    private let notifications = PlaybackNotifications()
    private var board = NowPlayingBoard()
    private var refreshGeneration = 0

    func setEnabled(_ enabled: Bool) {
        refreshGeneration += 1
        let generation = refreshGeneration
        if !enabled {
            notifications.stop()
            track = nil
            artwork = nil
            automationDenied = false
            board = NowPlayingBoard()
            return
        }
        if notifications.onSpotify == nil {
            notifications.onSpotify = { [weak self] fields in
                Task { @MainActor in
                    self?.ingest(.spotify, fields: fields)
                }
            }
            notifications.onMusic = { [weak self] fields in
                Task { @MainActor in
                    self?.ingest(.appleMusic, fields: fields)
                }
            }
        }
        notifications.start()
        Task {
            await self.pull(.spotify, generation: generation)
            guard generation == self.refreshGeneration else { return }
            await self.pull(.appleMusic, generation: generation)
        }
    }

    func perform(_ action: TransportAction) {
        let source = track?.source ?? .spotify
        let generation = refreshGeneration
        Task {
            let result = await AppleScriptRunner.run(PlaybackScripts.transport(action, source: source))
            guard generation == self.refreshGeneration else { return }
            if AppleScriptRunner.isDenied(result) {
                automationDenied = true
                return
            }
            if result.status == 0 {
                automationDenied = false
            }
            await pull(source, generation: generation)
        }
    }

    private func ingest(_ source: PlaybackSource, fields: [String: String]) {
        let parsed: Track?
        switch source {
        case .spotify:
            parsed = PlaybackNotificationParser.spotify(fields)
        case .appleMusic:
            parsed = PlaybackNotificationParser.appleMusic(fields)
        }
        guard let parsed else { return }
        board.apply(parsed, at: Date())
        publish()
    }

    private func pull(_ source: PlaybackSource, generation: Int) async {
        let result = await AppleScriptRunner.run(PlaybackScripts.snapshot(source))
        guard generation == refreshGeneration else { return }
        if AppleScriptRunner.isDenied(result) {
            automationDenied = true
            return
        }
        guard result.status == 0,
              let parsed = PlaybackScriptParser.parse(
                source: source,
                output: result.stdout,
                durationUnit: PlaybackScripts.durationUnit(for: source)
              )
        else { return }
        board.apply(parsed, at: Date())
        publish()
    }

    private func publish() {
        let next = board.current()
        let changed = next?.source != track?.source || next?.title != track?.title || next?.trackID != track?.trackID
        track = next
        guard changed else { return }
        artwork = nil
        guard let next, !next.title.isEmpty else { return }
        let generation = refreshGeneration
        Task { await self.loadArtwork(for: next, generation: generation) }
    }

    private func loadArtwork(for track: Track, generation: Int) async {
        let result = await AppleScriptRunner.run(PlaybackScripts.artwork(track.source))
        guard generation == refreshGeneration else { return }
        guard self.track?.source == track.source, self.track?.title == track.title else { return }
        if AppleScriptRunner.isDenied(result) {
            automationDenied = true
            return
        }
        guard result.stdout.count < 12_000_000,
              let data = AppleScriptImage.decode(result.stdout),
              !data.isEmpty
        else { return }
        artwork = data
    }
}

/// Selector-based observer so Spotify and Music notifications are delivered immediately while Quay is inactive.
final class PlaybackNotifications: NSObject {
    var onSpotify: (([String: String]) -> Void)?
    var onMusic: (([String: String]) -> Void)?
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        let center = DistributedNotificationCenter.default()
        center.addObserver(
            self,
            selector: #selector(spotify(_:)),
            name: Notification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
        center.addObserver(
            self,
            selector: #selector(music(_:)),
            name: Notification.Name("com.apple.Music.playerInfo"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
    }

    func stop() {
        guard started else { return }
        started = false
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func spotify(_ notification: Notification) {
        onSpotify?(UserInfoStrings.parse(notification.userInfo))
    }

    @objc private func music(_ notification: Notification) {
        onMusic?(UserInfoStrings.parse(notification.userInfo))
    }
}
