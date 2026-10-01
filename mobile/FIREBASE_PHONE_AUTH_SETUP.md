# Firebase Phone OTP setup

The application uses Firebase only to send and verify the phone OTP. FastAPI,
MongoDB, application JWTs, password login, Google login, roles, and routes are
unchanged.

## Firebase Console

1. Create or select a Firebase project.
2. In Authentication, enable the **Phone** provider.
3. Allow India in the Authentication SMS region policy.
4. Register Android package `com.krayansh.studybook`.
5. Add the Android SHA-1 and SHA-256 fingerprints.
6. For web, register the deployed domain as an authorized domain.
7. Add Firebase test phone numbers before testing; they do not send real SMS.

## Flutter configuration

The recommended setup is:

```powershell
dart pub global activate flutterfire_cli
flutterfire configure
```

The app also supports configuration using `--dart-define`:

```powershell
flutter run -d chrome `
  --dart-define=FIREBASE_API_KEY=... `
  --dart-define=FIREBASE_APP_ID=... `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... `
  --dart-define=FIREBASE_PROJECT_ID=... `
  --dart-define=FIREBASE_AUTH_DOMAIN=...
```

## FastAPI / Render configuration

Download a Firebase Admin service-account JSON file. Store its complete JSON as
the Render secret environment variable `FIREBASE_SERVICE_ACCOUNT_JSON`. Never
commit the real service-account file or JSON.

After configuration, redeploy the backend. Flutter sends the verified Firebase
ID token to `/api/auth/mobile/firebase`, where FastAPI validates it before
issuing the application's existing access and refresh tokens.
