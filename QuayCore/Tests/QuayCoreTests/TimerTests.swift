import XCTest
import QuayCore

final class TimerTests: XCTestCase {
    func testCountdownCompletesOnce() {
        var timer = CountdownTimer(duration: 10)
        let start = Date(timeIntervalSince1970: 5_000)
        XCTAssertTrue(timer.start(at: start))
        XCTAssertFalse(timer.start(at: start.addingTimeInterval(1)))
        XCTAssertFalse(timer.refresh(at: start.addingTimeInterval(4)))
        XCTAssertEqual(timer.remaining, 6, accuracy: 0.001)
        XCTAssertTrue(timer.refresh(at: start.addingTimeInterval(10)))
        XCTAssertTrue(timer.didComplete)
        XCTAssertFalse(timer.isRunning)
        XCTAssertEqual(timer.remaining, 0)
        XCTAssertFalse(timer.refresh(at: start.addingTimeInterval(12)))
    }

    func testPausePreservesRemainingAndCanFinish() {
        var timer = CountdownTimer(duration: 100)
        let start = Date(timeIntervalSince1970: 1_000)
        XCTAssertTrue(timer.start(at: start))
        XCTAssertFalse(timer.setDuration(15))
        XCTAssertFalse(timer.pause(at: start.addingTimeInterval(40)))
        XCTAssertFalse(timer.isRunning)
        XCTAssertEqual(timer.remaining, 60, accuracy: 0.001)
        XCTAssertTrue(timer.start(at: Date(timeIntervalSince1970: 2_000)))
        XCTAssertEqual(timer.endDate, Date(timeIntervalSince1970: 2_060))
        XCTAssertTrue(timer.pause(at: Date(timeIntervalSince1970: 2_060)))
        XCTAssertTrue(timer.didComplete)
    }

    func testResetAndCustomDuration() {
        var timer = CountdownTimer(duration: 30)
        XCTAssertTrue(timer.start(at: Date(timeIntervalSince1970: 10)))
        timer.reset()
        XCTAssertEqual(timer.remaining, 30)
        XCTAssertFalse(timer.didComplete)
        XCTAssertFalse(timer.isRunning)
        XCTAssertNil(DurationInput.seconds(hours: 0, minutes: 0, seconds: 0))
        XCTAssertNil(DurationInput.seconds(hours: 0, minutes: 60, seconds: 0))
        XCTAssertNil(DurationInput.seconds(hours: -1, minutes: 0, seconds: 1))
        let custom = DurationInput.seconds(hours: 1, minutes: 2, seconds: 3)
        XCTAssertEqual(custom, 3723)
        XCTAssertTrue(timer.setDuration(custom!))
        XCTAssertEqual(timer.remaining, 3723)
        timer.remaining = 0
        XCTAssertFalse(timer.start(at: Date(timeIntervalSince1970: 1)))
    }

    func testStopwatchStartPauseResumeReset() {
        var watch = Stopwatch()
        let start = Date(timeIntervalSince1970: 100)
        XCTAssertEqual(watch.elapsed(at: start), 0)
        watch.start(at: start)
        watch.start(at: start.addingTimeInterval(5))
        XCTAssertEqual(watch.elapsed(at: start.addingTimeInterval(5)), 5, accuracy: 0.001)
        watch.pause(at: start.addingTimeInterval(2))
        XCTAssertEqual(watch.elapsed(at: start.addingTimeInterval(10)), 2, accuracy: 0.001)
        watch.start(at: start.addingTimeInterval(10))
        XCTAssertEqual(watch.elapsed(at: start.addingTimeInterval(11.5)), 3.5, accuracy: 0.001)
        watch.reset()
        XCTAssertFalse(watch.isRunning)
        XCTAssertEqual(watch.elapsed(at: start), 0)
        watch.pause(at: start)
        XCTAssertEqual(watch.accumulated, 0)
    }

    func testFormatting() {
        XCTAssertEqual(TimeFormatting.clock(0), "00:00")
        XCTAssertEqual(TimeFormatting.clock(59.9), "00:59")
        XCTAssertEqual(TimeFormatting.clock(60), "01:00")
        XCTAssertEqual(TimeFormatting.clock(3600), "1:00:00")
        XCTAssertEqual(TimeFormatting.clock(-4), "00:00")
        XCTAssertEqual(TimeFormatting.stopwatch(0), "00:00.0")
        XCTAssertEqual(TimeFormatting.stopwatch(0.1), "00:00.1")
        XCTAssertEqual(TimeFormatting.stopwatch(90), "01:30.0")
        XCTAssertEqual(TimeFormatting.stopwatch(3661), "1:01:01")
    }

    func testActivityPersistsAcrossReload() throws {
        let directory = try TestFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = JSONFileStore<ActivityState>(fileURL: directory.appendingPathComponent("activity.json"))
        var state = ActivityState()
        XCTAssertTrue(state.countdown.setDuration(90))
        XCTAssertTrue(state.countdown.start(at: Date(timeIntervalSince1970: 10_000)))
        state.stopwatch.start(at: Date(timeIntervalSince1970: 10_000))
        state.stopwatch.pause(at: Date(timeIntervalSince1970: 10_012))
        try store.save(state)
        XCTAssertEqual(try store.load(), state)

        try Data("{".utf8).write(to: store.fileURL)
        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? QuayStoreError, .corrupt)
        }
        XCTAssertNil(try JSONFileStore<ActivityState>(fileURL: directory.appendingPathComponent("missing.json")).load())
    }
}
