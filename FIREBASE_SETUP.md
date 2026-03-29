# Firebase Setup Guide for Cloud Sync

This guide will help you set up Firebase for the Cloud Sync & Backup feature.

## Prerequisites

- A Google account
- Firebase CLI (optional but recommended)

## Step 1: Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project" or "Add project"
3. Enter a project name (e.g., "Discipline Tracker")
4. Enable/disable Google Analytics as preferred
5. Click "Create project"

## Step 2: Enable Authentication

1. In your Firebase project, go to **Build > Authentication**
2. Click "Get started"
3. Go to the **Sign-in method** tab
4. Enable **Google** as a sign-in provider
5. Configure the OAuth consent screen if prompted
6. Save the changes

## Step 3: Set Up Firestore Database

1. In your Firebase project, go to **Build > Firestore Database**
2. Click "Create database"
3. Choose **Start in production mode** (recommended) or test mode
4. Select a Cloud Firestore location closest to your users
5. Click "Enable"

### Set Up Security Rules

Go to **Firestore Database > Rules** and add these rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

Click "Publish" to apply the rules.

## Step 4: Configure Android App

### 4.1 Register Android App

1. In Firebase Console, click the gear icon > **Project settings**
2. Under "Your apps", click **Add app** > **Android**
3. Enter the package name: `com.example.discipline_tracker` (or your actual package name from `android/app/build.gradle`)
4. Enter app nickname (optional)
5. Enter SHA-1 certificate (required for Google Sign-In):

   ```powershell
   # Run this in your project's android folder:
   cd android
   ./gradlew signingReport
   ```
   
   Copy the SHA-1 from the output.

6. Click "Register app"

### 4.2 Download Configuration File

1. Download the `google-services.json` file
2. Move it to `android/app/google-services.json`

### 4.3 Update Android Build Files

**android/build.gradle** - Add Google services classpath:

```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

**android/app/build.gradle** - Apply Google services plugin:

```gradle
plugins {
    id 'com.android.application'
    id 'kotlin-android'
    id 'com.google.gms.google-services'  // Add this line
}
```

## Step 5: Configure Windows App (Optional)

For Windows, you need to use FlutterFire CLI:

1. Install Firebase CLI:
   ```powershell
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```powershell
   firebase login
   ```

3. Install FlutterFire CLI:
   ```powershell
   dart pub global activate flutterfire_cli
   ```

4. Configure your app:
   ```powershell
   flutterfire configure
   ```

5. This will generate `lib/firebase_options.dart`

6. Update `lib/main.dart`:
   ```dart
   import 'firebase_options.dart';
   
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await Firebase.initializeApp(
       options: DefaultFirebaseOptions.currentPlatform,
     );
     // ...
   }
   ```

## Step 6: Test the Setup

1. Run the app:
   ```powershell
   flutter run
   ```

2. Go to **Data Management** screen
3. Tap "Sign in with Google"
4. Sign in with your Google account
5. Try uploading and downloading data

## Troubleshooting

### Google Sign-In Not Working

1. **Check SHA-1**: Make sure you added the correct SHA-1 certificate in Firebase Console
2. **Check Package Name**: Ensure the package name in Firebase matches your app
3. **OAuth Consent Screen**: Make sure it's configured in Google Cloud Console

### Firebase Initialization Failed

1. **Check google-services.json**: Ensure it's in the correct location
2. **Check Gradle Config**: Ensure Google services plugin is applied correctly
3. **Clean Build**: Run `flutter clean` and rebuild

### Firestore Permission Denied

1. **Check Rules**: Ensure security rules allow authenticated users to access their data
2. **Check Auth**: Make sure the user is properly authenticated before accessing Firestore

## Data Structure

Your data is stored in Firestore with this structure:

```
users/
  {userId}/
    app_data/
      data/
        - habits: [...]
        - dailyTasks: [...]
        - goals: [...]
        - workSessions: [...]
        - lastModified: timestamp
```

Each user's data is isolated and can only be accessed by that user.

## Privacy & Security

- All data is encrypted in transit (HTTPS)
- Data is stored in Google's secure infrastructure
- Users can only access their own data
- You can delete all cloud data by signing out and requesting data deletion

## Support

If you encounter issues:
1. Check Firebase Console for error logs
2. Run `flutter doctor` to check your Flutter setup
3. Check the app's debug console for error messages
