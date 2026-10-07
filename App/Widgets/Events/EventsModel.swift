import Combine
import EventKit
import Foundation
import QuayCore

enum AgendaAccess: Equatable {
    case unknown
    case granted
    case denied
}

@MainActor
final class EventsModel: ObservableObject {
    @Published private(set) var events: [CalendarEventItem] = []
    @Published private(set) var reminders: [ReminderItem] = []
    @Published private(set) var calendarAccess: AgendaAccess = .unknown
    @Published private(set) var reminderAccess: AgendaAccess = .unknown

    private let store = EKEventStore()
    private var changeObserver: NSObjectProtocol?
    private var isEnabled = false

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        if enabled {
            changeObserver = NotificationCenter.default.addObserver(
                forName: .EKEventStoreChanged,
                object: store,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.reload()
                }
            }
            Task { await prepare() }
        } else {
            if let changeObserver {
                NotificationCenter.default.removeObserver(changeObserver)
                self.changeObserver = nil
            }
            events = []
            reminders = []
        }
    }

    private func prepare() async {
        calendarAccess = await resolve(.event) {
            try await self.store.requestFullAccessToEvents()
        }
        reminderAccess = await resolve(.reminder) {
            try await self.store.requestFullAccessToReminders()
        }
        reload()
    }

    private func resolve(_ type: EKEntityType, request: @MainActor () async throws -> Bool) async -> AgendaAccess {
        switch EKEventStore.authorizationStatus(for: type) {
        case .fullAccess, .authorized:
            return .granted
        case .denied, .restricted, .writeOnly:
            return .denied
        case .notDetermined:
            let granted = (try? await request()) ?? false
            return granted ? .granted : .denied
        @unknown default:
            return .denied
        }
    }

    private func reload() {
        guard isEnabled else { return }
        let now = Date()
        if calendarAccess == .granted {
            events = AgendaBuilder.upcomingEvents(fetchEvents(now: now), now: now)
        } else {
            events = []
        }
        guard reminderAccess == .granted else {
            reminders = []
            return
        }
        let end = now.addingTimeInterval(AgendaBuilder.horizon)
        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: Date(timeIntervalSince1970: 0),
            ending: end,
            calendars: nil
        )
        store.fetchReminders(matching: predicate) { [weak self] fetched in
            let items = (fetched ?? []).map { reminder in
                ReminderItem(
                    id: reminder.calendarItemIdentifier,
                    title: Self.displayTitle(reminder.title),
                    dueDate: reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) },
                    isCompleted: reminder.isCompleted,
                    listName: Self.calendarTitle(reminder.calendar)
                )
            }
            Task { @MainActor in
                guard let self, self.isEnabled, self.reminderAccess == .granted else { return }
                self.reminders = AgendaBuilder.openReminders(items, now: Date())
            }
        }
    }

    private func fetchEvents(now: Date) -> [CalendarEventItem] {
        let start = now.addingTimeInterval(-24 * 60 * 60)
        let end = now.addingTimeInterval(AgendaBuilder.horizon)
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).compactMap { event in
            guard let id = event.eventIdentifier, let start = event.startDate, let end = event.endDate else {
                return nil
            }
            return CalendarEventItem(
                id: id,
                title: Self.displayTitle(event.title),
                start: start,
                end: end,
                calendarName: Self.calendarTitle(event.calendar),
                isAllDay: event.isAllDay
            )
        }
    }

    private static func calendarTitle(_ calendar: EKCalendar?) -> String {
        (calendar?.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func displayTitle(_ title: String?) -> String {
        let trimmed = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }
}
