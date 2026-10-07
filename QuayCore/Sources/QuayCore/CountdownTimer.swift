import Foundation

public struct TimerPreset: Equatable, Identifiable, Sendable {
    public var name: String
    public var seconds: TimeInterval
    public var id: String { name }

    public init(name: String, seconds: TimeInterval) {
        self.name = name
        self.seconds = seconds
    }

    public static let quick: [TimerPreset] = [
        TimerPreset(name: "1m", seconds: 60),
        TimerPreset(name: "5m", seconds: 5 * 60),
        TimerPreset(name: "15m", seconds: 15 * 60),
        TimerPreset(name: "25m", seconds: 25 * 60),
    ]
}

public enum DurationInput {
    /// Returns a positive duration, or nil when the parts are out of range or zero.
    public static func seconds(hours: Int, minutes: Int, seconds: Int) -> TimeInterval? {
        guard (0...99).contains(hours), (0...59).contains(minutes), (0...59).contains(seconds) else {
            return nil
        }
        let total = TimeInterval((hours * 3600) + (minutes * 60) + seconds)
        guard total > 0 else { return nil }
        return total
    }
}

public struct CountdownTimer: Equatable, Codable, Sendable {
    public var duration: TimeInterval
    public var remaining: TimeInterval
    public var isRunning: Bool
    public var endDate: Date?
    public var didComplete: Bool

    public init(
        duration: TimeInterval = 5 * 60,
        remaining: TimeInterval? = nil,
        isRunning: Bool = false,
        endDate: Date? = nil,
        didComplete: Bool = false
    ) {
        let duration = max(0, duration)
        self.duration = duration
        self.remaining = max(0, remaining ?? duration)
        self.isRunning = isRunning
        self.endDate = endDate
        self.didComplete = didComplete
    }

    @discardableResult
    public mutating func setDuration(_ seconds: TimeInterval) -> Bool {
        guard !isRunning, seconds > 0 else { return false }
        duration = seconds
        remaining = seconds
        endDate = nil
        didComplete = false
        return true
    }

    @discardableResult
    public mutating func start(at now: Date) -> Bool {
        guard !isRunning, remaining > 0 else { return false }
        isRunning = true
        endDate = now.addingTimeInterval(remaining)
        didComplete = false
        return true
    }

    /// Pauses the countdown. Returns true when this call is the one that reaches zero.
    @discardableResult
    public mutating func pause(at now: Date) -> Bool {
        guard isRunning else { return false }
        let fired = refresh(at: now)
        if isRunning {
            isRunning = false
            endDate = nil
        }
        return fired
    }

    public mutating func reset() {
        isRunning = false
        endDate = nil
        remaining = duration
        didComplete = false
    }

    /// Updates `remaining` from `endDate`. Returns true the first time the countdown finishes.
    @discardableResult
    public mutating func refresh(at now: Date) -> Bool {
        guard isRunning, let endDate else { return false }
        if now >= endDate {
            remaining = 0
            isRunning = false
            self.endDate = nil
            if didComplete { return false }
            didComplete = true
            return true
        }
        remaining = endDate.timeIntervalSince(now)
        return false
    }
}
