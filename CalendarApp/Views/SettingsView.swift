import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var calendarManager: CalendarManager

    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.system(size: 24, weight: .bold))

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Calendar Access")
                    .font(.system(size: 16, weight: .semibold))

                if calendarManager.hasAccess {
                    Text("✓ Calendar access granted")
                        .foregroundColor(.green)
                } else {
                    Text("✗ Calendar access not granted")
                        .foregroundColor(.red)

                    Button("Request Access") {
                        calendarManager.requestAccess()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Spacer()
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}
