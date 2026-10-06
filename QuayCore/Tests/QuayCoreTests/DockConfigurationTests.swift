import XCTest
import QuayCore

final class DockConfigurationTests: XCTestCase {
    func testFreshDefaultHasOneOfEachWidget() {
        let configuration = DockConfiguration.freshDefault()
        XCTAssertEqual(configuration.schemaVersion, 1)
        XCTAssertTrue(configuration.autoHides)
        XCTAssertEqual(
            configuration.slots.compactMap(\.widgetKind),
            [.nowPlaying, .timer, .upcomingEvents]
        )
    }

    func testAddAppRejectsDuplicatePaths() {
        var configuration = DockConfiguration(slots: [])
        let notes = TestFixtures.app(id: 1, name: "Notes", path: "/Applications/Notes.app")
        XCTAssertTrue(configuration.addApp(notes))
        let again = TestFixtures.app(id: 2, name: "Notes copy", path: "/Applications/./Notes.app")
        XCTAssertFalse(configuration.addApp(again))
        XCTAssertEqual(configuration.slots.count, 1)
        XCTAssertTrue(configuration.containsApp(path: "/Applications/Notes.app/"))
    }

    func testWidgetKindsAreUnique() {
        var configuration = DockConfiguration(slots: [])
        XCTAssertNotNil(configuration.addWidget(.timer))
        XCTAssertNil(configuration.addWidget(.timer))
        XCTAssertEqual(configuration.slots.count, 1)
    }

    func testDuplicateWidgetsAreDroppedOnSanitize() {
        let first = DockSlot(id: TestFixtures.uuid(1), content: .widget(.timer))
        let second = DockSlot(id: TestFixtures.uuid(2), content: .widget(.timer))
        let app = DockSlot(id: TestFixtures.uuid(3), content: .app(TestFixtures.app(id: 4, name: "Mail", path: "/Applications/Mail.app")))
        let configuration = DockConfiguration(slots: [first, app, second]).removingDuplicateWidgets()
        XCTAssertEqual(configuration.slots.map { $0.id }, [first.id, app.id])
    }

    func testCollectionEditing() {
        var configuration = DockConfiguration(slots: [])
        let slotID = configuration.addCollection(named: "  ")
        XCTAssertEqual(configuration.slots.first?.title, "Collection")
        XCTAssertTrue(configuration.renameCollection(slotID: slotID, to: " Design "))
        XCTAssertEqual(configuration.slots.first?.title, "Design")

        let figma = TestFixtures.app(id: 5, name: "Figma", path: "/Applications/Figma.app")
        let sketch = TestFixtures.app(id: 6, name: "Sketch", path: "/Applications/Sketch.app")
        XCTAssertTrue(configuration.addApp(figma, toCollectionSlot: slotID))
        XCTAssertTrue(configuration.addApp(sketch, toCollectionSlot: slotID))
        XCTAssertFalse(configuration.addApp(figma, toCollectionSlot: slotID))
        XCTAssertTrue(configuration.removeApp(appID: figma.id, fromCollectionSlot: slotID))

        guard case .collection(let collection) = configuration.slots[0].content else {
            return XCTFail("Expected a collection")
        }
        XCTAssertEqual(collection.apps.map(\.name), ["Sketch"])
    }

    func testMoveSlotsMatchesIndexSetSemantics() {
        var configuration = DockConfiguration(slots: [
            DockSlot(id: TestFixtures.uuid(1), content: .app(TestFixtures.app(id: 11, name: "A", path: "/Applications/A.app"))),
            DockSlot(id: TestFixtures.uuid(2), content: .app(TestFixtures.app(id: 12, name: "B", path: "/Applications/B.app"))),
            DockSlot(id: TestFixtures.uuid(3), content: .app(TestFixtures.app(id: 13, name: "C", path: "/Applications/C.app"))),
            DockSlot(id: TestFixtures.uuid(4), content: .app(TestFixtures.app(id: 14, name: "D", path: "/Applications/D.app"))),
        ])
        configuration.moveSlots(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        XCTAssertEqual(configuration.slots.map { $0.title }, ["B", "C", "A", "D"])

        XCTAssertTrue(configuration.moveSlot(id: TestFixtures.uuid(4), direction: -1))
        XCTAssertEqual(configuration.slots.map { $0.title }, ["B", "C", "D", "A"])
        XCTAssertFalse(configuration.moveSlot(id: TestFixtures.uuid(2), direction: -1))
    }

    func testMoveAppsInsideCollection() {
        var configuration = DockConfiguration(slots: [])
        let slotID = configuration.addCollection(named: "Tools")
        let apps = [
            TestFixtures.app(id: 21, name: "A", path: "/Applications/A.app"),
            TestFixtures.app(id: 22, name: "B", path: "/Applications/B.app"),
            TestFixtures.app(id: 23, name: "C", path: "/Applications/C.app"),
        ]
        for app in apps {
            XCTAssertTrue(configuration.addApp(app, toCollectionSlot: slotID))
        }
        XCTAssertTrue(configuration.moveApps(inCollectionSlot: slotID, fromOffsets: IndexSet(integer: 2), toOffset: 0))
        guard case .collection(let collection) = configuration.slots[0].content else {
            return XCTFail("Expected a collection")
        }
        XCTAssertEqual(collection.apps.map(\.name), ["C", "A", "B"])
    }

    func testRemoveSlot() {
        var configuration = DockConfiguration.freshDefault()
        let id = configuration.slots[1].id
        XCTAssertTrue(configuration.removeSlot(id: id))
        XCTAssertFalse(configuration.hasWidget(.timer))
        XCTAssertFalse(configuration.removeSlot(id: id))
    }

    func testJSONRoundTrip() throws {
        var configuration = DockConfiguration(slots: [])
        let slotID = configuration.addCollection(named: "Harbor")
        XCTAssertTrue(configuration.addApp(
            TestFixtures.app(id: 30, name: "Notes", path: "/Applications/Notes.app"),
            toCollectionSlot: slotID
        ))
        XCTAssertNotNil(configuration.addWidget(.nowPlaying))
        let data = try QuayJSON.makeEncoder().encode(configuration)
        let decoded = try QuayJSON.makeDecoder().decode(DockConfiguration.self, from: data)
        XCTAssertEqual(decoded, configuration)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("\"schemaVersion\" : 1"))
        XCTAssertTrue(text.contains("\"type\" : \"collection\""))
        XCTAssertTrue(text.contains("\"widget\" : \"nowPlaying\""))
    }

    func testDecodeHandWrittenSlot() throws {
        let json = """
        {
          "schemaVersion": 1,
          "slots": [
            {
              "id": "00000000-0000-0000-0000-000000000008",
              "type": "widget",
              "widget": "timer"
            }
          ]
        }
        """.data(using: .utf8)!
        let configuration = try QuayJSON.makeDecoder().decode(DockConfiguration.self, from: json)
        XCTAssertEqual(configuration.slots.first?.widgetKind, .timer)
        XCTAssertTrue(configuration.autoHides)
    }
}
