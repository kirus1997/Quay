import XCTest
import QuayCore

final class AgendaTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testUpcomingEventsSkipPastAndFarFuture() {
        let current = CalendarEventItem(
            id: "now",
            title: "Standup",
            start: now.addingTimeInterval(-600),
            end: now.addingTimeInterval(600),
            calendarName: "Work",
            isAllDay: false
        )
        let later = CalendarEventItem(
            id: "later",
            title: "Lunch",
            start: now.addingTimeInterval(3_600),
            end: now.addingTimeInterval(5_000),
            calendarName: "Work",
            isAllDay: false
        )
        let past = CalendarEventItem(
            id: "past",
            title: "Yesterday",
            start: now.addingTimeInterval(-10_000),
            end: now.addingTimeInterval(-20),
            calendarName: "Work",
            isAllDay: false
        )
        let distant = CalendarEventItem(
            id: "far",
            title: "Next month",
            start: now.addingTimeInterval(AgendaBuilder.horizon + 60),
            end: now.addingTimeInterval(AgendaBuilder.horizon + 120),
            calendarName: "Work",
            isAllDay: false
        )
        let allDay = CalendarEventItem(
            id: "day",
            title: "Retreat",
            start: now.addingTimeInterval(-3_600),
            end: now.addingTimeInterval(20 * 3_600),
            calendarName: "Home",
            isAllDay: true
        )
        let events = AgendaBuilder.upcomingEvents([later, past, distant, current, allDay], now: now, limit: 10)
        XCTAssertEqual(events.map(\.id), ["day", "now", "later"])
    }

    func testEventLimitAndTitleTieBreak() {
        let first = CalendarEventItem(id: "b", title: "Beta", start: now.addingTimeInterval(100), end: now.addingTimeInterval(200), calendarName: "Home", isAllDay: false)
        let second = CalendarEventItem(id: "a", title: "Alpha", start: now.addingTimeInterval(100), end: now.addingTimeInterval(200), calendarName: "Home", isAllDay: false)
        let third = CalendarEventItem(id: "c", title: "Later", start: now.addingTimeInterval(300), end: now.addingTimeInterval(400), calendarName: "Home", isAllDay: false)
        let events = AgendaBuilder.upcomingEvents([first, third, second], now: now, limit: 2)
        XCTAssertEqual(events.map(\.title), ["Alpha", "Beta"])
        XCTAssertTrue(AgendaBuilder.upcomingEvents([first], now: now, limit: 0).isEmpty)
    }

    func testOpenRemindersSortOverdueThenUndated() {
        let overdue = ReminderItem(id: "1", title: "Milk", dueDate: now.addingTimeInterval(-3_600), isCompleted: false, listName: "Home")
        let soon = ReminderItem(id: "2", title: "Call", dueDate: now.addingTimeInterval(3_600), isCompleted: false, listName: "Home")
        let done = ReminderItem(id: "3", title: "Done", dueDate: now.addingTimeInterval(-10), isCompleted: true, listName: "Home")
        let undated = ReminderItem(id: "4", title: "Someday", dueDate: nil, isCompleted: false, listName: "Home")
        let far = ReminderItem(id: "7", title: "Later", dueDate: now.addingTimeInterval(AgendaBuilder.horizon + 60), isCompleted: false, listName: "Home")
        let sameA = ReminderItem(id: "5", title: "Alpha", dueDate: now.addingTimeInterval(100), isCompleted: false, listName: "Home")
        let sameB = ReminderItem(id: "6", title: "Beta", dueDate: now.addingTimeInterval(100), isCompleted: false, listName: "Home")
        let reminders = AgendaBuilder.openReminders([soon, done, undated, far, sameB, overdue, sameA], now: now, limit: 10)
        XCTAssertEqual(reminders.map(\.title), ["Milk", "Alpha", "Beta", "Call"])
        XCTAssertEqual(AgendaBuilder.openReminders(reminders, now: now, limit: 2).map(\.title), ["Milk", "Alpha"])
    }
}
