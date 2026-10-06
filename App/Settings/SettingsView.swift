import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var dock: DockModel
    @State private var page: Page = .dock
    @State private var selection: UUID?
    @State private var pickingApps = false
    @State private var pickingForCollection = false
    @State private var collectionDraft = ""
    @State private var ignoreNextDraftChange = false

    private enum Page: String, CaseIterable, Identifiable {
        case dock = "Dock"
        case about = "About"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            switch page {
            case .dock:
                dockPage
            case .about:
                aboutPage
            }
        }
        .frame(width: 720, height: 520)
        .onChange(of: dock.configuration.slots.map(\.id)) { _, ids in
            if let selection, !ids.contains(selection) {
                self.selection = nil
            }
            syncCollectionDraft()
        }
        .onChange(of: selection) { previous, _ in
            if let previous {
                dock.renameCollection(slotID: previous, to: collectionDraft)
            }
            syncCollectionDraft()
        }
        .onAppear(perform: syncCollectionDraft)
        .sheet(isPresented: $pickingApps) {
            AppPickerSheet(
                isAdded: { path in
                    if pickingForCollection, let selection {
                        return collectionApps(slotID: selection).contains { DockApp.samePath($0.path, path) }
                    }
                    return dock.configuration.containsApp(path: path)
                },
                onAdd: { app in
                    if pickingForCollection, let selection {
                        return dock.addApp(app, toCollectionSlot: selection)
                    }
                    let added = dock.addApp(app)
                    if added, let id = dock.configuration.slots.last?.id {
                        self.selection = id
                    }
                    return added
                }
            )
        }
    }

    private var header: some View {
        HStack {
            Text("Quay")
                .font(.title2.weight(.semibold))
            Spacer()
            Picker("Section", selection: $page) {
                ForEach(Page.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
            .labelsHidden()
        }
        .padding(16)
    }

    private var dockPage: some View {
        HStack(spacing: 0) {
            slotList
            Divider()
            editor
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var slotList: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(dock.configuration.slots) { slot in
                    HStack(spacing: 8) {
                        Image(systemName: symbol(for: slot))
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(slot.title)
                                .lineLimit(1)
                            Text(kindLabel(for: slot))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(slot.id)
                }
                .onMove { offsets, destination in
                    dock.move(from: offsets, to: destination)
                }
            }
            HStack(spacing: 8) {
                Button {
                    moveSelection(-1)
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(selection == nil)
                .help("Move up")

                Button {
                    moveSelection(1)
                } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(selection == nil)
                .help("Move down")

                Spacer()

                Menu {
                    Button("App…") {
                        pickingForCollection = false
                        pickingApps = true
                    }
                    Button("Collection") {
                        let id = dock.addCollection()
                        selection = id
                    }
                    Menu("Widget") {
                        ForEach(WidgetKind.allCases, id: \.self) { kind in
                            Button(kind.title) {
                                if let id = dock.addWidget(kind) {
                                    selection = id
                                }
                            }
                            .disabled(dock.configuration.hasWidget(kind))
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add")

                Button(role: .destructive) {
                    removeSelection()
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(selection == nil)
                .help("Remove")
            }
            .padding(10)
        }
        .frame(width: 250)
    }

    @ViewBuilder
    private var editor: some View {
        if let slot = selectedSlot {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch slot.content {
                    case .app(let app):
                        appEditor(app, slotID: slot.id)
                    case .collection(let collection):
                        collectionEditor(collection, slotID: slot.id)
                    case .widget(let kind):
                        widgetEditor(kind, slotID: slot.id)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Text("Select a slot, or add an app, collection, or widget.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func appEditor(_ app: DockApp, slotID: UUID) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(app.name, systemImage: "app")
                .font(.title3.weight(.semibold))
            LabeledContent("Bundle ID", value: app.bundleIdentifier ?? "None")
            LabeledContent("Path") {
                Text(app.path)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.trailing)
            }
            if !FileManager.default.fileExists(atPath: app.path) {
                Text("Quay can't find this app at the saved path.")
                    .foregroundStyle(.orange)
            }
            Button("Remove from Dock", role: .destructive) {
                dock.removeSlot(id: slotID)
            }
        }
    }

    private func collectionEditor(_ collection: AppCollection, slotID: UUID) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Collection")
                .font(.title3.weight(.semibold))
            TextField("Name", text: $collectionDraft)
                .textFieldStyle(.roundedBorder)
                .onSubmit { commitCollectionName(slotID) }
                .onChange(of: collectionDraft) { _, newValue in
                    if ignoreNextDraftChange {
                        ignoreNextDraftChange = false
                        return
                    }
                    dock.renameCollection(slotID: slotID, to: newValue)
                }
            if collection.apps.isEmpty {
                Text("This collection is empty.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(collection.apps.enumerated()), id: \.element.id) { index, app in
                    HStack {
                        AppIconView(path: app.path, size: 20)
                        Text(app.name)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            moveApp(in: slotID, direction: -1, index: index, count: collection.apps.count)
                        } label: {
                            Image(systemName: "chevron.up")
                        }
                        .buttonStyle(.borderless)
                        .disabled(index == 0)
                        Button {
                            moveApp(in: slotID, direction: 1, index: index, count: collection.apps.count)
                        } label: {
                            Image(systemName: "chevron.down")
                        }
                        .buttonStyle(.borderless)
                        .disabled(index == collection.apps.count - 1)
                        Button(role: .destructive) {
                            dock.removeApp(appID: app.id, fromCollectionSlot: slotID)
                        } label: {
                            Image(systemName: "minus")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            HStack {
                Button("Add Apps…") {
                    pickingForCollection = true
                    selection = slotID
                    pickingApps = true
                }
                Button("Remove Collection", role: .destructive) {
                    dock.removeSlot(id: slotID)
                }
            }
        }
    }

    private func widgetEditor(_ kind: WidgetKind, slotID: UUID) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(kind.title)
                .font(.title3.weight(.semibold))
            Text(kind.summary)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Quay keeps a single \(kind.title) widget on the dock.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Remove Widget", role: .destructive) {
                dock.removeSlot(id: slotID)
            }
        }
    }

    private var aboutPage: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quay")
                .font(.largeTitle.weight(.semibold))
            Text("Version \(AppVersion.marketing) (\(AppVersion.build))")
                .foregroundStyle(.secondary)
            Text("A floating dock for the apps and widgets you keep coming back to. Quay stays on this Mac: no account, no analytics, and no network.")
                .fixedSize(horizontal: false, vertical: true)
            Text(storageLine)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var storageLine: String {
        if let directory = try? QuayFiles.supportDirectory() {
            return "The dock layout is saved in \(directory.path)."
        }
        return "The dock layout is saved in Application Support."
    }

    private var selectedSlot: DockSlot? {
        guard let selection else { return nil }
        return dock.configuration.slots.first { $0.id == selection }
    }

    private func collectionApps(slotID: UUID) -> [DockApp] {
        guard let slot = dock.configuration.slots.first(where: { $0.id == slotID }),
              case .collection(let collection) = slot.content else {
            return []
        }
        return collection.apps
    }

    private func syncCollectionDraft() {
        guard let selection,
              let slot = dock.configuration.slots.first(where: { $0.id == selection }),
              case .collection(let collection) = slot.content else {
            return
        }
        guard collectionDraft != collection.name else { return }
        ignoreNextDraftChange = true
        collectionDraft = collection.name
    }

    private func commitCollectionName(_ slotID: UUID) {
        dock.renameCollection(slotID: slotID, to: collectionDraft)
        syncCollectionDraft()
    }

    private func moveSelection(_ direction: Int) {
        guard let selection else { return }
        dock.moveSlot(id: selection, direction: direction)
    }

    private func removeSelection() {
        guard let selection else { return }
        dock.removeSlot(id: selection)
        self.selection = nil
    }

    private func moveApp(in slotID: UUID, direction: Int, index: Int, count: Int) {
        let target = index + direction
        guard target >= 0, target < count else { return }
        let source = IndexSet(integer: index)
        let destination = direction < 0 ? target : target + 1
        dock.moveApps(inCollectionSlot: slotID, from: source, to: destination)
    }

    private func symbol(for slot: DockSlot) -> String {
        switch slot.content {
        case .app:
            return "app"
        case .collection:
            return "square.stack.3d.up"
        case .widget(.nowPlaying):
            return "music.note"
        case .widget(.timer):
            return "timer"
        case .widget(.upcomingEvents):
            return "calendar"
        }
    }

    private func kindLabel(for slot: DockSlot) -> String {
        switch slot.content {
        case .app:
            return "App"
        case .collection:
            return "Collection"
        case .widget:
            return "Widget"
        }
    }
}
