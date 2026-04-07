# Discipline Tracker - Flutter App

Discipline Tracker is a Flutter productivity app for building consistent routines with habits, tasks, focus-time tracking, journaling, goals, analytics, AI coaching, and gamified progress.

It includes business-day safeguards, challenge rewards, achievements, social share cards, local backup/export/import, and Google Drive sync.

## App Navigation (Current Tab Order)

The app currently has 10 main tabs:

1. **Daily Tasks**
2. **Stats**
3. **Challenge**
4. **AI Coach**
5. **Work Time**
6. **Calendar**
7. **Reflection**
8. **Goals**
9. **Data**
10. **Settings**

## Core Day Rules (Important)

The app uses a **business day** that starts at **6:00 AM local device time**.

- Before 6:00 AM, the app still treats the date as the previous day.
- After rollover, **past and future dates are read-only** for habits, tasks, and work-session edits.
- Only **Vacation/Holiday toggle** is allowed outside today, and only inside a **-7 to +7 day window**.

This protects consistency metrics and prevents accidental historical edits.

## Full Feature Breakdown

### 1) Daily Tasks (Habits + Tasks)

- Create recurring habits with active ranges (`startDate` and optional `endDate`).
- Mark habit completion per day and track streaks.
- Add, edit, complete, and delete daily tasks.
- Date navigator with lock-aware behavior and clear restriction messages.
- Toggle vacation/holiday days to exclude those days from consistency calculations.
- In-app gamification panel with level, XP, discipline score, and 7-day maintenance.
- Daily motivation card (AI-powered or local fallback) with one-tap handoff into AI Coach.
- Shareable wins entry point and achievements shortcut from the app bar.

### 2) Stats

- Time-range filters: **7 days, 30 days, 90 days, all time**.
- Overview metrics for streaks, habit completion, task completion, and work time.
- XP history/trend visibility and discipline-score context.
- Access to achievements and shareable win cards.

### 3) Challenge

- Rotating **daily** and **weekly** challenge cards with XP rewards.
- Claim workflow with completion/claimed states and confetti feedback.
- AI-generated personalized challenge suggestions.
- Save your own long-form **30-day challenge** text.
- **Privileged Mode**:
	- Fully automatic (no manual on/off switch).
	- Uses **habit completion** (not task completion).
	- Turns ON only when **both** are on track:
		- today habit progress, and
		- rolling last 7 days habit progress.
	- Customizable daily and last-7-days habit targets.
	- Customizable list of allowed activities when mode is ON.
	- Visual state card with gradient styling (green ON, red OFF).
- Shareable wins entry point from Challenge tab.

### 4) AI Coach (Google Gemini)

- Secure Gemini API key storage via `flutter_secure_storage`.
- Context-aware chat using your streaks, habits, tasks, work-time, and reflections.
- Persistent conversation history with:
	- new conversation,
	- restore history,
	- clear all history.
- Quick actions such as pep talk, focus suggestions, and dynamic weakest-habit coaching.
- Voice-to-text input using speech recognition.
- Daily motivation context integration from Daily Tasks.

### 5) Work Time

- Start/stop live focus sessions.
- Resume active session safely after app restart.
- Edit active-session start time.
- Add/edit manual sessions with validation.
- Daily totals and per-session history.
- 45-minute work alert dialog and optional local notification support.
- Business-day edit locks are enforced for session modifications.

### 6) Calendar

- Color-coded completion heatmap for historical days.
- Legend for high/medium/low/no-data completion.
- Selected-day detail panel with completion rate and habit status snapshot.

### 7) Reflection

- Daily journal with date navigation.
- Save/edit reflection entries per date.
- Historical review by selecting past dates.

### 8) Goals

- Long-term goals editor.
- Separate daily notes area.
- Persistent save for both goals and notes.

### 9) Data (Local + Cloud)

Local data features:

- Auto-save on data changes.
- Automatic JSON backup snapshots in app documents storage.
- Backup cleanup policy to keep only recent backups (max 10).
- Export JSON to Downloads (when available).
- Import JSON with replace confirmation flow.

Cloud data features:

- Google sign-in and Google Drive backup upload/download.
- Auto-sync toggle and last-sync status.
- Mobile-first cloud sync flow (Windows/Linux show availability guidance).

### 10) Settings & Notifications

- Enable/disable reminders.
- Set reminder intervals using presets or custom minutes.
- Test notification action.
- View scheduled notifications and reset notification schedule.
- Android guidance for battery optimization and permissions.
- One-tap **Reset All Data** (with confirmation).

## Gamification System (Across the App)

- XP sources include:
	- habit completions,
	- daily task completions,
	- focused work chunks,
	- challenge reward claims.
- Level progression and XP-to-next-level progress.
- Discipline score derived from streak, completion, and work components.
- 7-day maintenance tracking and momentum trend indicators.
- Achievement system with unlock progress and badge gallery.
- Maintenance mechanics include low-activity decay limits and recovery bonuses.

## Shareable Wins

The app can generate social-ready PNG cards and open the native share sheet.

Share card types:

- Streak Win
- Level Up
- Discipline Score
- Weekly Report

## Tech Highlights

- **State management**: `provider`
- **Local persistence**: `shared_preferences`
- **Secure secret storage**: `flutter_secure_storage`
- **AI integration**: Google Gemini REST API via `http`
- **Charts and gamification UI**: `fl_chart`, `confetti`, `flutter_svg`
- **Shareable cards**: `screenshot`, `image`, `share_plus`
- **Voice input**: `speech_to_text`
- **File handling**: `path_provider`, `file_picker`
- **Calendar UI**: `table_calendar`
- **Notifications**: `flutter_local_notifications`, `timezone`
- **Cloud sync**: `google_sign_in`, `googleapis`, `extension_google_sign_in_as_googleapis_auth`

## Setup

1. Install Flutter SDK (`>=3.0.0 <4.0.0`).
2. Clone this repository.
3. Install dependencies:

```bash
flutter pub get
```

4. Run the app:

```bash
flutter run
```

For Windows desktop explicitly:

```bash
flutter run -d windows
```

5. (Optional) Open **AI Coach** and add your Gemini API key.

## Build (Android Release)

```bash
flutter build apk --release
```

Generated APK:

`build/app/outputs/flutter-apk/app-release.apk`

## Gemini API Key

To enable AI coaching:

1. Go to `https://makersuite.google.com/app/apikey`
2. Create an API key
3. Add it inside the app from the **AI Coach** tab

## License

MIT License
