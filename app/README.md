# app2

Word Friend

## Getting Started

### Android emulator + Google sign-in

This app uses Google Sign-In to obtain a Google `idToken`, then exchanges it with the backend at `POST /auth/google`.

This repo includes an IDE run configuration plus a defines file at `tool/dart_defines.android_emulator.json`.

1. Edit `tool/dart_defines.android_emulator.json` and set `GOOGLE_SERVER_CLIENT_ID` to your OAuth **Web application** client id.
1. In Android Studio, run the `Android Emulator` configuration.

If you prefer the CLI, you can still run:

```bash
flutter run --dart-define-from-file=tool/dart_defines.android_emulator.json
```

Notes:

1. `API_BASE_URL` must use `10.0.2.2` (emulator access to your host machine).

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
