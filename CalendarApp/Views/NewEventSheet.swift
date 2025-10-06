import SwiftUI
import EventKit

struct NewEventSheet: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @Environment(\.dismiss) var dismiss

    @State private var quickInput = ""
    @State private var title = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600)
    @State private var selectedCalendar: EKCalendar?
    @State private var notes = ""
    @State private var isAllDay = false
    @State private var showError = false
    @State private var errorMessage = ""

    private let parser = NaturalLanguageParser()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Event")
                    .font(.system(size: 22, weight: .semibold))

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .font(.system(size: 15))
                .keyboardShortcut(.escape, modifiers: [])

                Button("Save") {
                    saveEvent()
                }
                .font(.system(size: 15))
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(title.isEmpty)
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Quick input with natural language parsing
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick Add")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)

                        TextField("e.g., 'Dentist appointment next saturday at 3pm for 2 hours'", text: $quickInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 15))
                            .onSubmit {
                                parseQuickInput()
                            }

                        Button("Parse") {
                            parseQuickInput()
                        }
                        .font(.system(size: 14))
                        .buttonStyle(.bordered)
                        .disabled(quickInput.isEmpty)

                        Text("Try: 'tomorrow at 2pm', 'next friday at 10am for 1 hour'")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // Manual input fields
                    VStack(alignment: .leading, spacing: 18) {
                        // Title
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Title")
                                .font(.system(size: 15, weight: .medium))
                            TextField("Event title", text: $title)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 15))
                        }

                        // Calendar selection
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Calendar")
                                .font(.system(size: 15, weight: .medium))
                            Picker("", selection: $selectedCalendar) {
                                ForEach(calendarManager.calendars, id: \.calendarIdentifier) { calendar in
                                    HStack {
                                        Circle()
                                            .fill(calendarManager.color(for: calendar))
                                            .frame(width: 12, height: 12)
                                        Text(calendar.title)
                                            .font(.system(size: 14))
                                    }
                                    .tag(calendar as EKCalendar?)
                                }
                            }
                            .labelsHidden()
                        }

                        // All-day toggle
                        Toggle("All-day event", isOn: $isAllDay)
                            .font(.system(size: 15))

                        // Start date
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Starts")
                                .font(.system(size: 15, weight: .medium))
                            DatePicker("", selection: $startDate, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                                .datePickerStyle(.field)
                                .font(.system(size: 14))
                                .labelsHidden()
                        }

                        // End date
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Ends")
                                .font(.system(size: 15, weight: .medium))
                            DatePicker("", selection: $endDate, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                                .datePickerStyle(.field)
                                .font(.system(size: 14))
                                .labelsHidden()
                        }

                        // Notes
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notes")
                                .font(.system(size: 15, weight: .medium))
                            TextEditor(text: $notes)
                                .frame(height: 100)
                                .font(.system(size: 14))
                                .border(Color(NSColor.separatorColor), width: 1)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            if selectedCalendar == nil {
                selectedCalendar = calendarManager.calendars.first
            }
        }
    }

    private func parseQuickInput() {
        guard !quickInput.isEmpty else { return }

        if let parsed = parser.parseEventInput(quickInput) {
            title = parsed.title
            startDate = parsed.startDate
            endDate = parsed.endDate
            if let parsedNotes = parsed.notes {
                notes = parsedNotes
            }
            quickInput = ""
        }
    }

    private func saveEvent() {
        guard !title.isEmpty else { return }

        do {
            try calendarManager.createEvent(
                title: title,
                startDate: startDate,
                endDate: endDate,
                calendar: selectedCalendar,
                notes: notes.isEmpty ? nil : notes
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
