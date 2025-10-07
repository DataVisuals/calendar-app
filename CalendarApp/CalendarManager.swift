import Foundation
import EventKit

enum FontSize: String, CaseIterable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    case extraLarge = "Extra Large"

    var scale: CGFloat {
        switch self {
        case .small: return 0.85
        case .medium: return 1.0
        case .large: return 1.15
        case .extraLarge: return 1.3
        }
    }
}

enum TemperatureUnit: String, CaseIterable {
    case celsius = "Celsius"
    case fahrenheit = "Fahrenheit"

    func convert(_ fahrenheit: Double) -> Double {
        switch self {
        case .celsius:
            return (fahrenheit - 32) * 5 / 9
        case .fahrenheit:
            return fahrenheit
        }
    }

    var symbol: String {
        switch self {
        case .celsius: return "°C"
        case .fahrenheit: return "°F"
        }
    }
}

class CalendarManager: ObservableObject {
    @Published var events: [EKEvent] = []
    @Published var calendars: [EKCalendar] = []
    @Published var reminders: [EKReminder] = []
    @Published var hasAccess = false
    @Published var fontSize: FontSize = .medium
    @Published var temperatureUnit: TemperatureUnit = .celsius

    let eventStore = EKEventStore()
    private let calendar = Calendar.current

    init() {
        checkAccess()
    }

    private func checkAccess() {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) {
            hasAccess = (status == .authorized || status == .fullAccess)
        } else {
            hasAccess = (status == .authorized)
        }
        if hasAccess {
            loadCalendars()

            // Check reminders access
            let reminderStatus = EKEventStore.authorizationStatus(for: .reminder)
            let hasReminderAccess: Bool
            if #available(macOS 14.0, *) {
                hasReminderAccess = (reminderStatus == .authorized || reminderStatus == .fullAccess)
            } else {
                hasReminderAccess = (reminderStatus == .authorized)
            }
            if hasReminderAccess {
                loadReminders()
            }
        }
    }

    func requestAccess() {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.hasAccess = granted
                    if granted {
                        self?.loadCalendars()
                        self?.loadEvents()
                        // Request reminders access separately
                        self?.eventStore.requestFullAccessToReminders { remindersGranted, _ in
                            DispatchQueue.main.async {
                                if remindersGranted {
                                    self?.loadReminders()
                                }
                            }
                        }
                    }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.hasAccess = granted
                    if granted {
                        self?.loadCalendars()
                        self?.loadEvents()
                        // Request reminders access separately
                        self?.eventStore.requestAccess(to: .reminder) { remindersGranted, _ in
                            DispatchQueue.main.async {
                                if remindersGranted {
                                    self?.loadReminders()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    func loadCalendars() {
        calendars = eventStore.calendars(for: .event)
    }

    func loadEvents() {
        let startDate = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let endDate = calendar.date(byAdding: .month, value: 2, to: Date()) ?? Date()

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        events = eventStore.events(matching: predicate)
    }

    func loadReminders() {
        let predicate = eventStore.predicateForReminders(in: nil)
        eventStore.fetchReminders(matching: predicate) { [weak self] reminders in
            DispatchQueue.main.async {
                self?.reminders = reminders?.filter { !$0.isCompleted } ?? []
            }
        }
    }

    func events(for date: Date) -> [EKEvent] {
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        return events.filter { event in
            guard let eventStart = event.startDate,
                  let eventEnd = event.endDate else { return false }
            return eventStart < endOfDay && eventEnd > startOfDay
        }
    }

    func color(for calendar: EKCalendar) -> Color {
        Color(cgColor: calendar.cgColor)
    }

    func createEvent(title: String, startDate: Date, endDate: Date, calendar: EKCalendar?, notes: String?) throws {
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = calendar ?? eventStore.defaultCalendarForNewEvents
        event.notes = notes

        try eventStore.save(event, span: .thisEvent)
        loadEvents()
    }
}

import SwiftUI

extension Color {
    init(cgColor: CGColor) {
        if let components = cgColor.components, components.count >= 3 {
            self.init(red: components[0], green: components[1], blue: components[2])
        } else {
            self.init(.sRGB, red: 0.5, green: 0.5, blue: 0.5)
        }
    }
}
