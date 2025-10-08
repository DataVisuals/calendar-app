import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Text("Settings")
                .font(.system(size: 24, weight: .bold))
                .padding(.top, 20)
                .padding(.bottom, 16)

            Divider()

            ScrollView {
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

                Divider()

                // Visible Calendars
                VStack(alignment: .leading, spacing: 12) {
                    Text("Visible Calendars")
                        .font(.system(size: 16, weight: .semibold))

                    if calendarManager.hasAccess && !calendarManager.calendars.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(calendarManager.calendars, id: \.calendarIdentifier) { calendar in
                                HStack(spacing: 10) {
                                    Toggle(isOn: Binding(
                                        get: { calendarManager.selectedCalendarIDs.contains(calendar.calendarIdentifier) },
                                        set: { _ in calendarManager.toggleCalendar(calendar.calendarIdentifier) }
                                    )) {
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(calendarManager.color(for: calendar, colorScheme: colorScheme))
                                                .frame(width: 12, height: 12)

                                            Text(calendar.title)
                                                .font(.system(size: 13))
                                        }
                                    }
                                    .toggleStyle(.checkbox)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(.leading, 4)

                        Text("Select which calendars to display")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    } else {
                        Text("No calendars available")
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // Default Calendar
                VStack(alignment: .leading, spacing: 12) {
                    Text("Default Calendar")
                        .font(.system(size: 16, weight: .semibold))

                    if calendarManager.hasAccess && !calendarManager.calendars.isEmpty {
                        Menu {
                            Button("System Default") {
                                calendarManager.defaultCalendar = nil
                            }
                            ForEach(calendarManager.calendars, id: \.calendarIdentifier) { calendar in
                                Button(calendar.title) {
                                    calendarManager.defaultCalendar = calendar
                                }
                            }
                        } label: {
                            HStack {
                                Text(calendarManager.defaultCalendar?.title ?? "System Default")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(NSColor.controlBackgroundColor))
                            )
                        }
                        .buttonStyle(.plain)

                        Text("Calendar for quick add events")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    } else {
                        Text("No calendars available")
                            .foregroundColor(.secondary)
                    }
                }
                }
                .padding()
            }
        }
        .frame(width: 450)
        .frame(minHeight: 500, maxHeight: 700)
    }
}

import EventKit
