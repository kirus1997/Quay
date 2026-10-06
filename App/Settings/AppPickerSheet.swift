import SwiftUI

struct AppPickerSheet: View {
    var isAdded: (String) -> Bool
    var onAdd: (DockApp) -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var apps: [InstalledApp] = []
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Applications")
                .font(.title3.weight(.semibold))
            TextField("Search", text: $query)
                .textFieldStyle(.roundedBorder)
            List(filtered) { app in
                HStack(spacing: 8) {
                    AppIconView(path: app.path, size: 28)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(app.name)
                        Text(app.bundleIdentifier ?? app.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if isAdded(app.path) {
                        Text("Added")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Add") {
                            _ = onAdd(app.makeDockApp())
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(minHeight: 280)
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 460, height: 460)
        .onAppear {
            if apps.isEmpty {
                apps = InstalledApps.scan()
            }
        }
    }

    private var filtered: [InstalledApp] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return apps }
        return apps.filter { app in
            app.name.localizedCaseInsensitiveContains(needle)
                || (app.bundleIdentifier?.localizedCaseInsensitiveContains(needle) ?? false)
        }
    }
}
