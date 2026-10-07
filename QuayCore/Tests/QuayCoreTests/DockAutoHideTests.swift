import XCTest
import QuayCore

final class DockAutoHideTests: XCTestCase {
    func testTimingAndStripStayInTheRequestedRange() {
        XCTAssertGreaterThanOrEqual(DockAutoHideLayout.stripThickness, 2)
        XCTAssertLessThanOrEqual(DockAutoHideLayout.stripThickness, 4)
        XCTAssertGreaterThanOrEqual(DockAutoHideLayout.slideDuration, 0.2)
        XCTAssertLessThanOrEqual(DockAutoHideLayout.slideDuration, 0.35)
        XCTAssertGreaterThanOrEqual(DockAutoHideLayout.hideDelay, 0.4)
        XCTAssertLessThanOrEqual(DockAutoHideLayout.hideDelay, 0.8)
    }

    func testRestingFrameSitsAboveTheVisibleBottomAndStripUsesTheDisplayEdge() {
        let resting = DockAutoHideLayout.restingFrame(
            contentWidth: 420,
            contentHeight: 140,
            visibleMinX: 0,
            visibleMinY: 80,
            visibleWidth: 1440
        )
        XCTAssertEqual(resting, DockRect(x: 510, y: 86, width: 420, height: 140))

        let concealed = DockAutoHideLayout.concealedFrame(resting: resting, screenMinY: 0)
        XCTAssertEqual(concealed.y + concealed.height, -1)
        XCTAssertEqual(concealed.x, resting.x)
        XCTAssertEqual(concealed.width, resting.width)

        let strip = DockAutoHideLayout.stripFrame(matching: resting, screenMinY: 0)
        XCTAssertEqual(strip, DockRect(x: 510, y: 0, width: 420, height: 3))
        XCTAssertTrue(strip.contains(x: 510, y: 0))
        XCTAssertFalse(strip.contains(x: 510, y: 3))
    }

    func testLayoutFollowsADisplayWhoseBottomIsNotZero() {
        let resting = DockAutoHideLayout.restingFrame(
            contentWidth: 2000,
            contentHeight: 100,
            visibleMinX: 100,
            visibleMinY: 180,
            visibleWidth: 1000
        )
        XCTAssertEqual(resting.width, 984)
        XCTAssertEqual(resting.x, 108)
        XCTAssertEqual(resting.y, 186)

        let concealed = DockAutoHideLayout.concealedFrame(resting: resting, screenMinY: 100)
        XCTAssertLessThanOrEqual(concealed.y + concealed.height, 100)
        XCTAssertEqual(DockAutoHideLayout.stripFrame(matching: resting, screenMinY: 100).y, 100)
    }

    func testHoverShowsAndLeaveHidesAfterTheDelay() {
        var state = DockAutoHideState()
        XCTAssertEqual(state.send(.pointerEntered), .reveal)
        XCTAssertTrue(state.revealed)
        XCTAssertFalse(state.hideScheduled)

        XCTAssertEqual(state.send(.pointerExited), .none)
        XCTAssertTrue(state.hideScheduled)
        XCTAssertTrue(state.revealed)

        XCTAssertEqual(state.send(.hideDelayFired), .conceal)
        XCTAssertFalse(state.revealed)
        XCTAssertFalse(state.hideScheduled)
    }

    func testReenteringDuringTheDelayCancelsTheHide() {
        var state = DockAutoHideState(revealed: true, pointerInside: true)
        _ = state.send(.pointerExited)
        XCTAssertTrue(state.hideScheduled)
        XCTAssertEqual(state.send(.pointerEntered), .none)
        XCTAssertFalse(state.hideScheduled)
        XCTAssertEqual(state.send(.hideDelayFired), .none)
        XCTAssertTrue(state.revealed)
    }

    func testPopoverKeepsTheDockVisibleUntilItCloses() {
        var state = DockAutoHideState()
        XCTAssertEqual(state.send(.popoverBegan), .reveal)
        XCTAssertEqual(state.send(.pointerExited), .none)
        XCTAssertFalse(state.hideScheduled)

        _ = state.send(.popoverBegan)
        XCTAssertEqual(state.send(.popoverEnded), .none)
        XCTAssertFalse(state.hideScheduled)
        XCTAssertEqual(state.popoverCount, 1)

        XCTAssertEqual(state.send(.popoverEnded), .none)
        XCTAssertTrue(state.hideScheduled)
        XCTAssertTrue(state.revealed)
        XCTAssertEqual(state.send(.hideDelayFired), .conceal)
    }

    func testPopoverCloseWhilePointerRemainsDoesNotHide() {
        var state = DockAutoHideState(revealed: true, pointerInside: true, popoverCount: 1)
        XCTAssertEqual(state.send(.popoverEnded), .none)
        XCTAssertFalse(state.hideScheduled)
        XCTAssertTrue(state.revealed)
    }

    func testTurningAutoHideOffPinsTheDockAndOnConcealsIt() {
        var state = DockAutoHideState(revealed: true, pointerInside: true)
        XCTAssertEqual(state.send(.setAutoHides(false)), .pinVisible)
        XCTAssertEqual(state.send(.pointerExited), .none)
        XCTAssertFalse(state.hideScheduled)
        XCTAssertTrue(state.revealed)

        XCTAssertEqual(state.send(.setAutoHides(true)), .conceal)
        XCTAssertFalse(state.revealed)
    }

    func testEnablingAutoHideWhileAPopoverIsOpenStaysRevealed() {
        var state = DockAutoHideState(autoHides: false, revealed: true, popoverCount: 1)
        XCTAssertEqual(state.send(.setAutoHides(true)), .reveal)
        XCTAssertTrue(state.revealed)
        XCTAssertFalse(state.hideScheduled)
    }

    func testShowRequestedRevealsAndArmsTheHideDelay() {
        var state = DockAutoHideState()
        XCTAssertEqual(state.send(.showRequested), .reveal)
        XCTAssertTrue(state.revealed)
        XCTAssertTrue(state.hideScheduled)

        var hovering = DockAutoHideState(revealed: true, pointerInside: true)
        XCTAssertEqual(hovering.send(.showRequested), .reveal)
        XCTAssertFalse(hovering.hideScheduled)
    }

    func testFreshDefaultHidesAutomatically() {
        XCTAssertTrue(DockConfiguration.freshDefault().autoHides)
    }

    func testSavedDockWithoutTheFlagDefaultsToAutoHide() throws {
        let json = """
        {"schemaVersion":1,"slots":[],"autoHides":false}
        """.data(using: .utf8)!
        let disabled = try QuayJSON.makeDecoder().decode(DockConfiguration.self, from: json)
        XCTAssertFalse(disabled.autoHides)

        let legacy = """
        {"schemaVersion":1,"slots":[]}
        """.data(using: .utf8)!
        let decoded = try QuayJSON.makeDecoder().decode(DockConfiguration.self, from: legacy)
        XCTAssertTrue(decoded.autoHides)

        let data = try QuayJSON.makeEncoder().encode(disabled)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("\"autoHides\" : false"))
        XCTAssertEqual(try QuayJSON.makeDecoder().decode(DockConfiguration.self, from: data).autoHides, false)
    }
}
