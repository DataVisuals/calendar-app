import SwiftUI

struct WeatherSection: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @ObservedObject var weatherManager: WeatherManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "cloud.sun.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 18 * calendarManager.fontSize.scale))
                Text("Weather Forecast")
                    .font(.system(size: 18 * calendarManager.fontSize.scale, weight: .semibold))
                Spacer()
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if weatherManager.dailyForecasts.isEmpty {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading weather...")
                        .font(.system(size: 13 * calendarManager.fontSize.scale))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(weatherManager.dailyForecasts) { forecast in
                            WeatherDayCard(forecast: forecast)
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

struct WeatherDayCard: View {
    @EnvironmentObject var calendarManager: CalendarManager
    let forecast: DailyWeatherInfo

    var body: some View {
        VStack(spacing: 8) {
            Text(dayOfWeek)
                .font(.system(size: 13 * calendarManager.fontSize.scale, weight: .medium))
                .foregroundColor(.secondary)

            Image(systemName: forecast.symbolName)
                .font(.system(size: 28 * calendarManager.fontSize.scale))
                .foregroundColor(.blue)
                .frame(height: 32)

            VStack(spacing: 2) {
                Text(formattedTemp(forecast.highTemp))
                    .font(.system(size: 16 * calendarManager.fontSize.scale, weight: .semibold))

                Text(formattedTemp(forecast.lowTemp))
                    .font(.system(size: 13 * calendarManager.fontSize.scale))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(width: 80)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
    }

    private var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: forecast.date)
    }

    private func formattedTemp(_ temp: Double) -> String {
        let converted = calendarManager.temperatureUnit.convert(temp)
        return "\(Int(converted))\(calendarManager.temperatureUnit.symbol)"
    }
}
