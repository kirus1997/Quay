import AppKit

enum QuayActions {
    static var showDock: () -> Void = {}

    static func openSettings() {
        NSApp.activate()
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    static func focusDock() {
        showDock()
    }

    static func quit() {
        NSApp.terminate(nil)
    }
}
