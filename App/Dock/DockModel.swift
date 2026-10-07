import Combine
import Foundation
import QuayCore

@MainActor
final class DockModel: ObservableObject {
    @Published private(set) var configuration: DockConfiguration
    var onChange: (() -> Void)?

    private let store: DockStore

    init(store: DockStore) {
        self.store = store
        configuration = store.loadOrCreate()
    }

    @discardableResult
    func addApp(_ app: DockApp) -> Bool {
        var accepted = false
        mutate { accepted = $0.addApp(app) }
        return accepted
    }

    @discardableResult
    func addWidget(_ kind: WidgetKind) -> UUID? {
        var created: UUID?
        mutate { created = $0.addWidget(kind) }
        return created
    }

    @discardableResult
    func addCollection(named name: String = "Collection") -> UUID {
        var created = UUID()
        mutate { created = $0.addCollection(named: name) }
        return created
    }

    func removeSlot(id: UUID) {
        mutate { _ = $0.removeSlot(id: id) }
    }

    func moveSlot(id: UUID, direction: Int) {
        mutate { _ = $0.moveSlot(id: id, direction: direction) }
    }

    func move(from offsets: IndexSet, to destination: Int) {
        mutate { $0.moveSlots(fromOffsets: offsets, toOffset: destination) }
    }

    func renameCollection(slotID: UUID, to name: String) {
        mutate { _ = $0.renameCollection(slotID: slotID, to: name) }
    }

    @discardableResult
    func addApp(_ app: DockApp, toCollectionSlot slotID: UUID) -> Bool {
        var accepted = false
        mutate { accepted = $0.addApp(app, toCollectionSlot: slotID) }
        return accepted
    }

    func removeApp(appID: UUID, fromCollectionSlot slotID: UUID) {
        mutate { _ = $0.removeApp(appID: appID, fromCollectionSlot: slotID) }
    }

    func moveApps(inCollectionSlot slotID: UUID, from offsets: IndexSet, to destination: Int) {
        mutate { _ = $0.moveApps(inCollectionSlot: slotID, fromOffsets: offsets, toOffset: destination) }
    }

    func setAutoHides(_ enabled: Bool) {
        mutate { $0.autoHides = enabled }
    }

    private func mutate(_ body: (inout DockConfiguration) -> Void) {
        var next = configuration
        body(&next)
        guard next != configuration else { return }
        configuration = next
        do {
            try store.save(configuration)
        } catch {
            QuayLog.general.error("Could not save the dock: \(error.localizedDescription, privacy: .public)")
        }
        onChange?()
    }
}
