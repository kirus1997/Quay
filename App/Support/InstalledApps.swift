import Foundation

struct InstalledApp: Identifiable, Hashable {
    var name: String
    var bundleIdentifier: String?
    var path: String
    var id: String { path }

    func makeDockApp() -> DockApp {
        DockApp(name: name, bundleIdentifier: bundleIdentifier, path: path)
    }
}

enum InstalledApps {
    static func scan() -> [InstalledApp] {
        let fileManager = FileManager.default
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true),
        ]
        var found: [InstalledApp] = []
        for root in roots {
            found.append(contentsOf: apps(in: root, fileManager: fileManager, descend: true))
        }
        var seen = Set<String>()
        return found
            .filter { seen.insert(DockApp.normalize($0.path)).inserted }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func apps(in directory: URL, fileManager: FileManager, descend: Bool) -> [InstalledApp] {
        guard let items = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        var found: [InstalledApp] = []
        for url in items {
            if url.pathExtension == "app" {
                found.append(describe(url))
                continue
            }
            guard descend else { continue }
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }
            found.append(contentsOf: apps(in: url, fileManager: fileManager, descend: false))
        }
        return found
    }

    private static func describe(_ url: URL) -> InstalledApp {
        let bundle = Bundle(url: url)
        let display = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let bundleName = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
        let fallback = url.deletingPathExtension().lastPathComponent
        let name = preferredName(display) ?? preferredName(bundleName) ?? fallback
        return InstalledApp(name: name, bundleIdentifier: bundle?.bundleIdentifier, path: url.path)
    }

    private static func preferredName(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
