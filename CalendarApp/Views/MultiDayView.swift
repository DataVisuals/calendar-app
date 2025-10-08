import SwiftUI
import EventKit

struct MultiDayView: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @Binding var currentDate: Date
    let numberOfDays: Int
    let workweekOnly: Bool
    let highlightedEventIDs: Set<String>

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday = 2 (Sunday = 1)
        return cal
    }
    private let hourHeight: CGFloat = 70

    init(currentDate: Binding<Date>, numberOfDays: Int, workweekOnly: Bool = false, highlightedEventIDs: Set<String> = []) {
        self._currentDate = currentDate
        self.numberOfDays = numberOfDays
        self.workweekOnly = workweekOnly
        self.highlightedEventIDs = highlightedEventIDs
    }

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
                        ForEach(displayDays, id: \.self) { date in
                            DayHeader(date: date)
                                .frame(width: (geometry.size.width - totalTimeWidth) / CGFloat(displayDays.count), height: 70)
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
                            ForEach(displayDays, id: \.self) { date in
                                DayColumnContent(date: date, hourHeight: hourHeight, highlightedEventIDs: highlightedEventIDs)
                                    .frame(width: (geometry.size.width - totalTimeWidth) / CGFloat(displayDays.count))
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
                // Scroll up = go to previous period
                if let newDate = calendar.date(byAdding: .day, value: -numberOfDays, to: currentDate) {
                    currentDate = newDate
                }
            } else {
                // Scroll down = go to next period
                if let newDate = calendar.date(byAdding: .day, value: numberOfDays, to: currentDate) {
                    currentDate = newDate
                }
            }
        }
    }

    private var displayDays: [Date] {
        if workweekOnly {
            return workweekDays
        } else {
            return consecutiveDays
        }
    }

    private var consecutiveDays: [Date] {
        var days: [Date] = []
        let startDate = calendar.startOfDay(for: currentDate)

        for i in 0..<numberOfDays {
            if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                days.append(date)
            }
        }

        return days
    }

    private var workweekDays: [Date] {
        // Find the start of the week containing currentDate
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: currentDate) else {
            return []
        }

        var days: [Date] = []
        var date = weekInterval.start

        for _ in 0..<7 {
            let weekday = calendar.component(.weekday, from: date)
            // Include Monday (2) through Friday (6)
            if weekday >= 2 && weekday <= 6 {
                days.append(date)
            }
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

// DayColumn and EventBlock are already defined in WeekView.swift and will be reused
