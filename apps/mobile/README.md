# CV ATS — Flutter Android app (first implementation)

This is the initial source-level UI shell following the established Figma design direction (blue, white, cyan, accessible spacing).

## Implemented
- Material 3 theme and responsive max-width page shell
- Landing screen with ATS and Job Match explained separately
- New Analysis screen with job-title and job-description inputs
- Widget test for landing -> new analysis navigation

## Not yet implemented
File picker and upload, Supabase login, authenticated dashboard, history, live analysis, Gemini and PDF export. The Analyze button is intentionally disabled until real backend integration is ready. Screens do **not** represent completed analysis.

## Requirements
Flutter stable, Android SDK/Android Studio, supported Java toolchain. Run `flutter doctor` and fix reported issues.

## Start locally

```sh
cd apps/mobile
flutter create --platforms=android .
flutter pub get
flutter test
flutter run
```

Review changes made by `flutter create` before committing generated files. Pin and commit `pubspec.lock` once dependencies are resolved.

No Gemini API keys or privileged Supabase secrets should be included in the Flutter application.
