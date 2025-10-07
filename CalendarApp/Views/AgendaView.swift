import SwiftUI
import EventKit

struct AgendaView: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @Binding var currentDate: Date
    let highlightedEventIDs: Set<String>

    private let calendar = Calendar.current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(upcomingDays, id: \.self) { date in
                    AgendaDaySection(date: date, highlightedEventIDs: highlightedEventIDs)
                }
            }
            .padding()
        }
    }

    private var upcomingDays: [Date] {
        var days: [Date] = []
        let startDate = calendar.startOfDay(for: currentDate)

        for i in 0..<30 {
            if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                days.append(date)
            }
        }

        return days
    }
}

struct AgendaDaySection: View {
    @EnvironmentObject var calendarManager: CalendarManager
    let date: Date
    let highlightedEventIDs: Set<String>

    private let calendar = Calendar.current

    var body: some View {
        let dayEvents = calendarManager.events(for: date).filter { $0.eventIdentifier != nil }

        if !dayEvents.isEmpty || calendar.isDateInToday(date) {
            VStack(alignment: .leading, spacing: 8) {
                // Date header
                HStack(spacing: 12) {
                    VStack(spacing: 2) {
                        Text(monthAbbr)
                            .font(.system(size: 13 * calendarManager.fontSize.scale, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("\(calendar.component(.day, from: date))")
                            .font(.system(size: 22 * calendarManager.fontSize.scale, weight: .bold))
                    }
                    .frame(width: 50)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(dayOfWeek)
                            .font(.system(size: 18 * calendarManager.fontSize.scale, weight: .semibold))
                        if calendar.isDateInToday(date) {
                            Text("Today")
                                .font(.system(size: 13 * calendarManager.fontSize.scale))
                                .foregroundColor(.accentColor)
                        }
                    }

                    Spacer()
                }
                .padding(.vertical, 8)

                // Events
                if dayEvents.isEmpty {
                    Text("No events")
                        .font(.system(size: 15 * calendarManager.fontSize.scale))
                        .foregroundColor(.secondary)
                        .padding(.leading, 62)
                        .padding(.vertical, 8)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(dayEvents, id: \.eventIdentifier) { event in
                            AgendaEventRow(event: event, isHighlighted: highlightedEventIDs.contains(event.eventIdentifier))
                        }
                    }
                    .padding(.leading, 62)
                }

                Divider()
            }
        }
    }

    private var monthAbbr: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date).uppercased()
    }

    private var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}

struct AgendaEventRow: View {
    @EnvironmentObject var calendarManager: CalendarManager
    let event: EKEvent
    let isHighlighted: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time or all-day indicator
            if event.isAllDay {
                Text("All Day")
                    .font(.system(size: 14 * calendarManager.fontSize.scale))
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)
            } else {
                Text(timeString)
                    .font(.system(size: 14 * calendarManager.fontSize.scale))
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)
            }

            // Event details
            HStack(alignment: .top, spacing: 8) {
                Rectangle()
                    .fill(calendarManager.color(for: event.calendar))
                    .frame(width: isHighlighted ? 6 : 4)
                    .cornerRadius(2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: EventIconHelper.icon(for: event))
                            .font(.system(size: 14 * calendarManager.fontSize.scale))
                            .foregroundColor(calendarManager.color(for: event.calendar))

                        Text(event.title ?? "Untitled")
                            .font(.system(size: 16 * calendarManager.fontSize.scale, weight: .medium))
                    }

                    if let location = event.location, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 12 * calendarManager.fontSize.scale))
                            Text(location)
                                .font(.system(size: 14 * calendarManager.fontSize.scale))
                        }
                        .foregroundColor(.secondary)
                    }

                    if let notes = event.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 14 * calendarManager.fontSize.scale))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(calendarManager.color(for: event.calendar).opacity(isHighlighted ? 0.25 : 0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHighlighted ? calendarManager.color(for: event.calendar).opacity(0.8) : Color.clear, lineWidth: 2)
        )
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: event.startDate)
    }
}
