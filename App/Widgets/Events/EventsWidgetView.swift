import QuayCore
import SwiftUI

struct EventsWidgetView: View {
    @EnvironmentObject private var model: EventsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            section(
                title: "Events",
                access: model.calendarAccess,
                deniedTitle: "Calendar access is off",
                pane: .calendars
            ) {
                if model.events.isEmpty {
                    quiet("No events soon")
                } else {
                    ForEach(model.events) { event in
                        row(time: eventWhen(event), title: event.title, overdue: false)
                            .help(event.calendarName)
                    }
                }
            }

            section(
                title: "Reminders",
                access: model.reminderAccess,
                deniedTitle: "Reminders access is off",
                pane: .reminders
            ) {
                if model.reminders.isEmpty {
                    quiet("Nothing due")
                } else {
                    ForEach(model.reminders) { reminder in
                        row(time: reminderWhen(reminder), title: reminder.title, overdue: isOverdue(reminder))
                            .help(reminder.listName)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: 248, alignment: .leading)
        .background(WidgetPlate())
    }

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        access: AgendaAccess,
        deniedTitle: String,
        pane: SystemSettingsLink.Pane,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            switch access {
            case .unknown:
                quiet("Checking…")
            case .denied:
                Text(deniedTitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Button("System Settings") {
                    SystemSettingsLink.open(pane)
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            case .granted:
                content()
            }
        }
    }

    private func row(time: String, title: String, overdue: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(time)
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(overdue ? Color.orange : Color.secondary)
                .frame(minWidth: 58, alignment: .leading)
            Text(title)
                .font(.system(size: 12))
                .lineLimit(1)
        }
    }

    private func quiet(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
    }

    private func eventWhen(_ event: CalendarEventItem) -> String {
        let calendar = Calendar.current
        if event.isAllDay {
            if calendar.isDate(event.start, inSameDayAs: Date()) { return "All day" }
            return event.start.formatted(.dateTime.weekday(.abbreviated))
        }
        if calendar.isDate(event.start, inSameDayAs: Date()) {
            return event.start.formatted(.dateTime.hour().minute())
        }
        return event.start.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }

    private func reminderWhen(_ reminder: ReminderItem) -> String {
        guard let due = reminder.dueDate else { return "Due" }
        if due < Date() { return "Overdue" }
        if Calendar.current.isDate(due, inSameDayAs: Date()) {
            return due.formatted(.dateTime.hour().minute())
        }
        return due.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }

    private func isOverdue(_ reminder: ReminderItem) -> Bool {
        guard let due = reminder.dueDate else { return false }
        return due < Date()
    }
}
