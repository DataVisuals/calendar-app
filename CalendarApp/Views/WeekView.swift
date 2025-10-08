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
                        ForEach(weekDays, id: \.self) { date in
                            DayColumn(date: date, hourHeight: hourHeight, highlightedEventIDs: highlightedEventIDs)
                                .frame(width: (geometry.size.width - 60) / 7)
                        }
                    }
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
}

struct DayColumn: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @Environment(\.colorScheme) var colorScheme
    let date: Date
    let hourHeight: CGFloat
    let highlightedEventIDs: Set<String>

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday = 2 (Sunday = 1)
        return cal
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
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
            .frame(height: 70)
            .frame(maxWidth: .infinity)
            .background(Color(NSColor.controlBackgroundColor))

            // Hour grid with events
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

    private var isToday: Bool {
        calendar.isDateInToday(date)
    }

    private var isWeekend: Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7 // Sunday or Saturday
    }

    private var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
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

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday = 2 (Sunday = 1)
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

            Text(timeString)
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
        .offset(y: offsetY)
        .frame(height: height)
        .padding(.horizontal, 3)
    }

    private var offsetY: CGFloat {
        let startOfDay = calendar.startOfDay(for: date)
        let secondsFromStart = event.startDate.timeIntervalSince(startOfDay)
        let hours = secondsFromStart / 3600
        return CGFloat(hours) * hourHeight
    }

    private var height: CGFloat {
        let duration = event.endDate.timeIntervalSince(event.startDate)
        let hours = duration / 3600
        return max(CGFloat(hours) * hourHeight - 4, 20)
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: event.startDate)
    }
}
