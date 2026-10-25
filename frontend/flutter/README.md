# MAKCO Flutter app

Chennai Metro booking client built with Flutter, Riverpod 3 and go_router.
"Madras Flow" design system lives in `lib/theme/`.

## Run

```bash
flutter pub get
flutter run --dart-define=API_BASE=http://127.0.0.1:8080
```

## Verify

```bash
flutter analyze
flutter test
flutter build apk --release
```

Release APK: `build/app/outputs/flutter-apk/app-release.apk`.

## Local data

- Session token/user id: `flutter_secure_storage`.
- Offline cache: `lib/services/cache.dart`.
- Favourites: `lib/state/favourites.dart`.
- Fonts: `assets/fonts/` (Bricolage Grotesque, Public Sans; OFL licenses).
