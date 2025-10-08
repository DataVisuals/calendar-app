import SwiftUI
import EventKit

struct NewReminderSheet: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @Environment(\.dismiss) var dismiss

    let reminderIdToEdit: String?

    @State private var title = ""
    @State private var notes = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var priority = 0
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showDeleteConfirmation = false

    init(reminderIdToEdit: String? = nil) {
        self.reminderIdToEdit = reminderIdToEdit
    }

    private var isEditMode: Bool {
        reminderIdToEdit != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEditMode ? "Edit Reminder" : "New Reminder")
                    .font(.system(size: 22 * calendarManager.fontSize.scale, weight: .semibold))

                Spacer()

                if isEditMode {
                    Button("Delete") {
                        showDeleteConfirmation = true
                    }
                    .font(.system(size: 15 * calendarManager.fontSize.scale))
                    .foregroundColor(.red)
                    .buttonStyle(.bordered)
                }

                Button("Cancel") {
                    dismiss()
                }
                .font(.system(size: 15 * calendarManager.fontSize.scale))
                .keyboardShortcut(.escape, modifiers: [])

                Button("Save") {
                    saveReminder()
                }
                .font(.system(size: 15 * calendarManager.fontSize.scale))
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(title.isEmpty)
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Title")
                            .font(.system(size: 15 * calendarManager.fontSize.scale, weight: .medium))
                        TextField("Reminder title", text: $title)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 15 * calendarManager.fontSize.scale))
                    }

                    // Due date toggle
                    Toggle("Due date", isOn: $hasDueDate)
                        .font(.system(size: 15 * calendarManager.fontSize.scale))

                    // Due date picker
                    if hasDueDate {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Date & Time")
                                .font(.system(size: 15 * calendarManager.fontSize.scale, weight: .medium))
                            DatePicker("", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.field)
                                .font(.system(size: 14 * calendarManager.fontSize.scale))
                                .labelsHidden()
                        }
                    }

                    // Priority
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Priority")
                            .font(.system(size: 15 * calendarManager.fontSize.scale, weight: .medium))
                        Picker("", selection: $priority) {
                            Text("None").tag(0)
                            Text("Low").tag(9)
                            Text("Medium").tag(5)
                            Text("High").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes")
                            .font(.system(size: 15 * calendarManager.fontSize.scale, weight: .medium))
                        TextEditor(text: $notes)
                            .frame(height: 100)
                            .font(.system(size: 14 * calendarManager.fontSize.scale))
                            .border(Color(NSColor.separatorColor), width: 1)
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 500)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Delete Reminder", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                performDelete()
            }
        } message: {
            Text("Are you sure you want to delete this reminder? This action cannot be undone.")
        }
        .onAppear {
            if let reminderId = reminderIdToEdit,
               let reminder = calendarManager.reminders.first(where: { $0.calendarItemIdentifier == reminderId }) {
                // Populate fields with existing reminder data
                title = reminder.title ?? ""
                notes = reminder.notes ?? ""
                hasDueDate = reminder.dueDateComponents?.date != nil
                if let dueDate = reminder.dueDateComponents?.date {
                    self.dueDate = dueDate
                }
                priority = reminder.priority
            }
        }
    }

    private func saveReminder() {
        guard !title.isEmpty else { return }

        do {
            if let reminderId = reminderIdToEdit {
                try calendarManager.updateReminder(
                    withIdentifier: reminderId,
                    title: title,
                    dueDate: hasDueDate ? dueDate : nil,
                    notes: notes.isEmpty ? nil : notes,
                    priority: priority
                )
            } else {
                try calendarManager.createReminder(
                    title: title,
                    dueDate: hasDueDate ? dueDate : nil,
                    notes: notes.isEmpty ? nil : notes,
                    priority: priority
                )
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func performDelete() {
        guard let reminderId = reminderIdToEdit else { return }

        do {
            try calendarManager.deleteReminder(withIdentifier: reminderId)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
