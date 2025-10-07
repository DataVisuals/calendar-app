import SwiftUI
import EventKit

enum CalendarViewType: String, CaseIterable {
    case month = "Month"
    case week = "Week"
    case workweek = "Work Week"
    case threeDay = "3 Days"
    case agenda = "Agenda"

    var shortcut: KeyEquivalent {
        switch self {
        case .month: return "1"
        case .week: return "2"
        case .workweek: return "3"
        case .threeDay: return "4"
        case .agenda: return "5"
        }
    }

    var tooltip: String {
        switch self {
        case .month: return "Month (⌘1)"
        case .week: return "Week (⌘2)"
        case .workweek: return "Work Week (⌘3)"
        case .threeDay: return "3 Days (⌘4)"
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
    @State private var showingSearch = false
    @State private var searchText = ""
    @State private var highlightedEventIDs: Set<String> = []
    @FocusState private var searchFocused: Bool
    @State private var quickAddText = ""
    @FocusState private var quickAddFocused: Bool

    private let calendar = Calendar.current

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
            NewEventSheet()
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
            calendarManager.loadEvents()
            calendarManager.loadReminders()
        }
        .applyViewShortcuts(selectedView: $selectedView)
        .applySearchShortcut(showingSearch: $showingSearch, searchFocused: $searchFocused)
    }

    private var searchOverlay: some View {
        VStack {
            Spacer()

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
            .padding(12)
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

        // Find all matching events
        let matchingEvents = calendarManager.events.filter { event in
            (event.title?.lowercased().contains(lowercased) ?? false) ||
            (event.location?.lowercased().contains(lowercased) ?? false) ||
            (event.notes?.lowercased().contains(lowercased) ?? false)
        }

        // Store highlighted event IDs
        highlightedEventIDs = Set(matchingEvents.compactMap { $0.eventIdentifier })

        // Navigate to the first match's date
        if let foundEvent = matchingEvents.first, let startDate = foundEvent.startDate {
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
                .frame(width: 450 * calendarManager.fontSize.scale)
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
                    .font(.system(size: 13 * calendarManager.fontSize.scale, weight: .medium))
                    .padding(.horizontal, 3)
            }
            .buttonStyle(.bordered)

            Button(action: previousPeriod) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14 * calendarManager.fontSize.scale))
            }
            .buttonStyle(.borderless)

            Button(action: nextPeriod) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14 * calendarManager.fontSize.scale))
            }
            .buttonStyle(.borderless)

            Text(headerTitle)
                .font(.system(size: 18 * calendarManager.fontSize.scale, weight: .semibold))
                .frame(minWidth: 200)
        }
    }

    private var quickAddField: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 16 * calendarManager.fontSize.scale))
                .foregroundColor(.accentColor)

            TextField("Quick add event (e.g., 'Meeting tomorrow at 2pm')", text: $quickAddText)
                .textFieldStyle(.plain)
                .font(.system(size: 14 * calendarManager.fontSize.scale))
                .focused($quickAddFocused)
                .onSubmit {
                    createQuickEvent()
                }

            if !quickAddText.isEmpty {
                Button(action: { quickAddText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14 * calendarManager.fontSize.scale))
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
                // Show bottom panel only if there are reminders
                if !calendarManager.reminders.isEmpty {
                    let bottomPanelHeight = geometry.size.height * 0.2

                    calendarView
                        .frame(height: geometry.size.height - bottomPanelHeight)

                    Divider()

                    RemindersSection()
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
                MonthView(currentDate: $currentDate, highlightedEventIDs: highlightedEventIDs, weatherForecasts: weatherManager.dailyForecasts)
            case .week:
                WeekView(currentDate: $currentDate, highlightedEventIDs: highlightedEventIDs)
            case .workweek:
                MultiDayView(currentDate: $currentDate, numberOfDays: 5, workweekOnly: true, highlightedEventIDs: highlightedEventIDs)
            case .threeDay:
                MultiDayView(currentDate: $currentDate, numberOfDays: 3, highlightedEventIDs: highlightedEventIDs)
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
        case .agenda:
            formatter.dateFormat = "MMMM yyyy"
        }

        return formatter.string(from: currentDate)
    }

    private func goToToday() {
        currentDate = Date()
    }

    private func createQuickEvent() {
        guard !quickAddText.isEmpty else { return }

        let parser = NaturalLanguageParser()

        if let parsed = parser.parseEventInput(quickAddText) {
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
            // Fallback: create event with raw text as title
            let startDate = Date()
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

    @EnvironmentObject var calendarManager: CalendarManager

    var body: some View {
        Button(action: action) {
            Text(viewType.rawValue)
                .font(.system(size: 12 * calendarManager.fontSize.scale, weight: isSelected ? .medium : .regular))
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
                }
            )
    }
}

extension View {
    func applyViewShortcuts(selectedView: Binding<CalendarViewType>) -> some View {
        self.modifier(ViewShortcutsModifier(selectedView: selectedView))
    }

    func applySearchShortcut(showingSearch: Binding<Bool>, searchFocused: FocusState<Bool>.Binding) -> some View {
        self.background(
            Button("") {
                showingSearch.wrappedValue = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    searchFocused.wrappedValue = true
                }
            }
            .keyboardShortcut("/", modifiers: [])
            .hidden()
        )
    }
}
