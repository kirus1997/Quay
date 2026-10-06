import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationPresenter.shared.prepare()
        let runtime = QuayRuntime.shared
        runtime.timers.start()
        let panel = DockPanelController()
        runtime.dockPanel = panel
        panel.start()
        runtime.bindWidgets()
        QuayActions.showDock = {
            QuayRuntime.shared.dockPanel?.show()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
