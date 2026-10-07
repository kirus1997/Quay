import AppKit

enum AppLauncher {
    static func open(_ path: String) {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            if let error {
                QuayLog.general.error("Could not open \(path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
