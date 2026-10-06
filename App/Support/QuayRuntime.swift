import Foundation
import QuayCore

@MainActor
final class QuayRuntime {
    static let shared = QuayRuntime()

    let dock: DockModel
    let timers: TimerModel
    let nowPlaying: NowPlayingModel
    let events: EventsModel
    var dockPanel: DockPanelController?

    private init() {
        let directory = (try? QuayFiles.supportDirectory())
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("Quay", isDirectory: true)
        dock = DockModel(store: DockStore(fileURL: directory.appendingPathComponent(QuayFiles.dockFileName)))
        timers = TimerModel(store: JSONFileStore(fileURL: directory.appendingPathComponent(QuayFiles.activityFileName)))
        nowPlaying = NowPlayingModel()
        events = EventsModel()
    }

    func bindWidgets() {
        dock.onChange = {
            Task { @MainActor in
                QuayRuntime.shared.applyWidgetVisibility()
            }
        }
        applyWidgetVisibility()
    }

    func applyWidgetVisibility() {
        nowPlaying.setEnabled(dock.configuration.hasWidget(.nowPlaying))
        events.setEnabled(dock.configuration.hasWidget(.upcomingEvents))
    }
}
