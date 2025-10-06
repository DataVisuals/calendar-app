import Foundation

struct ParsedEvent {
    let title: String
    let startDate: Date
    let endDate: Date
    let notes: String?
}

class NaturalLanguageParser {
    private let calendar = Calendar.current

    func parseEventInput(_ input: String) -> ParsedEvent? {
        var text = input.lowercased()
        var startDate: Date?
        var duration: TimeInterval = 3600 // Default 1 hour

        // Extract duration first
        if let durationMatch = text.range(of: #"for (\d+)\s*(hour|hr|h|minute|min|m)s?"#, options: .regularExpression) {
            let durationText = String(text[durationMatch])
            if let value = extractNumber(from: durationText) {
                if durationText.contains("hour") || durationText.contains("hr") || durationText.contains("h") {
                    duration = TimeInterval(value * 3600)
                } else {
                    duration = TimeInterval(value * 60)
                }
            }
            text.removeSubrange(durationMatch)
        }

        // Parse relative dates
        if text.contains("tomorrow") {
            startDate = calendar.date(byAdding: .day, value: 1, to: Date())
        } else if text.contains("today") {
            startDate = Date()
        } else if let match = text.range(of: #"in (\d+) day"#, options: .regularExpression) {
            let matchText = String(text[match])
            if let days = extractNumber(from: matchText) {
                startDate = calendar.date(byAdding: .day, value: days, to: Date())
            }
        } else if let match = text.range(of: #"next (monday|tuesday|wednesday|thursday|friday|saturday|sunday)"#, options: .regularExpression) {
            let dayName = String(text[match]).replacingOccurrences(of: "next ", with: "")
            startDate = nextWeekday(dayName)
        }

        // Extract time
        var hour = 9
        var minute = 0

        if let timeMatch = text.range(of: #"(\d{1,2}):(\d{2})\s*(am|pm)?"#, options: .regularExpression) {
            let timeText = String(text[timeMatch])
            let components = timeText.components(separatedBy: ":")
            if let h = Int(components[0]) {
                hour = h
                if let minText = components[1].split(separator: " ").first,
                   let m = Int(minText) {
                    minute = m
                }
                if timeText.contains("pm") && hour < 12 {
                    hour += 12
                } else if timeText.contains("am") && hour == 12 {
                    hour = 0
                }
            }
        } else if let timeMatch = text.range(of: #"(\d{1,2})\s*(am|pm)"#, options: .regularExpression) {
            let timeText = String(text[timeMatch])
            if let h = extractNumber(from: timeText) {
                hour = h
                if timeText.contains("pm") && hour < 12 {
                    hour += 12
                } else if timeText.contains("am") && hour == 12 {
                    hour = 0
                }
            }
        } else if let timeMatch = text.range(of: #"at (\d{1,2})"#, options: .regularExpression) {
            let timeText = String(text[timeMatch])
            if let h = extractNumber(from: timeText) {
                hour = h
            }
        }

        // Build start date with time
        if let baseDate = startDate {
            startDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: baseDate)
        }

        guard let finalStartDate = startDate else {
            return nil
        }

        let finalEndDate = finalStartDate.addingTimeInterval(duration)

        // Extract title (everything before time/date markers)
        var title = input
        let markers = ["tomorrow", "today", "next", "at ", "for ", "in "]
        for marker in markers {
            if let range = title.lowercased().range(of: marker) {
                title = String(title[..<range.lowerBound])
                break
            }
        }
        title = title.trimmingCharacters(in: .whitespaces)

        if title.isEmpty {
            title = "New Event"
        }

        return ParsedEvent(title: title, startDate: finalStartDate, endDate: finalEndDate, notes: nil)
    }

    private func extractNumber(from text: String) -> Int? {
        let numbers = text.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Int(numbers)
    }

    private func nextWeekday(_ dayName: String) -> Date? {
        let weekdays = ["sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
                       "thursday": 5, "friday": 6, "saturday": 7]

        guard let targetWeekday = weekdays[dayName.lowercased()] else {
            return nil
        }

        let today = Date()
        let currentWeekday = calendar.component(.weekday, from: today)

        var daysToAdd = targetWeekday - currentWeekday
        if daysToAdd <= 0 {
            daysToAdd += 7
        }

        return calendar.date(byAdding: .day, value: daysToAdd, to: today)
    }
}
