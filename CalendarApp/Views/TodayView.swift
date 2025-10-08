import SwiftUI
import EventKit

struct TodayView: View {
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

                // Today column
                ScrollView {
                    TodayColumn(date: currentDate, hourHeight: hourHeight, highlightedEventIDs: highlightedEventIDs)
                        .frame(width: geometry.size.width - 60)
                }
            }
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date).lowercased()
    }
}

struct TodayColumn: View {
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
                    .font(.system(size: 20 * calendarManager.fontSize.scale, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.blue)
                    )
            }
            .frame(height: 70)
            .frame(maxWidth: .infinity)
            .background(Color(NSColor.controlBackgroundColor))

            // Hour grid with events and gaps
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
                    TodayEventBlock(event: event, hourHeight: hourHeight, date: date, isHighlighted: event.eventIdentifier.map { highlightedEventIDs.contains($0) } ?? false)
                }

                // Gaps
                ForEach(Array(eventGaps.enumerated()), id: \.offset) { _, gap in
                    GapIndicator(gap: gap, hourHeight: hourHeight)
                }
            }
        }
        .background(Color.clear)
        .border(Color(NSColor.separatorColor), width: 0.5)
    }

    private var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }

    private var dayEvents: [EKEvent] {
        calendarManager.events(for: date).filter { !$0.isAllDay }.sorted { $0.startDate < $1.startDate }
    }

    private var eventGaps: [EventGap] {
        var gaps: [EventGap] = []
        let events = dayEvents

        guard !events.isEmpty else { return gaps }

        let startOfDay = calendar.startOfDay(for: date)

        for i in 0..<events.count - 1 {
            let currentEvent = events[i]
            let nextEvent = events[i + 1]

            // Check if there's a gap between current event end and next event start
            if currentEvent.endDate < nextEvent.startDate {
                let gapStart = currentEvent.endDate
                let gapEnd = nextEvent.startDate
                let duration = gapEnd.timeIntervalSince(gapStart)

                // Only show gaps of at least 15 minutes
                if duration >= 900 {
                    let secondsFromStart = gapStart.timeIntervalSince(startOfDay)
                    let hours = secondsFromStart / 3600
                    let offsetY = CGFloat(hours) * hourHeight

                    let gapHours = duration / 3600
                    let height = CGFloat(gapHours) * hourHeight

                    gaps.append(EventGap(offsetY: offsetY, height: height, duration: duration))
                }
            }
        }

        return gaps
    }
}

struct EventGap: Identifiable {
    let id = UUID()
    let offsetY: CGFloat
    let height: CGFloat
    let duration: TimeInterval
}

struct GapIndicator: View {
    @EnvironmentObject var calendarManager: CalendarManager
    let gap: EventGap
    let hourHeight: CGFloat

    var body: some View {
        VStack(spacing: 2) {
            Spacer()

            HStack(spacing: 6) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)

                Text(formatDuration(gap.duration))
                    .font(.system(size: 11 * calendarManager.fontSize.scale))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.9))
                    )

                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.horizontal, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: gap.height)
        .offset(y: gap.offsetY)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m free"
        } else if hours > 0 {
            return "\(hours)h free"
        } else {
            return "\(minutes)m free"
        }
    }
}

struct TodayEventBlock: View {
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
        .padding(.horizontal, 8)
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
        let endTime = formatter.string(from: event.endDate)
        return "\(formatter.string(from: event.startDate)) – \(endTime)"
    }

    private var previewTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        let minutesOffset = (dragOffset / hourHeight) * 60
        if let newStartDate = calendar.date(byAdding: .minute, value: Int(minutesOffset), to: event.startDate),
           let duration = calendar.dateComponents([.minute], from: event.startDate, to: event.endDate).minute,
           let newEndDate = calendar.date(byAdding: .minute, value: duration, to: newStartDate) {
            let endTime = formatter.string(from: newEndDate)
            return "\(formatter.string(from: newStartDate)) – \(endTime)"
        }
        return timeString
    }
}
