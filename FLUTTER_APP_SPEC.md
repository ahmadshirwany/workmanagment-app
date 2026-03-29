# Discipline Tracker App - Flutter Implementation Spec

Build a habit tracking mobile app with the following features:

## Core Functionalities

### 1. Habit Tracking Tab
- Display list of user-defined habits
- Each habit has a checkbox to mark as completed for today
- Show current streak count (🔥 emoji + number) next to each habit name
- Add new habit button
- Delete habit functionality
- Tap checkbox to toggle habit completion
- Save all data locally (JSON or SQLite)

### 2. Challenge Tab
- Text input for "My 30-Day Challenge" description
- Save and persist challenge text
- Display saved challenge

### 3. Reflection Tab
- Date selector (defaults to today)
- Text area for daily reflection/journal entry
- Save reflection for selected date
- Load and display reflection when date changes
- Persist reflections by date

### 4. Goals Tab
- Text area for long-term goals
- Text area for daily notes
- Save and load goals and notes
- Persist data locally

### 5. Statistics Tab
- Show 30-day statistics:
  - Days tracked
  - Overall completion rate (percentage)
  - Current streak (consecutive days)
  - Longest streak achieved
  - Per-habit completion count
- Display stats in clean, readable format

### 6. Calendar Tab
- Monthly calendar view
- Color-code days:
  - Green: High completion rate (>66%)
  - Orange: Medium completion (33-66%)
  - Red: Low completion (<33%)
  - Gray: No data
  - Yellow text: Today's date
- Show month/year navigation (previous/next month)
- Calculate completion rate per day based on habit checkboxes

### 7. Data Management Tab
- Export all data to JSON file
- Import data from JSON file
- Show last backup timestamp
- Automatic backup on each save (keep last 10 backups)
- Display success/error messages for data operations

### 8. AI Coach Tab (Google Gemini Integration)
- Three AI-powered features:

  **Daily Insight:**
  - Button to fetch personalized motivation
  - Analyze user's habit data (streak, completion rate)
  - Display 2-3 sentence encouraging message
  - Scrollable text area for response

  **Pattern Analysis:**
  - Button to analyze 30-day patterns
  - Show key patterns, strengths, areas needing attention
  - Format with emojis and bullet points
  - Display recommendations
  - Scrollable text area for long responses

  **Habit Suggestions:**
  - Text input for user's goal
  - Button to get AI suggestions
  - Suggest 3-5 new complementary habits based on current habits and goal
  - Display as numbered list with brief benefits
  - Scrollable text area for suggestions

- API key storage (secure local storage)
- Show loading indicator while AI processes
- Handle API errors gracefully

## Technical Requirements

### Data Storage
- Store habits list (array of habit names)
- Store daily habit completion (date → habits → boolean)
- Store challenge text
- Store reflections (date → text)
- Store goals and notes
- Store statistics (calculated from habit data)
- Store API key (encrypted/secure storage)
- Auto-backup system with rotation

### UI/UX Requirements
- Bottom navigation or tabbed interface for 8 tabs
- Color scheme:
  - Primary: Blue (#2196F3)
  - Success: Green (#4CAF50)
  - Danger: Red (#F44336)
  - Warning: Orange (#FF9800)
  - Accent: Purple (#9C27B0)
- Smooth scrolling for long content
- Text wrapping for AI responses
- Loading indicators for async operations
- Confirmation dialogs for destructive actions (delete habit, import data)
- Toast/snackbar messages for success/error feedback

### API Integration
- Google Gemini API integration
- HTTP requests with error handling
- API key configuration screen
- Retry logic for failed requests
- Timeout handling (30 seconds)

### Permissions (Android)
- Storage access for data export/import
- Internet access for AI features

### App Behavior
- All data persists between sessions
- Data loads on app startup
- Auto-save on every change
- Streak calculation based on consecutive days with all habits completed
- Statistics recalculate dynamically
- Calendar updates when habits change
- Handle edge cases (no habits, no data, API failures)

## Data Structure Examples

```json
{
  "habits": ["Exercise", "Read", "Meditate", "Drink Water"],
  "habit_data": {
    "2026-01-22": {
      "Exercise": true,
      "Read": true,
      "Meditate": false,
      "Drink Water": true
    }
  },
  "challenge": "Complete all habits for 30 days",
  "reflections": {
    "2026-01-22": "Had a productive day..."
  },
  "goals": "Improve health and focus",
  "daily_notes": "Remember to drink water"
}
```

## Expected Deliverables

1. Complete Flutter app with all 8 tabs functional
2. Local data persistence (SharedPreferences + JSON or SQLite)
3. Google Gemini API integration
4. Responsive UI that works on various screen sizes
5. Error handling for all operations
6. Clean, maintainable code structure
7. Android APK ready for testing

Build this as a production-ready Flutter app with clean architecture, proper state management (Provider/Riverpod/Bloc), and following Flutter best practices.
