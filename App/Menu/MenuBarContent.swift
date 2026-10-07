import QuayCore
import SwiftUI

struct MenuBarContent: View {
    var body: some View {
        SettingsLink {
            Text("Settings…")
        }
        .keyboardShortcut(",", modifiers: .command)

        Button("Show Dock") {
            QuayActions.focusDock()
        }

        Divider()

        Button("Quit Quay") {
            QuayActions.quit()
        }
        .keyboardShortcut("q")
    }
}

enum AppVersion {
    static var marketing: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? QuayVersion.marketing
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? String(QuayVersion.build)
    }
}
