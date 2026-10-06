import Foundation

public struct CalendarEventItem: Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var start: Date
    public var end: Date
    public var calendarName: String
    public var isAllDay: Bool

    public init(id: String, title: String, start: Date, end: Date, calendarName: String, isAllDay: Bool) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.calendarName = calendarName
        self.isAllDay = isAllDay
    }
}

public struct ReminderItem: Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var dueDate: Date?
    public var isCompleted: Bool
    public var listName: String

    public init(id: String, title: String, dueDate: Date?, isCompleted: Bool, listName: String) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.listName = listName
    }
}

public enum AgendaBuilder {
    public static let defaultEventLimit = 3
    public static let defaultReminderLimit = 2
    public static let horizon: TimeInterval = 7 * 24 * 60 * 60

    public static func upcomingEvents(
        _ events: [CalendarEventItem],
        now: Date,
        limit: Int = defaultEventLimit,
        horizon: TimeInterval = AgendaBuilder.horizon
    ) -> [CalendarEventItem] {
        let horizonEnd = now.addingTimeInterval(horizon)
        let filtered = events.filter { event in
            event.end > now && event.start < horizonEnd
        }
        let sorted = filtered.sorted { lhs, rhs in
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            return lhs.title < rhs.title
        }
        return Array(sorted.prefix(max(0, limit)))
    }

    /// Incomplete reminders that have a due date, including overdue ones, through `horizon`.
    public static func openReminders(
        _ reminders: [ReminderItem],
        now: Date,
        limit: Int = defaultReminderLimit,
        horizon: TimeInterval = AgendaBuilder.horizon
    ) -> [ReminderItem] {
        let horizonEnd = now.addingTimeInterval(horizon)
        let open = reminders.filter { reminder in
            guard !reminder.isCompleted, let due = reminder.dueDate else { return false }
            return due <= horizonEnd
        }
        let sorted = open.sorted { lhs, rhs in
            let left = lhs.dueDate ?? .distantFuture
            let right = rhs.dueDate ?? .distantFuture
            if left != right { return left < right }
            return lhs.title < rhs.title
        }
        return Array(sorted.prefix(max(0, limit)))
    }
}
