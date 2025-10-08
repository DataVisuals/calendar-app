import SwiftUI
import EventKit

struct WeekView: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @Environment(\.colorScheme) var colorScheme
    @Binding var currentDate: Date
    let highlightedEventIDs: Set<String>

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday = 2 (Sunday = 1)
        return cal
    }
    private let hourHeight: CGFloat = 70

    var body: some View {
        GeometryReader { geometry in
            let timeColumnWidth: CGFloat = 60
            let totalTimeColumns = 1 + calendarManager.alternateTimezones.count
            let totalTimeWidth = CGFloat(totalTimeColumns) * timeColumnWidth

            VStack(spacing: 0) {
                // Headers
                HStack(spacing: 0) {
                    // Timezone headers
                    ForEach(0..<calendarManager.alternateTimezones.count, id: \.self) { index in
                        let tzIdentifier = calendarManager.alternateTimezones[index]
                        if let tz = TimeZone(identifier: tzIdentifier) {
                            Text(tz.abbreviation() ?? "")
                                .font(.system(size: 10 * calendarManager.fontSize.scale, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: timeColumnWidth, height: 70)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                        }
                    }

                    // Empty spacer for local time
                    Text("")
                        .frame(width: timeColumnWidth, height: 70)

                    // Day headers
                    HStack(spacing: 0) {
                        ForEach(weekDays, id: \.self) { date in
                            DayHeader(date: date)
                                .frame(width: (geometry.size.width - totalTimeWidth) / 7, height: 70)
                        }
                    }
                }

                // Scrollable content
                ScrollView {
                    HStack(alignment: .top, spacing: 0) {
                        // Timezone columns
                        ForEach(0..<calendarManager.alternateTimezones.count, id: \.self) { index in
                            let tzIdentifier = calendarManager.alternateTimezones[index]
                            if let tz = TimeZone(identifier: tzIdentifier) {
                                VStack(spacing: 0) {
                                    ForEach(0..<24, id: \.self) { hour in
                                        Text(formatHourForTimezone(hour, timezone: tz))
                                            .font(.system(size: 12 * calendarManager.fontSize.scale))
                                            .foregroundColor(.secondary.opacity(0.7))
                                            .frame(width: timeColumnWidth, height: hourHeight, alignment: .top)
                                    }
                                }
                                .frame(width: timeColumnWidth)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.05))
                            }
                        }

                        // Local time labels
                        VStack(spacing: 0) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(formatHour(hour))
                                    .font(.system(size: 14 * calendarManager.fontSize.scale))
                                    .foregroundColor(.secondary)
                                    .frame(width: timeColumnWidth, height: hourHeight, alignment: .top)
                            }
                        }
                        .frame(width: timeColumnWidth)

                        // Day columns
                        HStack(spacing: 0) {
                            ForEach(weekDays, id: \.self) { date in
                                DayColumnContent(date: date, hourHeight: hourHeight, highlightedEventIDs: highlightedEventIDs)
                                    .frame(width: (geometry.size.width - totalTimeWidth) / 7)
                            }
                        }
                    }
                }
            }
            .onScrollWheel { event in
                handleScrollWheel(event)
            }
        }
    }

    private func handleScrollWheel(_ event: NSEvent) {
        let threshold: CGFloat = 10.0

        if abs(event.scrollingDeltaY) > threshold {
            if event.scrollingDeltaY > 0 {
                // Scroll up = go to previous week
                if let newDate = calendar.date(byAdding: .weekOfYear, value: -1, to: currentDate) {
                    currentDate = newDate
                }
            } else {
                // Scroll down = go to next week
                if let newDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) {
                    currentDate = newDate
                }
            }
        }
    }

    private var weekDays: [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: currentDate) else {
            return []
        }

        var days: [Date] = []
        var date = weekInterval.start

        for _ in 0..<7 {
            days.append(date)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = nextDate
        }

        return days
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date).lowercased()
    }

    private func formatHourForTimezone(_ hour: Int, timezone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        formatter.timeZone = timezone

        // Create a date in local time for the given hour
        let localDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: currentDate) ?? Date()

        // Format it in the target timezone
        return formatter.string(from: localDate).lowercased()
    }
}

struct DayHeader: View {
    @EnvironmentObject var calendarManager: CalendarManager
    let date: Date

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2
        cal.timeZone = TimeZone.current
        return cal
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(dayOfWeek)
                .font(.system(size: 13 * calendarManager.fontSize.scale, weight: .medium))
                .foregroundColor(.secondary)

            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 20 * calendarManager.fontSize.scale, weight: isToday ? .bold : .regular))
                .foregroundColor(isToday ? .white : .primary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isToday ? Color.blue : Color.clear)
                )
        }
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var isToday: Bool {
        calendar.isDateInToday(date)
    }

    private var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }
}

struct DayColumnContent: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @Environment(\.colorScheme) var colorScheme
    let date: Date
    let hourHeight: CGFloat
    let highlightedEventIDs: Set<String>

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2
        cal.timeZone = TimeZone.current
        return cal
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Hour lines
            VStack(spacing: 0) {
                ForEach(0..<24, id: \.self) { hour in
                    Rectangle()
                        .fill(Color(NSColor.separatorColor))
                        .frame(height: 0.5)
                        .frame(maxWidth: .infinity)
                    Spacer()
                        .frame(height: hourHeight - 0.5)
                }
            }

            // Events
            ForEach(Array(dayEvents.enumerated()), id: \.offset) { _, event in
                EventBlock(event: event, hourHeight: hourHeight, date: date, isHighlighted: event.eventIdentifier.map { highlightedEventIDs.contains($0) } ?? false)
            }
        }
        .background(
            isWeekend ? Color.accentColor.opacity(0.06) : Color.clear
        )
        .border(Color(NSColor.separatorColor), width: 0.5)
        .overlay(
            isWeekend ?
                Rectangle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                : nil
        )
    }

    private var isWeekend: Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    private var dayEvents: [EKEvent] {
        calendarManager.events(for: date).filter { !$0.isAllDay }
    }
}

struct EventBlock: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @Environment(\.colorScheme) var colorScheme
    let event: EKEvent
    let hourHeight: CGFloat
    let date: Date
    let isHighlighted: Bool

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday = 2 (Sunday = 1)
        cal.timeZone = TimeZone.current  // Explicitly use current timezone
        return cal
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: EventIconHelper.icon(for: event))
                    .font(.system(size: 12 * calendarManager.fontSize.scale))
                    .foregroundColor(calendarManager.color(for: event.calendar, colorScheme: colorScheme))
                    .frame(width: 16)

                Text(event.title ?? "Untitled")
                    .font(.system(size: 14 * calendarManager.fontSize.scale, weight: .medium))
                    .lineLimit(1)
            }

            Text(isDragging ? previewTimeString : timeString)
                .font(.system(size: 12 * calendarManager.fontSize.scale))
                .foregroundColor(.secondary)
                .padding(.leading, 20)
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(calendarManager.color(for: event.calendar, colorScheme: colorScheme).opacity(isHighlighted ? 0.5 : 0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(calendarManager.color(for: event.calendar, colorScheme: colorScheme), lineWidth: isHighlighted ? 2.5 : 1.5)
        )
        .offset(y: offsetY + dragOffset)
        .frame(height: height)
        .padding(.horizontal, 3)
        .opacity(isDragging ? 0.7 : 1.0)
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    // Snap to 15-minute intervals
                    let rawOffset = value.translation.height
                    let minutesPerPixel = 60.0 / hourHeight
                    let totalMinutes = rawOffset * minutesPerPixel
                    let snappedMinutes = round(totalMinutes / 15.0) * 15.0
                    dragOffset = (snappedMinutes / 60.0) * hourHeight
                }
                .onEnded { _ in
                    isDragging = false

                    // Calculate new start time
                    let minutesOffset = (dragOffset / hourHeight) * 60
                    if let newStartDate = calendar.date(byAdding: .minute, value: Int(minutesOffset), to: event.startDate) {
                        // Move the event
                        do {
                            try calendarManager.moveEvent(event, to: newStartDate)
                        } catch {
                            print("Failed to move event: \(error)")
                        }
                    }

                    dragOffset = 0
                }
        )
    }

    private var offsetY: CGFloat {
        guard let eventStart = event.startDate else { return 0 }

        let startOfDay = calendar.startOfDay(for: date)
        let secondsFromStart = eventStart.timeIntervalSince(startOfDay)
        let hours = secondsFromStart / 3600
        return CGFloat(hours) * hourHeight
    }

    private var height: CGFloat {
        guard let eventStart = event.startDate,
              let eventEnd = event.endDate else { return 20 }

        let duration = eventEnd.timeIntervalSince(eventStart)
        let hours = duration / 3600
        return max(CGFloat(hours) * hourHeight - 4, 20)
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: event.startDate)
    }

    private var previewTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        let minutesOffset = (dragOffset / hourHeight) * 60
        if let newStartDate = calendar.date(byAdding: .minute, value: Int(minutesOffset), to: event.startDate) {
            return formatter.string(from: newStartDate)
        }
        return timeString
    }
}
