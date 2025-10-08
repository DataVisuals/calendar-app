import SwiftUI
import EventKit

struct RemindersSection: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @Binding var showingNewReminder: Bool
    let onReminderDoubleClick: (EKReminder) -> Void

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
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ForEach(validReminders, id: \.calendarItemIdentifier) { reminder in
                            ReminderRow(reminder: reminder, onDoubleClick: {
                                onReminderDoubleClick(reminder)
                            })
                        }
                    }
                    .padding(16)
                }
            } else {
                VStack {
                    Text("No reminders")
                        .foregroundColor(.secondary)
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    showingNewReminder = true
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            showingNewReminder = true
        }
    }

    private var validReminders: [EKReminder] {
        calendarManager.reminders.filter { $0.calendarItemIdentifier != nil && $0.calendar != nil }
    }
}

struct ReminderRow: View {
    @EnvironmentObject var calendarManager: CalendarManager
    let reminder: EKReminder
    let onDoubleClick: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: toggleCompletion) {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16 * calendarManager.fontSize.scale))
                    .foregroundColor(reminder.isCompleted ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title ?? "Untitled")
                    .font(.system(size: 13 * calendarManager.fontSize.scale))
                    .strikethrough(reminder.isCompleted)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let dueDate = reminder.dueDateComponents?.date {
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 10 * calendarManager.fontSize.scale))
                            Text(formatDate(dueDate))
                                .font(.system(size: 11 * calendarManager.fontSize.scale))
                        }
                        .foregroundColor(isOverdue(dueDate) ? .red : .secondary)
                    }

                    if reminder.priority > 0 {
                        HStack(spacing: 2) {
                            ForEach(0..<priorityLevel, id: \.self) { _ in
                                Image(systemName: "exclamationmark")
                                    .font(.system(size: 9 * calendarManager.fontSize.scale))
                            }
                        }
                        .foregroundColor(.orange)
                    }

                    if let listTitle = reminder.calendar?.title {
                        Text(listTitle)
                            .font(.system(size: 10 * calendarManager.fontSize.scale))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onDoubleClick()
        }
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
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInTomorrow(date) {
            formatter.timeStyle = .short
            return "Tomorrow " + formatter.string(from: date)
        } else {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }

    private func isOverdue(_ date: Date) -> Bool {
        date < Date() && !reminder.isCompleted
    }
}
