import SwiftUI
import EventKit

struct TodayView: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @Environment(\.colorScheme) var colorScheme
    @Binding var currentDate: Date
    let highlightedEventIDs: Set<String>

    @State private var containerWidth: CGFloat = 0

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
            let effectiveWidth = containerWidth > 0 ? containerWidth : geometry.size.width
            let dateHeaderWidth = effectiveWidth - totalTimeWidth

            VStack(spacing: 0) {
                // News feed
                NewsFeedView()
                    .environmentObject(calendarManager)
                    .frame(width: effectiveWidth)

                // Sticky header
                ZStack(alignment: .topLeading) {
                    Color(NSColor.controlBackgroundColor)
                        .frame(height: 70)

                    HStack(spacing: 0) {
                        // Empty spacer for timezone columns
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

                        // Empty spacer for local time column
                        Color.clear
                            .frame(width: timeColumnWidth, height: 70)

                        // Date header
                        VStack(spacing: 4) {
                            Text(dayOfWeek)
                                .font(.system(size: 13 * calendarManager.fontSize.scale, weight: .medium))
                                .foregroundColor(.secondary)

                            Text("\(calendar.component(.day, from: currentDate))")
                                .font(.system(size: 20 * calendarManager.fontSize.scale, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(Color.blue)
                                )
                        }
                        .frame(width: dateHeaderWidth, height: 70)
                    }
                }
                .frame(width: effectiveWidth, height: 70)
                .border(Color(NSColor.separatorColor), width: 0.5)

                // Scrollable content
                ScrollView(.vertical, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 0) {
                        // Alternate timezone columns
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

                        // Today column (without header)
                        TodayColumnContent(date: currentDate, hourHeight: hourHeight, highlightedEventIDs: highlightedEventIDs)
                            .frame(width: dateHeaderWidth)
                    }
                    .frame(width: effectiveWidth, alignment: .leading)
                }
                .frame(width: effectiveWidth)
            }
            .frame(width: effectiveWidth, alignment: .topLeading)
            .clipped()
            .onAppear {
                if containerWidth == 0 {
                    containerWidth = geometry.size.width
                }
            }
        }
    }

    private var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: currentDate).uppercased()
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

struct TodayColumnContent: View {
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
        .background(Color.clear)
        .border(Color(NSColor.separatorColor), width: 0.5)
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
            guard let currentEnd = currentEvent.endDate,
                  let nextStart = nextEvent.startDate else {
                continue
            }

            if currentEnd < nextStart {
                let duration = nextStart.timeIntervalSince(currentEnd)

                // Only show gaps of at least 15 minutes
                if duration >= 900 {
                    let secondsFromStart = currentEnd.timeIntervalSince(startOfDay)
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
