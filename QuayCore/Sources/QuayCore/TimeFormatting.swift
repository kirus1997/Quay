import Foundation

public enum TimeFormatting {
    public static func clock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    public static func stopwatch(_ interval: TimeInterval) -> String {
        let clamped = max(0, interval)
        let totalTenths = Int((clamped * 10).rounded(.toNearestOrEven))
        let tenths = totalTenths % 10
        let totalSeconds = totalTenths / 10
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }
}
