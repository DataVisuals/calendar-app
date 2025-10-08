import SwiftUI
import EventKit

enum CalendarViewType: String, CaseIterable {
    case month = "Month"
    case week = "Week"
    case workweek = "5-Day"
    case threeDay = "3-Day"
    case today = "Today"
    case agenda = "Agenda"

    var shortcut: KeyEquivalent {
        switch self {
        case .month: return "1"
        case .week: return "2"
        case .workweek: return "3"
        case .threeDay: return "4"
        case .today: return "6"
        case .agenda: return "5"
        }
    }

    var tooltip: String {
        switch self {
        case .month: return "Month (⌘1)"
        case .week: return "Week (⌘2)"
        case .workweek: return "5-Day (⌘3)"
        case .threeDay: return "3-Day (⌘4)"
        case .today: return "Today (⌘6)"
        case .agenda: return "Agenda (⌘5)"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @StateObject private var weatherManager = WeatherManager()
    @State private var selectedView: CalendarViewType = .month
    @State private var currentDate = Date()
    @State private var showingNewEvent = false
    @State private var newEventDate: Date?
    @State private var eventIdToEdit: String?
    @State private var eventPropertiesToEdit: EventProperties?
    @State private var showingNewReminder = false
    @State private var reminderIdToEdit: String?
    @State private var showingSearch = false
    @State private var searchText = ""
    @State private var searchForward = true // true = forward (/), false = backward (\)
    @State private var highlightedEventIDs: Set<String> = []
    @FocusState private var searchFocused: Bool
    @State private var quickAddText = ""
    @FocusState private var quickAddFocused: Bool

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday = 2 (Sunday = 1)
        return cal
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if !calendarManager.hasAccess {
                    CalendarAccessView()
                } else {
                    mainContent
                }
            }

            if showingSearch {
                searchOverlay
            }
        }
        .sheet(isPresented: $showingNewEvent) {
            NewEventSheet(initialDate: newEventDate, eventIdToEdit: eventIdToEdit, eventPropertiesToEdit: eventPropertiesToEdit)
        }
        .sheet(isPresented: $showingNewReminder) {
            NewReminderSheet(reminderIdToEdit: reminderIdToEdit)
        }
        .onChange(of: showingNewEvent) { showing in
            if !showing {
                newEventDate = nil
                eventIdToEdit = nil
                eventPropertiesToEdit = nil
            }
        }
        .onChange(of: showingNewReminder) { showing in
            if !showing {
                reminderIdToEdit = nil
            }
        }
        .onChange(of: currentDate) { _ in
            calendarManager.loadEvents()
        }
        .onChange(of: searchText) { newValue in
            if !newValue.isEmpty {
                searchForEvent(newValue)
            }
        }
        .onAppear {
            if calendarManager.hasAccess {
                calendarManager.loadEvents()
                calendarManager.loadReminders()
            }
        }
        .applyViewShortcuts(selectedView: $selectedView)
        .applySearchShortcut(showingSearch: $showingSearch, searchForward: $searchForward, searchFocused: $searchFocused, quickAddFocused: $quickAddFocused)
        .applyEventReminderShortcuts(showingNewEvent: $showingNewEvent, showingNewReminder: $showingNewReminder)
    }

    private var searchOverlay: some View {
        VStack {
            Spacer()

            VStack(spacing: 8) {
                // Direction indicator
                HStack {
                    Image(systemName: searchForward ? "arrow.forward.circle" : "arrow.backward.circle")
                        .foregroundColor(searchForward ? .blue : .orange)
                        .font(.system(size: 14 * calendarManager.fontSize.scale))
                    Text(searchForward ? "Searching forward from today" : "Searching backward from today")
                        .font(.system(size: 12 * calendarManager.fontSize.scale))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16 * calendarManager.fontSize.scale))

                    TextField("Search events...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16 * calendarManager.fontSize.scale))
                        .focused($searchFocused)
                        .onSubmit {
                            closeSearch()
                        }

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(radius: 10)
            )
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color.black.opacity(0.3)
                .background(
                    Button("") {
                        closeSearch()
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                    .hidden()
                )
        )
        .onTapGesture {
            closeSearch()
        }
    }

    private func closeSearch() {
        showingSearch = false
        searchText = ""
        searchFocused = false
        highlightedEventIDs.removeAll()
    }

    private func searchForEvent(_ query: String) {
        let lowercased = query.lowercased()
        let now = Date()
        let calendar = Calendar.current

        // Query the store directly to avoid frozen object errors
        // Adjust search range based on direction
        let startDate: Date
        let endDate: Date

        if searchForward {
            // Forward search: from today to 12 months ahead
            startDate = now
            endDate = calendar.date(byAdding: .month, value: 12, to: now) ?? now
        } else {
            // Backward search: from 12 months ago to today
            startDate = calendar.date(byAdding: .month, value: -12, to: now) ?? now
            endDate = now
        }

        let predicate = calendarManager.eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let allEvents = calendarManager.eventStore.events(matching: predicate)

        // Find all matching events
        let matchingEvents = allEvents.filter { event in
            (event.title?.lowercased().contains(lowercased) ?? false) ||
            (event.location?.lowercased().contains(lowercased) ?? false) ||
            (event.notes?.lowercased().contains(lowercased) ?? false)
        }

        // Sort by date
        let sortedMatches = matchingEvents.sorted { event1, event2 in
            if searchForward {
                // Forward: earliest first
                return event1.startDate < event2.startDate
            } else {
                // Backward: latest first
                return event1.startDate > event2.startDate
            }
        }

        // Store highlighted event IDs
        highlightedEventIDs = Set(sortedMatches.compactMap { $0.eventIdentifier })

        // Navigate to the first match's date
        if let foundEvent = sortedMatches.first, let startDate = foundEvent.startDate {
            currentDate = startDate
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            toolbarView
            Divider()
            contentArea
        }
    }

    private var toolbarView: some View {
        HStack(spacing: 20) {
            navigationControls
            Spacer()
            ViewSelectorButtons(selectedView: $selectedView)
                .frame(width: 450)
            Spacer()
            quickAddField
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var navigationControls: some View {
        HStack(spacing: 10) {
            Button(action: goToToday) {
                Text("Today")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 3)
            }
            .buttonStyle(.bordered)

            Button(action: previousPeriod) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14))
            }
            .buttonStyle(.borderless)

            Button(action: nextPeriod) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
            }
            .buttonStyle(.borderless)

            Text(headerTitle)
                .font(.system(size: 32, weight: .bold))
                .frame(minWidth: 250)
        }
    }

    private var quickAddField: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.accentColor)

            TextField("Quick add event or reminder", text: $quickAddText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($quickAddFocused)
                .disabled(!calendarManager.hasAccess)
                .onSubmit {
                    if calendarManager.hasAccess {
                        createQuickEvent()
                    }
                }

            if !quickAddText.isEmpty {
                Button(action: { quickAddText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(quickAddFocused ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .frame(minWidth: 350)
    }

    private var contentArea: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Show bottom panel only if there are valid reminders
                if calendarManager.hasValidReminders {
                    let bottomPanelHeight = geometry.size.height * 0.15

                    calendarView
                        .frame(height: geometry.size.height - bottomPanelHeight)

                    Divider()

                    RemindersSection(
                        showingNewReminder: $showingNewReminder,
                        onReminderDoubleClick: { reminder in
                            reminderIdToEdit = reminder.calendarItemIdentifier
                            showingNewReminder = true
                        }
                    )
                    .frame(height: bottomPanelHeight)
                } else {
                    calendarView
                }
            }
        }
    }

    private var calendarView: some View {
        ZStack {
            switch selectedView {
            case .month:
                MonthView(
                    currentDate: $currentDate,
                    highlightedEventIDs: highlightedEventIDs,
                    weatherForecasts: weatherManager.dailyForecasts,
                    onDateDoubleClick: { date in
                        newEventDate = date
                        showingNewEvent = true
                    },
                    onEventDoubleClick: { event in
                        if let eventId = event.eventIdentifier {
                            print("Opening event for edit: \(event.title ?? "Untitled") with ID: \(eventId)")
                            eventIdToEdit = eventId
                        } else if let calendar = event.calendar {
                            print("Event '\(event.title ?? "Untitled")' has no identifier, using properties")
                            eventPropertiesToEdit = EventProperties(
                                title: event.title ?? "",
                                startDate: event.startDate,
                                endDate: event.endDate,
                                calendarIdentifier: calendar.calendarIdentifier
                            )
                        } else {
                            print("Cannot edit event '\(event.title ?? "Untitled")' - no identifier and calendar is nil")
                            return
                        }
                        showingNewEvent = true
                    }
                )
            case .week:
                WeekView(currentDate: $currentDate, highlightedEventIDs: highlightedEventIDs)
            case .workweek:
                MultiDayView(currentDate: $currentDate, numberOfDays: 5, workweekOnly: true, highlightedEventIDs: highlightedEventIDs)
            case .threeDay:
                MultiDayView(currentDate: $currentDate, numberOfDays: 3, highlightedEventIDs: highlightedEventIDs)
            case .today:
                TodayView(currentDate: $currentDate, highlightedEventIDs: highlightedEventIDs)
            case .agenda:
                AgendaView(currentDate: $currentDate, highlightedEventIDs: highlightedEventIDs)
            }
        }
    }

    private var headerTitle: String {
        let formatter = DateFormatter()

        switch selectedView {
        case .month:
            formatter.dateFormat = "MMMM yyyy"
        case .week, .workweek, .threeDay:
            // Show date range
            if let weekStart = calendar.dateInterval(of: .weekOfYear, for: currentDate)?.start,
               let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) {
                if calendar.component(.month, from: weekStart) == calendar.component(.month, from: weekEnd) {
                    formatter.dateFormat = "MMMM yyyy"
                    return formatter.string(from: weekStart)
                } else {
                    let startFormatter = DateFormatter()
                    startFormatter.dateFormat = "MMM d"
                    let endFormatter = DateFormatter()
                    endFormatter.dateFormat = "MMM d, yyyy"
                    return "\(startFormatter.string(from: weekStart)) – \(endFormatter.string(from: weekEnd))"
                }
            }
            formatter.dateFormat = "MMMM yyyy"
        case .today:
            formatter.dateFormat = "EEEE, MMMM d, yyyy"
        case .agenda:
            formatter.dateFormat = "MMMM yyyy"
        }

        return formatter.string(from: currentDate)
    }

    private func goToToday() {
        currentDate = Date()
    }

    private func isReminderInput(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        let reminderPrefixes = ["remind me to ", "remind me ", "remind ", "reminder ", "rem: ", "rem "]
        return reminderPrefixes.contains { lowercased.hasPrefix($0) }
    }

    private func removeReminderPrefix(_ text: String) -> String {
        let prefixes = [
            ("remind me to ", "remind me to ".count),
            ("remind me ", "remind me ".count),
            ("remind ", "remind ".count),
            ("reminder ", "reminder ".count),
            ("rem: ", "rem: ".count),
            ("rem ", "rem ".count)
        ]

        var result = text
        for (prefix, count) in prefixes {
            if result.lowercased().hasPrefix(prefix) {
                result = String(result.dropFirst(count))
                break
            }
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    private func createQuickEvent() {
        guard !quickAddText.isEmpty else { return }

        let parser = NaturalLanguageParser()

        // Check if it's a reminder
        if isReminderInput(quickAddText) {
            if let parsed = parser.parseReminderInput(quickAddText) {
                do {
                    try calendarManager.createReminder(
                        title: parsed.title,
                        dueDate: parsed.dueDate,
                        notes: parsed.notes
                    )
                    quickAddText = ""
                    quickAddFocused = false
                } catch {
                    print("Error creating quick reminder: \(error)")
                }
            } else {
                // Fallback: create reminder with raw text as title (removing prefix)
                let title = removeReminderPrefix(quickAddText)

                do {
                    try calendarManager.createReminder(
                        title: title,
                        dueDate: nil,
                        notes: nil
                    )
                    quickAddText = ""
                    quickAddFocused = false
                } catch {
                    print("Error creating quick reminder: \(error)")
                }
            }
        } else if let parsed = parser.parseEventInput(quickAddText) {
            do {
                try calendarManager.createEvent(
                    title: parsed.title,
                    startDate: parsed.startDate,
                    endDate: parsed.endDate,
                    calendar: nil,
                    notes: parsed.notes
                )
                quickAddText = ""
                quickAddFocused = false
            } catch {
                print("Error creating quick event: \(error)")
            }
        } else {
            // Fallback: create event with raw text as title, default to 6am today
            let startOfToday = calendar.startOfDay(for: Date())
            let startDate = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: startOfToday) ?? Date()
            let endDate = calendar.date(byAdding: .hour, value: 1, to: startDate) ?? startDate

            do {
                try calendarManager.createEvent(
                    title: quickAddText,
                    startDate: startDate,
                    endDate: endDate,
                    calendar: nil,
                    notes: nil
                )
                quickAddText = ""
                quickAddFocused = false
            } catch {
                print("Error creating quick event: \(error)")
            }
        }
    }

    private func previousPeriod() {
        switch selectedView {
        case .month:
            currentDate = calendar.date(byAdding: .month, value: -1, to: currentDate) ?? currentDate
        case .week, .workweek:
            currentDate = calendar.date(byAdding: .weekOfYear, value: -1, to: currentDate) ?? currentDate
        case .threeDay:
            currentDate = calendar.date(byAdding: .day, value: -3, to: currentDate) ?? currentDate
        case .today:
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        case .agenda:
            currentDate = calendar.date(byAdding: .month, value: -1, to: currentDate) ?? currentDate
        }
    }

    private func nextPeriod() {
        switch selectedView {
        case .month:
            currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
        case .week, .workweek:
            currentDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) ?? currentDate
        case .threeDay:
            currentDate = calendar.date(byAdding: .day, value: 3, to: currentDate) ?? currentDate
        case .today:
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        case .agenda:
            currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
        }
    }
}

struct ViewSelectorButtons: View {
    @Binding var selectedView: CalendarViewType

    var body: some View {
        HStack(spacing: 4) {
            ForEach(CalendarViewType.allCases, id: \.self) { viewType in
                ViewSelectorButton(
                    viewType: viewType,
                    isSelected: selectedView == viewType
                ) {
                    selectedView = viewType
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
        )
    }
}

struct ViewSelectorButton: View {
    let viewType: CalendarViewType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(viewType.rawValue)
                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                .fixedSize()
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .help(viewType.tooltip)
    }
}

struct CalendarAccessView: View {
    @EnvironmentObject var calendarManager: CalendarManager

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60 * calendarManager.fontSize.scale))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("Calendar Access Required")
                    .font(.system(size: 20 * calendarManager.fontSize.scale, weight: .semibold))

                Text("This app needs access to your calendars to display and manage events.")
                    .font(.system(size: 14 * calendarManager.fontSize.scale))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Grant Access") {
                calendarManager.requestAccess()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// View modifier for keyboard shortcuts
struct ViewShortcutsModifier: ViewModifier {
    @Binding var selectedView: CalendarViewType

    func body(content: Content) -> some View {
        content
            .background(
                Group {
                    Button("") { selectedView = .month }
                        .keyboardShortcut("1", modifiers: .command)
                        .hidden()
                    Button("") { selectedView = .week }
                        .keyboardShortcut("2", modifiers: .command)
                        .hidden()
                    Button("") { selectedView = .workweek }
                        .keyboardShortcut("3", modifiers: .command)
                        .hidden()
                    Button("") { selectedView = .threeDay }
                        .keyboardShortcut("4", modifiers: .command)
                        .hidden()
                    Button("") { selectedView = .agenda }
                        .keyboardShortcut("5", modifiers: .command)
                        .hidden()
                    Button("") { selectedView = .today }
                        .keyboardShortcut("6", modifiers: .command)
                        .hidden()
                }
            )
    }
}

extension View {
    func applyViewShortcuts(selectedView: Binding<CalendarViewType>) -> some View {
        self.modifier(ViewShortcutsModifier(selectedView: selectedView))
    }

    func applySearchShortcut(showingSearch: Binding<Bool>, searchForward: Binding<Bool>, searchFocused: FocusState<Bool>.Binding, quickAddFocused: FocusState<Bool>.Binding) -> some View {
        self.background(
            Group {
                // Forward search with /
                Button("") {
                    quickAddFocused.wrappedValue = false
                    searchForward.wrappedValue = true
                    showingSearch.wrappedValue = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        searchFocused.wrappedValue = true
                    }
                }
                .keyboardShortcut("/", modifiers: [])
                .hidden()

                // Backward search with \
                Button("") {
                    quickAddFocused.wrappedValue = false
                    searchForward.wrappedValue = false
                    showingSearch.wrappedValue = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        searchFocused.wrappedValue = true
                    }
                }
                .keyboardShortcut("\\", modifiers: [])
                .hidden()
            }
        )
    }

    func applyEventReminderShortcuts(showingNewEvent: Binding<Bool>, showingNewReminder: Binding<Bool>) -> some View {
        self.background(
            Group {
                // Command+E for new event
                Button("") {
                    showingNewEvent.wrappedValue = true
                }
                .keyboardShortcut("e", modifiers: .command)
                .hidden()

                // Command+R for new reminder
                Button("") {
                    showingNewReminder.wrappedValue = true
                }
                .keyboardShortcut("r", modifiers: .command)
                .hidden()
            }
        )
    }
}
