# Discipline Tracker - Flutter App

A comprehensive habit tracking mobile app with AI coaching powered by Google Gemini.

## Features

- **Habit Tracking**: Track daily habits with streak counters
- **30-Day Challenge**: Set and track your personal challenge
- **Daily Reflection**: Journal your thoughts and progress
- **Goals & Notes**: Manage long-term goals and daily notes
- **Statistics**: View detailed analytics of your progress
- **Calendar View**: Visual representation of your habit completion
- **Data Management**: Export/import data with automatic backups
- **AI Coach**: Get personalized insights and suggestions using Google Gemini AI

## Setup

1. Install Flutter SDK (3.0.0 or higher)
2. Clone this repository
3. Run `flutter pub get` to install dependencies
4. Configure your Google Gemini API key in the app
5. Run `flutter run` to launch the app

## Building for Android

```bash
flutter build apk --release
```

The APK will be available at `build/app/outputs/flutter-apk/app-release.apk`

## API Key

To use AI features, you need a Google Gemini API key:
1. Visit https://makersuite.google.com/app/apikey
2. Create an API key
3. Configure it in the AI Coach tab of the app

## Dependencies

- provider: State management
- shared_preferences: Local storage
- http: API calls
- intl: Date formatting
- path_provider: File system access
- table_calendar: Calendar widget
- flutter_secure_storage: Secure API key storage

## License

MIT License
