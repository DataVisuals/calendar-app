import SwiftUI
import EventKit

struct MonthView: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @Binding var currentDate: Date

    private let calendar = Calendar.current
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Day headers
                HStack(spacing: 0) {
                    ForEach(Array(daysOfWeek.enumerated()), id: \.element) { index, day in
                        Text(day)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(index == 0 || index == 6 ? .accentColor : .secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 14)
                .background(Color(NSColor.controlBackgroundColor))

                // Calculate cell height based on available space
                let headerHeight: CGFloat = 44
                let availableHeight = geometry.size.height - headerHeight
                let numberOfWeeks = CGFloat(getDaysInMonth().count / 7)
                let cellHeight = availableHeight / numberOfWeeks

                // Calendar grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                    ForEach(getDaysInMonth(), id: \.self) { date in
                        DayCell(date: date, currentMonth: isInCurrentMonth(date))
                            .frame(height: cellHeight)
                    }
                }
            }
        }
    }

    private func getDaysInMonth() -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentDate),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }

        var dates: [Date] = []
        var date = monthFirstWeek.start

        // Get enough weeks to fill the calendar
        for _ in 0..<42 {
            dates.append(date)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = nextDate
        }

        return dates
    }

    private func isInCurrentMonth(_ date: Date) -> Bool {
        calendar.isDate(date, equalTo: currentDate, toGranularity: .month)
    }
}

struct DayCell: View {
    @EnvironmentObject var calendarManager: CalendarManager
    let date: Date
    let currentMonth: Bool

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Day number
            HStack {
                Spacer()
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 20, weight: isToday ? .bold : .regular))
                    .foregroundColor(currentMonth ? (isToday ? .white : .primary) : .secondary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(isToday ? Color.accentColor : Color.clear)
                    )
                    .padding(.top, 4)
                    .padding(.trailing, 4)
            }

            // Events
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(dayEvents.prefix(3), id: \.eventIdentifier) { event in
                        EventBadge(event: event, compact: true)
                    }

                    if dayEvents.count > 3 {
                        Text("+\(dayEvents.count - 3) more")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .background(
            Group {
                if isWeekend {
                    Color.accentColor.opacity(currentMonth ? 0.08 : 0.04)
                } else {
                    currentMonth ? Color(NSColor.controlBackgroundColor) : Color(NSColor.controlBackgroundColor).opacity(0.5)
                }
            }
        )
        .border(Color(NSColor.separatorColor), width: 0.5)
        .overlay(
            isWeekend ?
                Rectangle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 2)
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

    private var dayEvents: [EKEvent] {
        calendarManager.events(for: date)
    }
}

struct EventBadge: View {
    @EnvironmentObject var calendarManager: CalendarManager
    let event: EKEvent
    let compact: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Image(systemName: EventIconHelper.icon(for: event))
                .font(.system(size: compact ? 11 : 13))
                .foregroundColor(calendarManager.color(for: event.calendar))
                .frame(width: compact ? 14 : 16)
                .padding(.top, 1)

            Text(event.title ?? "Untitled")
                .font(.system(size: compact ? 13 : 15))
                .lineLimit(compact ? 2 : 1)
                .fixedSize(horizontal: false, vertical: true)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, compact ? 3 : 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(calendarManager.color(for: event.calendar).opacity(0.15))
        )
    }
}
