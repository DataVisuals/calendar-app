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
            HStack(spacing: 0) {
                // Time labels
                VStack(spacing: 0) {
                    // Header spacer
                    Text("")
                        .frame(height: 70)

                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(formatHour(hour))
                                    .font(.system(size: 14 * calendarManager.fontSize.scale))
                                    .foregroundColor(.secondary)
                                    .frame(width: 60, height: hourHeight, alignment: .top)
                            }
                        }
                    }
                    .scrollDisabled(true)
                }
                .frame(width: 60)

                // Days
                ScrollView {
                    HStack(spacing: 0) {
                        ForEach(displayDays, id: \.self) { date in
                            DayColumn(date: date, hourHeight: hourHeight, highlightedEventIDs: highlightedEventIDs)
                                .frame(width: (geometry.size.width - 60) / CGFloat(displayDays.count))
                        }
                    }
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
}

// DayColumn and EventBlock are already defined in WeekView.swift and will be reused
