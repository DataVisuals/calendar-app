import SwiftUI

@main
struct CalendarApp: App {
    @StateObject private var calendarManager = CalendarManager()
    @StateObject private var weatherManager = WeatherManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(calendarManager)
                .environmentObject(weatherManager)
                .frame(minWidth: 900, minHeight: 600)
        }
        .defaultSize(width: 1200, height: 800)

        Settings {
            SettingsView()
                .environmentObject(calendarManager)
        }
    }
}
