import Foundation
import EventKit
import Combine

struct EventProperties {
    let title: String
    let startDate: Date
    let endDate: Date
    let calendarIdentifier: String
}

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
    @Published var defaultCalendar: EKCalendar?

    let eventStore = EKEventStore()
    private let calendar = Calendar.current

    var hasValidReminders: Bool {
        !reminders.filter { $0.calendarItemIdentifier != nil && $0.calendar != nil }.isEmpty
    }

    init() {
        checkAccess()

        // Observe defaultCalendar changes and persist
        $defaultCalendar
            .sink { calendar in
                if let calendar = calendar {
                    UserDefaults.standard.set(calendar.calendarIdentifier, forKey: "defaultCalendarIdentifier")
                    print("Saved default calendar: \(calendar.title)")
                } else {
                    UserDefaults.standard.removeObject(forKey: "defaultCalendarIdentifier")
                    print("Cleared default calendar")
                }
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

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

        // Restore default calendar from UserDefaults
        if let savedIdentifier = UserDefaults.standard.string(forKey: "defaultCalendarIdentifier") {
            print("Restoring default calendar with ID: \(savedIdentifier)")
            if let savedCalendar = calendars.first(where: { $0.calendarIdentifier == savedIdentifier }) {
                defaultCalendar = savedCalendar
                print("Restored default calendar: \(savedCalendar.title)")
            } else {
                print("Could not find calendar with saved ID")
            }
        } else {
            print("No saved default calendar")
        }
    }

    private var lastLoadTime: Date?
    private let minimumLoadInterval: TimeInterval = 0.5 // Minimum 0.5 seconds between loads

    func loadEvents() {
        // Throttle loads to prevent excessive queries
        if let lastLoad = lastLoadTime,
           Date().timeIntervalSince(lastLoad) < minimumLoadInterval {
            print("Skipping loadEvents - too soon since last load")
            return
        }

        lastLoadTime = Date()

        let startDate = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let endDate = calendar.date(byAdding: .month, value: 2, to: Date()) ?? Date()

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        events = eventStore.events(matching: predicate)
    }

    func loadReminders() {
        let predicate = eventStore.predicateForReminders(in: nil)
        eventStore.fetchReminders(matching: predicate) { [weak self] reminders in
            DispatchQueue.main.async {
                self?.reminders = reminders?.filter {
                    !$0.isCompleted &&
                    $0.calendar != nil &&
                    $0.calendarItemIdentifier != nil
                } ?? []
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
        guard let targetCalendar = calendar ?? defaultCalendar ?? eventStore.defaultCalendarForNewEvents else {
            throw NSError(domain: "CalendarManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No calendar available for new events"])
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = targetCalendar
        event.notes = notes

        try eventStore.save(event, span: .thisEvent)
        loadEvents()
    }

    func findEvent(byProperties properties: EventProperties) -> EKEvent? {
        // First try to find in cached events (much faster)
        let cachedMatch = events.first { event in
            event.title == properties.title &&
            abs(event.startDate.timeIntervalSince(properties.startDate)) < 2 &&
            abs(event.endDate.timeIntervalSince(properties.endDate)) < 2 &&
            event.calendar.calendarIdentifier == properties.calendarIdentifier
        }

        if let cached = cachedMatch {
            print("Found event in cache: \(cached.title ?? "Untitled")")
            return cached
        }

        // If not in cache, query the store (more expensive)
        print("Event not in cache, querying store...")
        let startOfDay = calendar.startOfDay(for: properties.startDate)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let matchingEvents = eventStore.events(matching: predicate)

        return matchingEvents.first { event in
            event.title == properties.title &&
            abs(event.startDate.timeIntervalSince(properties.startDate)) < 2 &&
            abs(event.endDate.timeIntervalSince(properties.endDate)) < 2 &&
            event.calendar.calendarIdentifier == properties.calendarIdentifier
        }
    }

    func updateEvent(withIdentifier identifier: String, title: String, startDate: Date, endDate: Date, calendar: EKCalendar?, notes: String?) throws {
        // Always fetch fresh from store
        guard let storeEvent = eventStore.event(withIdentifier: identifier) else {
            throw NSError(domain: "CalendarManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "Event not found in store"])
        }

        print("Found event by ID: '\(storeEvent.title ?? "Untitled")' in calendar '\(storeEvent.calendar.title)'")
        print("Original calendar: \(storeEvent.calendar.title), new calendar: \(calendar?.title ?? "nil")")

        // Update properties
        storeEvent.title = title
        storeEvent.startDate = startDate
        storeEvent.endDate = endDate
        storeEvent.notes = notes

        // Update calendar if provided and different
        if let calendar = calendar, calendar.calendarIdentifier != storeEvent.calendar.calendarIdentifier {
            print("Changing calendar from '\(storeEvent.calendar.title)' to '\(calendar.title)'")
            storeEvent.calendar = calendar
        }

        do {
            print("Attempting to save event to store")
            try eventStore.save(storeEvent, span: .thisEvent, commit: true)
            print("Successfully saved event '\(storeEvent.title ?? "Untitled")' to '\(storeEvent.calendar.title)'")
        } catch {
            print("Failed to save event: \(error)")
            throw error
        }

        // Reload events to get fresh data (with throttling)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.loadEvents()
        }
    }

    func updateEvent(byProperties properties: EventProperties, title: String, startDate: Date, endDate: Date, calendar: EKCalendar?, notes: String?) throws {
        // Always find fresh from the store right before saving
        guard let event = findEvent(byProperties: properties) else {
            throw NSError(domain: "CalendarManager", code: -4, userInfo: [NSLocalizedDescriptionKey: "Event not found"])
        }

        print("Found event by properties: '\(event.title ?? "Untitled")' in calendar '\(event.calendar.title)'")
        print("Original calendar: \(event.calendar.title), new calendar: \(calendar?.title ?? "nil")")

        // Update properties
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.notes = notes

        // Update calendar if provided and different
        if let calendar = calendar, calendar.calendarIdentifier != event.calendar.calendarIdentifier {
            print("Changing calendar from '\(event.calendar.title)' to '\(calendar.title)'")
            event.calendar = calendar
        }

        do {
            print("Attempting to save event to store")
            try eventStore.save(event, span: .thisEvent, commit: true)
            print("Successfully saved event '\(event.title ?? "Untitled")' to '\(event.calendar.title)'")
        } catch {
            print("Failed to save event: \(error)")
            throw error
        }

        // Reload events to get fresh data (with throttling)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.loadEvents()
        }
    }

    func deleteEvent(withIdentifier identifier: String) throws {
        guard let storeEvent = eventStore.event(withIdentifier: identifier) else {
            throw NSError(domain: "CalendarManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "Event not found in store"])
        }

        print("Deleting event: '\(storeEvent.title ?? "Untitled")'")
        try eventStore.remove(storeEvent, span: .thisEvent, commit: true)
        print("Successfully deleted event")

        // Reload events
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.loadEvents()
        }
    }

    func deleteEvent(byProperties properties: EventProperties) throws {
        guard let event = findEvent(byProperties: properties) else {
            throw NSError(domain: "CalendarManager", code: -4, userInfo: [NSLocalizedDescriptionKey: "Event not found"])
        }

        print("Deleting event by properties: '\(event.title ?? "Untitled")'")
        try eventStore.remove(event, span: .thisEvent, commit: true)
        print("Successfully deleted event")

        // Reload events
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.loadEvents()
        }
    }

    func moveEvent(_ event: EKEvent, to newDate: Date) throws {
        // Always fetch fresh from the store to avoid "does not belong to store" error
        guard let eventIdentifier = event.eventIdentifier else {
            throw NSError(domain: "CalendarManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Event has no identifier"])
        }

        guard let storeEvent = eventStore.event(withIdentifier: eventIdentifier) else {
            throw NSError(domain: "CalendarManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "Event not found in store"])
        }

        let duration = storeEvent.endDate.timeIntervalSince(storeEvent.startDate)
        storeEvent.startDate = newDate
        storeEvent.endDate = newDate.addingTimeInterval(duration)

        try eventStore.save(storeEvent, span: .thisEvent, commit: true)

        // Reload events to get fresh data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.loadEvents()
        }
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
