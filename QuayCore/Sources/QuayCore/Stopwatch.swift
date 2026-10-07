import Foundation

public struct Stopwatch: Equatable, Codable, Sendable {
    public var accumulated: TimeInterval
    public var runningSince: Date?

    public init(accumulated: TimeInterval = 0, runningSince: Date? = nil) {
        self.accumulated = max(0, accumulated)
        self.runningSince = runningSince
    }

    public var isRunning: Bool { runningSince != nil }

    public mutating func start(at now: Date) {
        guard runningSince == nil else { return }
        runningSince = now
    }

    public mutating func pause(at now: Date) {
        guard let runningSince else { return }
        accumulated += max(0, now.timeIntervalSince(runningSince))
        self.runningSince = nil
    }

    public mutating func reset() {
        accumulated = 0
        runningSince = nil
    }

    public func elapsed(at now: Date) -> TimeInterval {
        let extra = runningSince.map { max(0, now.timeIntervalSince($0)) } ?? 0
        return accumulated + extra
    }
}

public struct ActivityState: Codable, Equatable, Sendable {
    public var countdown: CountdownTimer
    public var stopwatch: Stopwatch

    public init(countdown: CountdownTimer = CountdownTimer(), stopwatch: Stopwatch = Stopwatch()) {
        self.countdown = countdown
        self.stopwatch = stopwatch
    }
}
