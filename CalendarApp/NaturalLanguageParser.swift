import Foundation

struct ParsedEvent {
    let title: String
    let startDate: Date
    let endDate: Date
    let notes: String?
}

struct ParsedReminder {
    let title: String
    let dueDate: Date?
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
        } else if let match = text.range(of: #"next (monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)"#, options: .regularExpression) {
            let dayName = String(text[match]).replacingOccurrences(of: "next ", with: "")
            startDate = nextWeekday(dayName)
        } else if let match = text.range(of: #"on (monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)"#, options: .regularExpression) {
            let dayName = String(text[match]).replacingOccurrences(of: "on ", with: "")
            startDate = nextWeekday(dayName)
        }

        // Extract time
        var hour = 6
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
        let markers = ["tomorrow", "today", "next ", "on monday", "on tuesday", "on wednesday", "on thursday", "on friday", "on saturday", "on sunday", "on mon", "on tue", "on wed", "on thu", "on fri", "on sat", "on sun", "at ", "for ", "in "]
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

    func parseReminderInput(_ input: String) -> ParsedReminder? {
        var text = input.lowercased()

        // Remove reminder prefix variants if present
        let reminderPrefixes = [
            "remind me to ",
            "remind me ",
            "remind ",
            "reminder ",
            "rem: ",
            "rem "
        ]

        for prefix in reminderPrefixes {
            if text.hasPrefix(prefix) {
                text = String(text.dropFirst(prefix.count))
                break
            }
        }

        var dueDate: Date?

        // Parse relative dates (similar to event parsing)
        if text.contains("tomorrow") {
            dueDate = calendar.date(byAdding: .day, value: 1, to: Date())
        } else if text.contains("today") {
            dueDate = Date()
        } else if let match = text.range(of: #"in (\d+) day"#, options: .regularExpression) {
            let matchText = String(text[match])
            if let days = extractNumber(from: matchText) {
                dueDate = calendar.date(byAdding: .day, value: days, to: Date())
            }
        } else if let match = text.range(of: #"next (monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)"#, options: .regularExpression) {
            let dayName = String(text[match]).replacingOccurrences(of: "next ", with: "")
            dueDate = nextWeekday(dayName)
        } else if let match = text.range(of: #"on (monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)"#, options: .regularExpression) {
            let dayName = String(text[match]).replacingOccurrences(of: "on ", with: "")
            dueDate = nextWeekday(dayName)
        }

        // Extract time
        var hour = 6
        var minute = 0
        var hasTime = false

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
                hasTime = true
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
                hasTime = true
            }
        } else if let timeMatch = text.range(of: #"at (\d{1,2})"#, options: .regularExpression) {
            let timeText = String(text[timeMatch])
            if let h = extractNumber(from: timeText) {
                hour = h
                hasTime = true
            }
        }

        // Build due date with time if we found a date
        if let baseDate = dueDate, hasTime {
            dueDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: baseDate)
        } else if let baseDate = dueDate {
            // Set to 6 AM by default if no time specified
            dueDate = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: baseDate)
        }

        // Extract title (everything before time/date markers)
        var title = input
        // Remove reminder prefix variants from the original input
        let titlePrefixes = [
            ("remind me to ", "remind me to ".count),
            ("remind me ", "remind me ".count),
            ("remind ", "remind ".count),
            ("reminder ", "reminder ".count),
            ("rem: ", "rem: ".count),
            ("rem ", "rem ".count)
        ]

        for (prefix, count) in titlePrefixes {
            if title.lowercased().hasPrefix(prefix) {
                title = String(title.dropFirst(count))
                break
            }
        }

        let markers = ["tomorrow", "today", "next ", "on monday", "on tuesday", "on wednesday", "on thursday", "on friday", "on saturday", "on sunday", "on mon", "on tue", "on wed", "on thu", "on fri", "on sat", "on sun", "at ", "in "]
        for marker in markers {
            if let range = title.lowercased().range(of: marker) {
                title = String(title[..<range.lowerBound])
                break
            }
        }
        title = title.trimmingCharacters(in: .whitespaces)

        if title.isEmpty {
            return nil
        }

        return ParsedReminder(title: title, dueDate: dueDate, notes: nil)
    }

    private func extractNumber(from text: String) -> Int? {
        let numbers = text.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Int(numbers)
    }

    private func nextWeekday(_ dayName: String) -> Date? {
        let weekdays = ["sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
                       "thursday": 5, "friday": 6, "saturday": 7,
                       "sun": 1, "mon": 2, "tue": 3, "wed": 4,
                       "thu": 5, "fri": 6, "sat": 7]

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
