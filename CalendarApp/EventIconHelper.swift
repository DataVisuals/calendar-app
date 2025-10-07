import Foundation
import EventKit

struct EventIconHelper {
    static func icon(for event: EKEvent) -> String {
        let title = (event.title ?? "").lowercased()
        let location = (event.location ?? "").lowercased()
        let notes = (event.notes ?? "").lowercased()
        let combined = "\(title) \(location) \(notes)"

        // Halloween
        if combined.contains("halloween") {
            return "theatermasks.fill"
        }

        // Diwali
        if combined.contains("diwali") {
            return "candle.fill"
        }

        // Guy Fawkes / Bonfire Night
        if combined.contains("guy fawkes") || combined.contains("bonfire night") || combined.contains("bonfire") {
            return "flame.fill"
        }

        // Guitar / Music Practice
        if combined.contains("guitar") {
            return "guitars.fill"
        }

        // Birthday
        if combined.contains("birthday") || combined.contains("bday") || combined.contains("b-day") {
            return "gift.fill"
        }

        // Hotel/Accommodation
        if combined.contains("hotel") || combined.contains("accommodation") || combined.contains("stay") ||
           combined.contains("airbnb") || combined.contains("hostel") {
            return "bed.double.fill"
        }

        // Flight/Travel
        if combined.contains("flight") || combined.contains("plane") || combined.contains("airport") ||
           combined.contains("airline") {
            return "airplane"
        }

        // Dining/Food
        if combined.contains("dinner") || combined.contains("lunch") || combined.contains("breakfast") ||
           combined.contains("restaurant") || combined.contains("cafe") || combined.contains("brunch") ||
           combined.contains("meal") {
            return "fork.knife"
        }

        // Fitness/Exercise
        if combined.contains("run") || combined.contains("jog") || combined.contains("gym") ||
           combined.contains("workout") || combined.contains("exercise") || combined.contains("yoga") ||
           combined.contains("fitness") || combined.contains("training") {
            return "figure.run"
        }

        // Medical
        if combined.contains("doctor") || combined.contains("dentist") || combined.contains("appointment") ||
           combined.contains("medical") || combined.contains("hospital") || combined.contains("clinic") {
            return "cross.case.fill"
        }

        // Meeting/Conference
        if combined.contains("meeting") || combined.contains("conference") || combined.contains("call") ||
           combined.contains("zoom") || combined.contains("teams") {
            return "person.2.fill"
        }

        // Education/Class
        if combined.contains("class") || combined.contains("lecture") || combined.contains("course") ||
           combined.contains("lesson") || combined.contains("training") || combined.contains("workshop") {
            return "book.fill"
        }

        // Work/Office
        if combined.contains("work") || combined.contains("office") || combined.contains("project") {
            return "briefcase.fill"
        }

        // Social/Party
        if combined.contains("party") || combined.contains("celebration") || combined.contains("event") {
            return "party.popper.fill"
        }

        // Music/Concert
        if combined.contains("concert") || combined.contains("music") || combined.contains("show") {
            return "music.note"
        }

        // Shopping
        if combined.contains("shopping") || combined.contains("shop") || combined.contains("buy") {
            return "cart.fill"
        }

        // Home/House
        if combined.contains("home") || combined.contains("house") || combined.contains("cleaning") {
            return "house.fill"
        }

        // Car/Vehicle
        if combined.contains("car") || combined.contains("drive") || combined.contains("vehicle") ||
           combined.contains("garage") {
            return "car.fill"
        }

        // Default calendar icon
        return "calendar"
    }
}
