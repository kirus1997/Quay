import XCTest
import QuayCore

final class DockStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = try TestFixtures.temporaryDirectory()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testMissingFileCreatesDefault() throws {
        let store = DockStore(fileURL: directory.appendingPathComponent("dock.json"))
        XCTAssertNil(try store.load())
        let created = store.loadOrCreate()
        XCTAssertEqual(created.slots.compactMap(\.widgetKind), [.nowPlaying, .timer, .upcomingEvents])
        let loaded = try XCTUnwrap(try store.load())
        XCTAssertEqual(loaded, created)
    }

    func testRoundTripPreservesOrder() throws {
        let store = DockStore(fileURL: directory.appendingPathComponent("nested/dock.json"))
        var configuration = DockConfiguration(slots: [])
        XCTAssertTrue(configuration.addApp(TestFixtures.app(id: 1, name: "Mail", path: "/Applications/Mail.app")))
        _ = configuration.addWidget(.upcomingEvents)
        try store.save(configuration)
        XCTAssertEqual(try store.load(), configuration)
    }

    func testCorruptFileIsQuarantined() throws {
        let url = directory.appendingPathComponent(QuayFiles.dockFileName)
        try Data("{".utf8).write(to: url)
        let store = DockStore(fileURL: url)
        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? QuayStoreError, .corrupt)
        }
        _ = store.loadOrCreate()
        let backup = directory.appendingPathComponent("dock.json.bad")
        XCTAssertTrue(FileManager.default.fileExists(atPath: backup.path))
        let restored = try XCTUnwrap(try store.load())
        XCTAssertEqual(restored.slots.count, 3)
    }

    func testUnsupportedSchemaIsRejected() throws {
        let url = directory.appendingPathComponent("dock.json")
        let body = #"{"schemaVersion":99,"slots":[]}"#
        try Data(body.utf8).write(to: url)
        let store = DockStore(fileURL: url)
        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? QuayStoreError, .unsupportedSchema)
        }
    }

    func testLoadDropsDuplicateWidgets() throws {
        let url = directory.appendingPathComponent("dock.json")
        let body = """
        {
          "schemaVersion": 1,
          "slots": [
            {"id": "00000000-0000-0000-0000-000000000001", "type": "widget", "widget": "timer"},
            {"id": "00000000-0000-0000-0000-000000000002", "type": "widget", "widget": "timer"}
          ]
        }
        """
        try Data(body.utf8).write(to: url)
        let loaded = try XCTUnwrap(try DockStore(fileURL: url).load())
        XCTAssertEqual(loaded.slots.count, 1)
        XCTAssertTrue(loaded.autoHides)
    }

    func testAutoHideFlagRoundTripsAndDefaultsOn() throws {
        let url = directory.appendingPathComponent("dock.json")
        var configuration = DockConfiguration(slots: [], autoHides: false)
        let store = DockStore(fileURL: url)
        try store.save(configuration)
        XCTAssertEqual(try store.load()?.autoHides, false)

        configuration.autoHides = true
        try store.save(configuration)
        XCTAssertEqual(try store.load()?.autoHides, true)
    }
}
