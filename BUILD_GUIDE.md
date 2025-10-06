# Build Guide

## Prerequisites

1. macOS 13.0 or later
2. Xcode 14.0 or later
3. XcodeGen

## Installation

### Install XcodeGen

```bash
brew install xcodegen
```

### Generate Xcode Project

```bash
./generate_project.sh
```

Or manually:

```bash
xcodegen generate
```

### Build the App

1. Open the project:
   ```bash
   open CalendarApp.xcodeproj
   ```

2. Select the CalendarApp scheme

3. Build and run (⌘R)

## Troubleshooting

### Calendar Access

If the app doesn't have calendar access:

1. Go to System Settings → Privacy & Security → Calendars
2. Ensure CalendarApp is checked
3. Restart the app

### Build Errors

If you encounter build errors:

1. Clean the build folder (⌘⇧K)
2. Delete DerivedData:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
3. Regenerate the project:
   ```bash
   xcodegen generate
   ```
4. Rebuild the project

## Development

### Project Structure

```
CalendarApp/
├── CalendarApp.swift          # App entry point
├── CalendarManager.swift      # EventKit integration
├── NaturalLanguageParser.swift # Natural language date parsing
├── EventIconHelper.swift      # Smart event icon categorization
├── Views/
│   ├── ContentView.swift     # Main view with toolbar and navigation
│   ├── MonthView.swift       # Month calendar view
│   ├── WeekView.swift        # Week calendar view
│   ├── MultiDayView.swift    # Work week and 3-day views
│   ├── AgendaView.swift      # Agenda list view
│   ├── NewEventSheet.swift   # Event creation dialog
│   ├── RemindersSection.swift # Reminders list
│   └── SettingsView.swift    # Settings window
├── Assets.xcassets/          # App assets
└── Info.plist               # App metadata
```

### Making Changes

1. Make your changes to the source files
2. Build and test in Xcode
3. If you add new files or change project structure, regenerate with XcodeGen:
   ```bash
   xcodegen generate
   ```
