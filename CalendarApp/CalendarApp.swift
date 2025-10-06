import SwiftUI

@main
struct CalendarApp: App {
    @StateObject private var calendarManager = CalendarManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(calendarManager)
                .frame(minWidth: 900, minHeight: 600)
        }
        .defaultSize(width: 1200, height: 800)

        Settings {
            SettingsView()
                .environmentObject(calendarManager)
        }
    }
}
