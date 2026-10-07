import Combine
import Foundation
import QuayCore

@MainActor
final class TimerModel: ObservableObject {
    @Published private(set) var countdown: CountdownTimer
    @Published private(set) var stopwatch: Stopwatch
    @Published private(set) var displayedNow = Date()

    private let store: JSONFileStore<ActivityState>
    private var ticker: Timer?

    init(store: JSONFileStore<ActivityState>) {
        self.store = store
        if let loaded = try? store.load() {
            countdown = loaded.countdown
            stopwatch = loaded.stopwatch
        } else {
            countdown = CountdownTimer()
            stopwatch = Stopwatch()
        }
    }

    func start() {
        displayedNow = Date()
        if countdown.refresh(at: displayedNow) {
            NotificationPresenter.shared.announceTimerFinished()
            persist()
        }
        syncTicker()
    }

    func toggleCountdown() {
        if countdown.isRunning {
            _ = countdown.pause(at: Date())
        } else {
            NotificationPresenter.shared.requestAuthorization()
            _ = countdown.start(at: Date())
        }
        displayedNow = Date()
        persist()
        syncTicker()
    }

    func resetCountdown() {
        countdown.reset()
        displayedNow = Date()
        persist()
        syncTicker()
    }

    func setCountdown(_ seconds: TimeInterval) {
        guard countdown.setDuration(seconds) else { return }
        displayedNow = Date()
        persist()
    }

    func toggleStopwatch() {
        if stopwatch.isRunning {
            stopwatch.pause(at: Date())
        } else {
            stopwatch.start(at: Date())
        }
        displayedNow = Date()
        persist()
        syncTicker()
    }

    func resetStopwatch() {
        stopwatch.reset()
        displayedNow = Date()
        persist()
        syncTicker()
    }

    private func tick() {
        let now = Date()
        let fired = countdown.refresh(at: now)
        displayedNow = now
        if fired {
            NotificationPresenter.shared.announceTimerFinished()
            persist()
        }
        syncTicker()
    }

    private func syncTicker() {
        let shouldRun = countdown.isRunning || stopwatch.isRunning
        if shouldRun, ticker == nil {
            let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.tick()
                }
            }
            timer.tolerance = 0.05
            RunLoop.main.add(timer, forMode: .common)
            ticker = timer
        } else if !shouldRun {
            ticker?.invalidate()
            ticker = nil
        }
    }

    private func persist() {
        do {
            try store.save(ActivityState(countdown: countdown, stopwatch: stopwatch))
        } catch {
            QuayLog.general.error("Could not save the timer: \(error.localizedDescription, privacy: .public)")
        }
    }
}
