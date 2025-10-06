# Calendar App

A native macOS calendar application built with SwiftUI that integrates with Apple Calendar.

## Features

- **Multiple Calendar Views**: Month, Week, Work Week, 3-Day, and Agenda views
- **Color-Coded Events**: Events are color-coded by their calendar source
- **Natural Language Event Creation**: Create events using phrases like "Dentist appointment next saturday at 3pm for 2 hours"
- **Smart Event Icons**: Automatically categorizes events and displays relevant icons (birthdays, flights, meetings, etc.)
- **Reminders Integration**: View and manage incomplete reminders grouped by list
- **Quick Search**: Press `/` to search for events by title, location, or notes
- **Keyboard Shortcuts**:
  - ⌘1-5: Switch between calendar views
  - ⌘N: Create new event
  - /: Quick search
- **Enhanced Weekend Styling**: Weekends are visually distinct with accent colors
- **Text Wrapping**: Event titles wrap in month view where space permits

## Requirements

- macOS 13.0 or later
- Xcode 14.0 or later
- XcodeGen (for project generation)

## Setup

1. Install XcodeGen:
   ```bash
   brew install xcodegen
   ```

2. Generate the Xcode project:
   ```bash
   ./generate_project.sh
   ```

3. Open the generated project:
   ```bash
   open CalendarApp.xcodeproj
   ```

4. Build and run the app (⌘R)

5. Grant calendar access when prompted

## Usage

### Creating Events

**Using Natural Language:**
1. Click "New Event" or press ⌘N
2. Enter a phrase like:
   - "tomorrow at 2pm"
   - "next friday at 10am for 1 hour"
   - "Dentist appointment next saturday at 3pm for 2 hours"
3. Click "Parse" to fill in the event details
4. Click "Save" or press ⌘↩

**Manual Entry:**
1. Click "New Event" or press ⌘N
2. Fill in the event details manually
3. Click "Save" or press ⌘↩

### Searching Events

1. Press `/` to open the search overlay
2. Type to search event titles, locations, and notes
3. The calendar will navigate to the first matching event
4. Press ESC or click outside to close

### Switching Views

- Press ⌘1 for Month view
- Press ⌘2 for Week view
- Press ⌘3 for Work Week view
- Press ⌘4 for 3-Day view
- Press ⌘5 for Agenda view

Or click the view selector buttons in the toolbar.

## License

MIT License
