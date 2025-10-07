import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var calendarManager: CalendarManager

    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.system(size: 24, weight: .bold))

            Divider()

            VStack(alignment: .leading, spacing: 20) {
                // Calendar Access
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

                Divider()

                // Font Size
                VStack(alignment: .leading, spacing: 12) {
                    Text("Font Size")
                        .font(.system(size: 16, weight: .semibold))

                    Picker("", selection: $calendarManager.fontSize) {
                        ForEach(FontSize.allCases, id: \.self) { size in
                            Text(size.rawValue).tag(size)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()

                    Text("Changes font size throughout the app")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Divider()

                // Temperature Unit
                VStack(alignment: .leading, spacing: 12) {
                    Text("Temperature Unit")
                        .font(.system(size: 16, weight: .semibold))

                    Picker("", selection: $calendarManager.temperatureUnit) {
                        ForEach(TemperatureUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()

                    Text("Temperature display in weather forecasts")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .frame(width: 450, height: 400)
    }
}
