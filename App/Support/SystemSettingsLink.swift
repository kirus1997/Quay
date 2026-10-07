import AppKit

enum SystemSettingsLink {
    enum Pane {
        case calendars
        case reminders
        case automation
        case notifications
    }

    static func open(_ pane: Pane) {
        let candidates: [String]
        switch pane {
        case .calendars:
            candidates = [
                "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Calendars",
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars",
            ]
        case .reminders:
            candidates = [
                "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Reminders",
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders",
            ]
        case .automation:
            candidates = [
                "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Automation",
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation",
            ]
        case .notifications:
            candidates = [
                "x-apple.systempreferences:com.apple.Notifications-Settings.extension",
                "x-apple.systempreferences:com.apple.preference.notifications",
            ]
        }
        for candidate in candidates {
            guard let url = URL(string: candidate) else { continue }
            if NSWorkspace.shared.open(url) { return }
        }
    }
}
