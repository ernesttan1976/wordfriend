# app2

Word Friend

## Getting Started

### Android emulator + Google sign-in

This app uses Google Sign-In to obtain a Google `idToken`, then exchanges it with the backend at `POST /auth/google`.

Run the app on an Android emulator with:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:4000 \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_OAUTH_CLIENT_ID.apps.googleusercontent.com
```

Notes:

1. `API_BASE_URL` must use `10.0.2.2` (emulator access to your host machine).
1. `GOOGLE_SERVER_CLIENT_ID` must be the OAuth **Web application** client id from Google Cloud Console.

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
