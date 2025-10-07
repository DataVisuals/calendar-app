import SwiftUI
import EventKit

struct RemindersSection: View {
    @EnvironmentObject var calendarManager: CalendarManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Reminders")
                    .font(.system(size: 18 * calendarManager.fontSize.scale, weight: .semibold))
                Spacer()
                Text("\(validReminders.count)")
                    .font(.system(size: 15 * calendarManager.fontSize.scale))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Reminders list grouped by list
            if !validReminders.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(groupedReminders.keys.sorted(), id: \.self) { listTitle in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(listTitle)
                                    .font(.system(size: 15 * calendarManager.fontSize.scale, weight: .medium))
                                    .foregroundColor(.secondary)

                                ForEach(groupedReminders[listTitle] ?? [], id: \.calendarItemIdentifier) { reminder in
                                    ReminderRow(reminder: reminder)
                                }
                            }
                        }
                    }
                    .padding()
                }
            } else {
                VStack {
                    Text("No reminders")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
    }

    private var validReminders: [EKReminder] {
        calendarManager.reminders.filter { $0.calendarItemIdentifier != nil && $0.calendar != nil }
    }

    private var groupedReminders: [String: [EKReminder]] {
        Dictionary(grouping: validReminders) { reminder in
            reminder.calendar?.title ?? "No List"
        }
    }
}

struct ReminderRow: View {
    @EnvironmentObject var calendarManager: CalendarManager
    let reminder: EKReminder

    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggleCompletion) {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18 * calendarManager.fontSize.scale))
                    .foregroundColor(reminder.isCompleted ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title ?? "Untitled")
                    .font(.system(size: 15 * calendarManager.fontSize.scale))
                    .strikethrough(reminder.isCompleted)

                if let dueDate = reminder.dueDateComponents?.date {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12 * calendarManager.fontSize.scale))
                        Text(formatDate(dueDate))
                            .font(.system(size: 13 * calendarManager.fontSize.scale))
                    }
                    .foregroundColor(isOverdue(dueDate) ? .red : .secondary)
                }

                if reminder.priority > 0 {
                    HStack(spacing: 4) {
                        ForEach(0..<priorityLevel, id: \.self) { _ in
                            Image(systemName: "exclamationmark")
                                .font(.system(size: 11 * calendarManager.fontSize.scale))
                        }
                    }
                    .foregroundColor(.orange)
                }
            }

            Spacer()
        }
        .padding(hasDate ? 10 : 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
    }

    private var hasDate: Bool {
        reminder.dueDateComponents?.date != nil
    }

    private var priorityLevel: Int {
        // EKReminder priority: 0 = none, 1-4 = high, 5 = medium, 6-9 = low
        if reminder.priority >= 1 && reminder.priority <= 4 {
            return 3
        } else if reminder.priority == 5 {
            return 2
        } else if reminder.priority >= 6 {
            return 1
        }
        return 0
    }

    private func toggleCompletion() {
        reminder.isCompleted.toggle()
        do {
            try calendarManager.eventStore.save(reminder, commit: true)
            calendarManager.loadReminders()
        } catch {
            print("Error toggling reminder: \(error)")
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func isOverdue(_ date: Date) -> Bool {
        date < Date() && !reminder.isCompleted
    }
}
