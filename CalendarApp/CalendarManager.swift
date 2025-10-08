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
            .dropFirst() // Skip initial nil value
            .sink { calendar in
                if let calendar = calendar {
                    UserDefaults.standard.set(calendar.calendarIdentifier, forKey: "defaultCalendarIdentifier")
                    UserDefaults.standard.synchronize()
                    print("✓ Saved default calendar: \(calendar.title) (ID: \(calendar.calendarIdentifier))")

                    // Verify it was saved
                    if let saved = UserDefaults.standard.string(forKey: "defaultCalendarIdentifier") {
                        print("✓ Verified saved in UserDefaults: \(saved)")
                    }
                } else {
                    UserDefaults.standard.removeObject(forKey: "defaultCalendarIdentifier")
                    UserDefaults.standard.synchronize()
                    print("✓ Cleared default calendar")
                }
            }
            .store(in: &cancellables)

        print("CalendarManager initialized")
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
        print("Loaded \(calendars.count) calendars")

        // Restore default calendar from UserDefaults
        if let savedIdentifier = UserDefaults.standard.string(forKey: "defaultCalendarIdentifier") {
            print("📥 Found saved default calendar ID: \(savedIdentifier)")
            if let savedCalendar = calendars.first(where: { $0.calendarIdentifier == savedIdentifier }) {
                // Use DispatchQueue to avoid triggering the publisher during initialization
                DispatchQueue.main.async { [weak self] in
                    self?.defaultCalendar = savedCalendar
                    print("✓ Restored default calendar: \(savedCalendar.title)")
                }
            } else {
                print("⚠️ Could not find calendar with saved ID among \(calendars.count) calendars")
                // List available calendar IDs for debugging
                print("Available calendars:")
                for cal in calendars {
                    print("  - \(cal.title): \(cal.calendarIdentifier)")
                }
            }
        } else {
            print("ℹ️ No saved default calendar found in UserDefaults")
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

        print("Deleting event: '\(storeEvent.title ?? "Untitled")' from calendar '\(storeEvent.calendar.title)'")
        print("Event details - Start: \(String(describing: storeEvent.startDate)), End: \(String(describing: storeEvent.endDate))")

        // Check if the calendar allows modifications
        if !storeEvent.calendar.allowsContentModifications {
            throw NSError(domain: "CalendarManager", code: -5, userInfo: [NSLocalizedDescriptionKey: "This calendar does not allow modifications. The event cannot be deleted."])
        }

        do {
            try eventStore.remove(storeEvent, span: .thisEvent, commit: true)
            print("Successfully deleted event")
        } catch let error as NSError {
            print("Delete failed with error: \(error)")
            print("Error domain: \(error.domain), code: \(error.code)")
            throw error
        }

        // Reload events
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.loadEvents()
        }
    }

    func deleteEvent(byProperties properties: EventProperties) throws {
        // First, check if the event has an identifier by searching
        if let cachedEvent = events.first(where: { event in
            event.title == properties.title &&
            abs(event.startDate.timeIntervalSince(properties.startDate)) < 2 &&
            abs(event.endDate.timeIntervalSince(properties.endDate)) < 2 &&
            event.calendar.calendarIdentifier == properties.calendarIdentifier
        }), let identifier = cachedEvent.eventIdentifier {
            // If it has an identifier, use the identifier-based deletion
            print("Event has identifier, using deleteEvent(withIdentifier:)")
            try deleteEvent(withIdentifier: identifier)
            return
        }

        // For events without identifiers, we need to search and delete in one operation
        print("Searching for event without identifier to delete")
        let startOfDay = calendar.startOfDay(for: properties.startDate)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            throw NSError(domain: "CalendarManager", code: -6, userInfo: [NSLocalizedDescriptionKey: "Invalid date"])
        }

        // Get fresh events from store
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let matchingEvents = eventStore.events(matching: predicate)

        guard let eventToDelete = matchingEvents.first(where: { event in
            event.title == properties.title &&
            abs(event.startDate.timeIntervalSince(properties.startDate)) < 2 &&
            abs(event.endDate.timeIntervalSince(properties.endDate)) < 2 &&
            event.calendar.calendarIdentifier == properties.calendarIdentifier
        }) else {
            throw NSError(domain: "CalendarManager", code: -4, userInfo: [NSLocalizedDescriptionKey: "Event not found"])
        }

        print("Deleting event by properties: '\(eventToDelete.title ?? "Untitled")' from calendar '\(eventToDelete.calendar.title)'")
        print("Event details - Start: \(String(describing: eventToDelete.startDate)), End: \(String(describing: eventToDelete.endDate))")

        // Check if the calendar allows modifications
        if !eventToDelete.calendar.allowsContentModifications {
            throw NSError(domain: "CalendarManager", code: -5, userInfo: [NSLocalizedDescriptionKey: "This calendar does not allow modifications. The event cannot be deleted."])
        }

        do {
            // Try to remove the event immediately after fetching
            try eventStore.remove(eventToDelete, span: .thisEvent, commit: true)
            print("Successfully deleted event")
        } catch let error as NSError {
            print("Delete failed with error: \(error)")
            print("Error domain: \(error.domain), code: \(error.code)")
            print("Error userInfo: \(error.userInfo)")
            throw error
        }

        // Reload events
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.loadEvents()
        }
    }

    func moveEvent(_ event: EKEvent, to newDate: Date) throws {
        // Try to get event from store by identifier first
        let storeEvent: EKEvent?

        if let eventIdentifier = event.eventIdentifier {
            storeEvent = eventStore.event(withIdentifier: eventIdentifier)
        } else {
            // If no identifier, try to find by properties
            print("Event has no identifier, searching by properties")
            let properties = EventProperties(
                title: event.title ?? "",
                startDate: event.startDate,
                endDate: event.endDate,
                calendarIdentifier: event.calendar.calendarIdentifier
            )
            storeEvent = findEvent(byProperties: properties)
        }

        guard let foundEvent = storeEvent else {
            throw NSError(domain: "CalendarManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "Event not found in store"])
        }

        let duration = foundEvent.endDate.timeIntervalSince(foundEvent.startDate)
        foundEvent.startDate = newDate
        foundEvent.endDate = newDate.addingTimeInterval(duration)

        try eventStore.save(foundEvent, span: .thisEvent, commit: true)

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
