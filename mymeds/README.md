# MyMeds - Firebase Authentication & Firestore Setup

This Flutter application uses Firebase Authentication for user management and Cloud Firestore for storing user data. This README explains how Firebase was integrated and how to configure it properly.

## Firebase Services Used

1. **Firebase Authentication**: For user registration and login with email/password
2. **Cloud Firestore**: For storing user profile data

## Dependencies Added

The following Firebase dependencies were added to `pubspec.yaml`:

```yaml
dependencies:
  firebase_core: ^4.1.1
  firebase_auth: ^6.1.0
  cloud_firestore: ^5.4.2
```

## Project Structure

### Authentication Service
- **File**: `lib/services/auth_service.dart`
- **Purpose**: Centralized service for all Firebase Authentication and Firestore operations
- **Key Methods**:
  - `registerWithEmailAndPassword()`: Creates new user accounts
  - `signInWithEmailAndPassword()`: Authenticates existing users
  - `signOut()`: Signs out current user
  - `getUserData()`: Retrieves user data from Firestore

### UI Screens
- **Login Screen**: `lib/ui/auth/login_screen.dart`
- **Registration Screen**: `lib/ui/auth/register_screen.dart`

## Firebase Console Configuration

To properly set up Firebase for this project, follow these steps:

### 1. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project" or select existing project
3. Follow the setup wizard

### 2. Enable Authentication

1. In your Firebase project, go to **Authentication** > **Sign-in method**
2. Click on **Email/Password**
3. Enable **Email/Password** sign-in method
4. Save the changes

### 3. Create Firestore Database

1. Go to **Firestore Database** in the Firebase Console
2. Click **Create database**
3. Choose **Start in test mode** for development (you can configure security rules later)
4. Select your preferred location
5. Click **Done**

### 4. Set Up Firestore Security Rules

For development, you can use these basic security rules. **Note**: These are permissive rules for development only.

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read and write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

For production, implement more restrictive rules based on your app's requirements.

### 5. Add Firebase Configuration Files

#### For Android:
1. In Firebase Console, go to **Project Settings** > **General**
2. Click **Add app** and select **Android**
3. Enter your Android package name (found in `android/app/build.gradle`)
4. Download the `google-services.json` file
5. Place it in `android/app/` directory

#### For iOS:
1. In Firebase Console, click **Add app** and select **iOS**
2. Enter your iOS bundle ID (found in `ios/Runner.xcodeproj/project.pbxproj`)
3. Download the `GoogleService-Info.plist` file
4. Add it to your iOS project in Xcode

#### For Web:
1. In Firebase Console, click **Add app** and select **Web**
2. Register your app and copy the configuration
3. Update `web/index.html` with the Firebase SDK configuration

## User Data Structure

When a user registers, the following data is stored in Firestore under the `users` collection:

```javascript
{
  "uid": "user_firebase_uid",
  "fullName": "User's full name",
  "email": "user@example.com",
  "phoneNumber": "user's phone number",
  "address": "user's address",
  "city": "user's city",
  "department": "user's department/state",
  "zipCode": "user's ZIP code",
  "createdAt": "timestamp"
}
```

## Authentication Flow

### Registration Process
1. User fills registration form
2. Validates email format and password length (minimum 6 characters)
3. Creates Firebase Authentication account
4. Creates corresponding Firestore document with user data
5. Redirects to login screen on success

### Login Process
1. User enters email and password
2. Validates form inputs
3. Authenticates with Firebase
4. Redirects to home screen on success
5. Shows error message on failure

## Error Handling

The app includes comprehensive error handling for common Firebase Authentication errors:

- **weak-password**: Password is too weak
- **email-already-in-use**: Email is already registered
- **invalid-email**: Email format is invalid
- **user-not-found**: No user found with this email
- **wrong-password**: Incorrect password
- **too-many-requests**: Too many failed login attempts

All error messages are displayed in Spanish to match the app's language.

## Development Setup

1. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

2. **Configure Firebase** (follow steps above)

3. **Run the App**:
   ```bash
   flutter run
   ```

## Production Considerations

Before deploying to production:

1. **Update Firestore Security Rules**: Implement proper security rules based on your app's requirements
2. **Enable App Check**: Add additional security layer to protect your Firebase resources
3. **Configure Authentication Settings**: Set up password policies, email verification, etc.
4. **Set up Analytics**: Configure Firebase Analytics for user behavior tracking
5. **Implement Proper Error Logging**: Use Firebase Crashlytics for error tracking

## Testing

You can test the authentication flow by:

1. Running the app
2. Creating a new account through the registration screen
3. Checking the Firebase Console to verify:
   - User appears in Authentication > Users
   - User document is created in Firestore > users collection
4. Logging out and logging back in with the created credentials

## Troubleshooting

### Common Issues

1. **"Target of URI doesn't exist" errors**: Run `flutter pub get` to install dependencies
2. **Build errors on Android**: Make sure `google-services.json` is in the correct location
3. **Build errors on iOS**: Ensure `GoogleService-Info.plist` is properly added to the Xcode project
4. **Authentication errors**: Check Firebase Console Authentication settings and network connectivity

### Firebase Console Debugging

- Check **Authentication > Users** to see registered users
- Check **Firestore Database** to verify user documents are being created
- Monitor **Usage** tab for API calls and errors

## Support

For Firebase-specific issues, refer to:
- [Firebase Documentation](https://firebase.google.com/docs)
- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [Firebase Support](https://firebase.google.com/support)
