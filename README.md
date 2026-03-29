# Discipline Tracker - Flutter App

Discipline Tracker is a Flutter productivity app for building consistent routines.
It combines daily habit/task tracking, focused work-session logging, reflection, analytics, reminders, data backup/sync, and an AI coach powered by Google Gemini.

## What The App Includes

The app is organized into 10 tabs:

1. **Daily Tasks**
2. **Work Time**
3. **Challenge**
4. **Reflection**
5. **Goals**
6. **Stats**
7. **Calendar**
8. **Data**
9. **AI Coach**
10. **Settings**

## Feature Breakdown

### 1) Daily Tasks (Habits + Tasks)

- Add habits with active date ranges (start/end dates).
- Mark habits complete per day.
- Automatically calculate streaks for each habit.
- Add, edit, complete, and delete daily tasks.
- Mark specific days as **Holiday/Vacation** to exclude them from streak/stat calculations.

### 2) Work Time Tracking

- Start/stop timed work sessions.
- Persist active session state safely.
- View day-based work sessions and totals.
- Track productivity duration and review recorded sessions.

### 3) Challenge

- Set and update a personal challenge goal.
- Keep challenge text saved with the rest of your progress data.

### 4) Reflection

- Write day-specific reflections/journal entries.
- Keep historical reflection notes tied to dates.

### 5) Goals

- Maintain longer-term goals and personal notes.
- Edit goals anytime with local persistence.

### 6) Statistics & Insights

- View overall completion rate and tracked-day metrics.
- See current and longest streaks.
- Habit completion counts and weekly breakdown insights.
- Daily task metrics: total tasks, completed tasks, completion rate, and average tasks per day.
- Work-time metrics: total work time, average work time per day, maximum work-session totals, and most productive day indicators.
- Consistency scoring and top-performing trend indicators.

### 7) Calendar View

- Visual calendar for activity history.
- Quickly inspect completion and tracking patterns by date.

### 8) Data Management (Local + Cloud)

- **Auto-save** app data locally using `shared_preferences`.
- **Auto-backup** JSON snapshots in app documents storage.
- Keep recent backups while cleaning older ones automatically.
- **Export** data to JSON (Downloads on Windows/Android when available).
- **Import** data from JSON with confirmation flow.
- **Google Drive cloud sync** with Google sign-in, upload/download JSON backup, and auto-sync/last-sync tracking.

### 9) AI Coach (Google Gemini)

- Save Gemini API key securely using `flutter_secure_storage`.
- Ask free-form coaching questions.
- Quick actions include motivation insight, weekly recap, and smart recommendations.
- Context-aware responses using your tracked habits, task stats, work-time stats, and recent reflections.

### 10) Settings & Notifications

- Enable/disable reminders.
- Configure reminder interval (preset or custom).
- Schedule local notifications with timezone-aware logic.
- Trigger test notifications.
- Receive long-work-session reminder alerts.

## Tech Highlights

- **State management**: `provider`
- **Local persistence**: `shared_preferences`
- **Secure secret storage**: `flutter_secure_storage`
- **File handling**: `path_provider`, `file_picker`
- **Calendar UI**: `table_calendar`
- **Notifications**: `flutter_local_notifications`, `timezone`
- **Cloud sync**: `google_sign_in`, `googleapis`, `extension_google_sign_in_as_googleapis_auth`
- **AI integration**: Google Gemini REST API via `http`

## Setup

1. Install Flutter SDK (`>=3.0.0 <4.0.0`).
2. Clone this repository.
3. Install packages:

```bash
flutter pub get
```

4. Run the app:

```bash
flutter run
```

5. (Optional) Open **AI Coach** and add your Gemini API key to enable AI features.

## Build For Android

```bash
flutter build apk --release
```

Generated APK path:
`build/app/outputs/flutter-apk/app-release.apk`

## Gemini API Key

To enable AI coaching:

1. Visit `https://makersuite.google.com/app/apikey`
2. Create an API key
3. Add it in the app from the **AI Coach** tab

## License

MIT License
