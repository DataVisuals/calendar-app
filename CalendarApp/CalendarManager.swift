import Foundation
import EventKit
import Combine
import SwiftUI

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
    @AppStorage("fontSize") var fontSize: FontSize = .medium
    @AppStorage("temperatureUnit") var temperatureUnit: TemperatureUnit = .celsius
    @Published var defaultCalendar: EKCalendar?
    @Published var selectedCalendarIDs: Set<String> = []

    let eventStore = EKEventStore()
    private let calendar = Calendar.current
    private let selectedCalendarsKey = "selectedCalendarIDs"

    // Short-lived cache to avoid excessive EventKit queries during rendering
    private var monthEventsCache: [Date: [EKEvent]] = [:]
    private var monthCacheTimestamp: [Date: Date] = [:]
    private let cacheTTL: TimeInterval = 2.0 // 2 seconds

    var hasValidReminders: Bool {
        !reminders.filter { $0.calendarItemIdentifier != nil && $0.calendar != nil }.isEmpty
    }

    init() {
        // @AppStorage automatically handles loading and saving fontSize and temperatureUnit
        print("📱 CalendarManager init - Font size: \(fontSize.rawValue), Temp unit: \(temperatureUnit.rawValue)")

        loadSelectedCalendarIDs()
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

        // Initialize selected calendars if empty (first time)
        if selectedCalendarIDs.isEmpty {
            selectedCalendarIDs = Set(calendars.map { $0.calendarIdentifier })
            saveSelectedCalendarIDs()
            print("✓ Initialized all calendars as selected")
        }

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

    private func loadSelectedCalendarIDs() {
        if let data = UserDefaults.standard.data(forKey: selectedCalendarsKey),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            selectedCalendarIDs = ids
            print("📥 Loaded \(ids.count) selected calendar IDs from UserDefaults")
        }
    }

    func saveSelectedCalendarIDs() {
        if let data = try? JSONEncoder().encode(selectedCalendarIDs) {
            UserDefaults.standard.set(data, forKey: selectedCalendarsKey)
            print("💾 Saved \(selectedCalendarIDs.count) selected calendar IDs to UserDefaults")
        }
    }

    func toggleCalendar(_ calendarID: String) {
        if selectedCalendarIDs.contains(calendarID) {
            selectedCalendarIDs.remove(calendarID)
        } else {
            selectedCalendarIDs.insert(calendarID)
        }
        saveSelectedCalendarIDs()
        clearEventCache()
        loadEvents()
        loadReminders()
    }

    private func clearEventCache() {
        monthEventsCache.removeAll()
        monthCacheTimestamp.removeAll()
    }

    var selectedCalendars: [EKCalendar] {
        calendars.filter { selectedCalendarIDs.contains($0.calendarIdentifier) }
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

        // Filter by selected calendars
        let calendarsToQuery = selectedCalendars.isEmpty ? nil : selectedCalendars
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendarsToQuery)
        events = eventStore.events(matching: predicate)
    }

    func loadReminders() {
        // Filter by selected calendars
        let calendarsForReminders = eventStore.calendars(for: .reminder).filter {
            selectedCalendarIDs.contains($0.calendarIdentifier)
        }
        let calendarsToQuery = calendarsForReminders.isEmpty ? nil : calendarsForReminders

        let predicate = eventStore.predicateForReminders(in: calendarsToQuery)
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

    func createReminder(title: String, dueDate: Date?, notes: String?, priority: Int = 0) throws {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.notes = notes
        reminder.priority = priority

        if let dueDate = dueDate {
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
            reminder.dueDateComponents = components
        }

        // Use default reminder list
        if let defaultList = eventStore.defaultCalendarForNewReminders() {
            reminder.calendar = defaultList
        } else {
            // Get any available reminder list
            let reminderCalendars = eventStore.calendars(for: .reminder)
            guard let firstList = reminderCalendars.first else {
                throw NSError(domain: "CalendarManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No reminder list available"])
            }
            reminder.calendar = firstList
        }

        try eventStore.save(reminder, commit: true)
        loadReminders()
    }

    func updateReminder(withIdentifier identifier: String, title: String, dueDate: Date?, notes: String?, priority: Int) throws {
        // Find the reminder in the event store
        let predicate = eventStore.predicateForReminders(in: nil)
        var foundReminder: EKReminder?

        let semaphore = DispatchSemaphore(value: 0)
        eventStore.fetchReminders(matching: predicate) { reminders in
            foundReminder = reminders?.first(where: { $0.calendarItemIdentifier == identifier })
            semaphore.signal()
        }
        semaphore.wait()

        guard let reminder = foundReminder else {
            throw NSError(domain: "CalendarManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "Reminder not found"])
        }

        // Update properties
        reminder.title = title
        reminder.notes = notes
        reminder.priority = priority

        if let dueDate = dueDate {
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
            reminder.dueDateComponents = components
        } else {
            reminder.dueDateComponents = nil
        }

        try eventStore.save(reminder, commit: true)
        loadReminders()
    }

    func deleteReminder(withIdentifier identifier: String) throws {
        // Find the reminder in the event store
        let predicate = eventStore.predicateForReminders(in: nil)
        var foundReminder: EKReminder?

        let semaphore = DispatchSemaphore(value: 0)
        eventStore.fetchReminders(matching: predicate) { reminders in
            foundReminder = reminders?.first(where: { $0.calendarItemIdentifier == identifier })
            semaphore.signal()
        }
        semaphore.wait()

        guard let reminder = foundReminder else {
            throw NSError(domain: "CalendarManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "Reminder not found"])
        }

        try eventStore.remove(reminder, commit: true)
        loadReminders()
    }

    func events(for date: Date) -> [EKEvent] {
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        // Get the start of the month as cache key
        guard let monthStart = calendar.dateInterval(of: .month, for: date)?.start else {
            return []
        }

        // Check if we have fresh cached events for this month
        let now = Date()
        if let cachedEvents = monthEventsCache[monthStart],
           let timestamp = monthCacheTimestamp[monthStart],
           now.timeIntervalSince(timestamp) < cacheTTL {
            // Use cached events and filter for this day
            return cachedEvents.filter { event in
                guard let eventStart = event.startDate,
                      let eventEnd = event.endDate else { return false }
                return eventStart < endOfDay && eventEnd > startOfDay
            }
        }

        // Cache is stale or missing - query the store for the entire month
        guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            return []
        }

        let calendarsToQuery = selectedCalendars.isEmpty ? nil : selectedCalendars
        let predicate = eventStore.predicateForEvents(withStart: monthStart, end: monthEnd, calendars: calendarsToQuery)
        let monthEvents = eventStore.events(matching: predicate)

        // Cache the results
        monthEventsCache[monthStart] = monthEvents
        monthCacheTimestamp[monthStart] = now

        // Clean up old cache entries (keep only last 3 months)
        let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now
        monthEventsCache = monthEventsCache.filter { $0.key >= threeMonthsAgo }
        monthCacheTimestamp = monthCacheTimestamp.filter { $0.key >= threeMonthsAgo }

        // Filter for this day
        return monthEvents.filter { event in
            guard let eventStart = event.startDate,
                  let eventEnd = event.endDate else { return false }
            return eventStart < endOfDay && eventEnd > startOfDay
        }
    }

    func color(for calendar: EKCalendar?, colorScheme: ColorScheme) -> Color {
        guard let calendar = calendar else {
            // Return gray for detached events without a calendar
            return Color.gray
        }

        let baseColor = Color(cgColor: calendar.cgColor)

        // In light mode, convert to pastel
        if colorScheme == .light {
            return baseColor.pastel()
        } else {
            // In dark mode, use original colors
            return baseColor
        }
    }

    private func invalidateMonthCache() {
        monthEventsCache.removeAll()
        monthCacheTimestamp.removeAll()
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
        invalidateMonthCache()
        loadEvents()
    }

    func findEvent(byProperties properties: EventProperties) -> EKEvent? {
        // First try to find in cached events to get the identifier
        let cachedMatch = events.first { event in
            event.title == properties.title &&
            abs(event.startDate.timeIntervalSince(properties.startDate)) < 2 &&
            abs(event.endDate.timeIntervalSince(properties.endDate)) < 2 &&
            event.calendar?.calendarIdentifier == properties.calendarIdentifier
        }

        // If we found it in cache and it has an identifier, refetch from store
        if let cached = cachedMatch, let identifier = cached.eventIdentifier {
            print("Found event in cache, refetching from store: \(cached.title ?? "Untitled")")
            return eventStore.event(withIdentifier: identifier)
        }

        // If not in cache or no identifier, query the store directly
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

        invalidateMonthCache()

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

        print("Found event by properties: '\(event.title ?? "Untitled")' in calendar '\(event.calendar?.title ?? "unknown")'")
        print("Original calendar: \(event.calendar?.title ?? "unknown"), new calendar: \(calendar?.title ?? "nil")")

        // Update properties
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.notes = notes

        // Update calendar if provided and different
        if let calendar = calendar, let eventCalendar = event.calendar, calendar.calendarIdentifier != eventCalendar.calendarIdentifier {
            print("Changing calendar from '\(eventCalendar.title)' to '\(calendar.title)'")
            event.calendar = calendar
        } else if let calendar = calendar, event.calendar == nil {
            print("Setting calendar to '\(calendar.title)' (was nil)")
            event.calendar = calendar
        }

        do {
            print("Attempting to save event to store")
            try eventStore.save(event, span: .thisEvent, commit: true)
            print("Successfully saved event '\(event.title ?? "Untitled")' to '\(event.calendar?.title ?? "unknown")'")
        } catch {
            print("Failed to save event: \(error)")
            throw error
        }

        invalidateMonthCache()

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

        invalidateMonthCache()

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
            event.calendar?.calendarIdentifier == properties.calendarIdentifier
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

        invalidateMonthCache()

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

        invalidateMonthCache()

        // Reload events to get fresh data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.loadEvents()
        }
    }
}

extension Color {
    init(cgColor: CGColor) {
        if let components = cgColor.components, components.count >= 3 {
            self.init(red: components[0], green: components[1], blue: components[2])
        } else {
            self.init(.sRGB, red: 0.5, green: 0.5, blue: 0.5)
        }
    }

    // Convert to pastel by mixing with white
    func pastel() -> Color {
        #if os(macOS)
        if let nsColor = NSColor(self).usingColorSpace(.deviceRGB) {
            let r = nsColor.redComponent
            let g = nsColor.greenComponent
            let b = nsColor.blueComponent

            // Mix with white (lighten and desaturate)
            let pastelR = r + (1.0 - r) * 0.6
            let pastelG = g + (1.0 - g) * 0.6
            let pastelB = b + (1.0 - b) * 0.6

            return Color(red: pastelR, green: pastelG, blue: pastelB)
        }
        #endif
        return self
    }
}
