# CV ATS Flutter — Android-first product UI

The mobile app now has a shared Material 3 design system and responsive screen coverage. **Flutter code is the implementation source of truth**, not the original Figma layout.

## Implemented in Flutter source

- Refined visitor landing and first-analysis form with real PDF/DOCX/image picker
- Sign in, registration, confirmation-email messaging and password recovery request
- Adaptive five-destination candidate workspace: dashboard, analyze, history, CV library, account
- Four result tabs: Overview, ATS breakdown, Job Match evidence, recommendations
- Real Supabase-backed dashboard/history/CV metadata queries, error/loading/empty states
- Free/Premium plan comparison, account settings, live light/dark theme, FAQs and privacy notice
- Protected administrator screen shells for Overview, Users, Plans & Limits and Statistics

Unimplemented operations (payment, account deletion, candidate detail editing, public visitor claim, admin APIs) are visibly labeled as pending rather than simulated.

The complete inventory and acceptance criteria are in [Flutter Screen & Workflow Map](../../docs/product/flutter-screen-and-workflow-map.md).

## Configure and run

Requirements: Flutter stable SDK, Android Studio/Android SDK, Java 17 and an Android emulator/device. Run `flutter doctor`.

```sh
cd apps/mobile
flutter create --platforms=android --project-name cv_ats_mobile .
flutter pub get
flutter analyze
flutter test
flutter run \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLIC_SUPABASE_KEY \
  --dart-define=CV_ATS_API_URL=https://YOUR_PUBLIC_API_HOST
```

`SUPABASE_URL` defaults to the public CV ATS project URL. Set it explicitly with another `--dart-define` when testing a different environment.

The app has a protective **analysis execution feature gate**. Only after deploying/validating the separate worker and end-to-end tests, add:

```sh
--dart-define=CV_ATS_ANALYSIS_ENABLED=true
```

The gate does **not** replace backend quotas, authorization or security checks.

The API must be reachable from the Android device without a Vercel Authentication browser login challenge. Configure a stable HTTPS API hostname and retain Supabase JWT validation and RLS.

Android platform files and `pubspec.lock` are not yet committed. The GitHub Actions workflow `flutter-android.yml` generates Android platform scaffolding for CI and attempts analysis, tests and a debug APK. Verify its run status before claiming a passing Android build.

## Design and security principles

- Accessible tap targets, screen-reader labels, dark and light contrast, clear loading/empty/error states and responsive layouts.
- No fabricated user results or recruiter success claims; scores only after completed jobs.
- No service-role, Gemini, database or other private credentials in Flutter.
- Never use real candidate documents with AI until consent/data-processing terms are reviewed.
- The anonymous visitor-before-registration workflow remains planned and is not the same as current guest exploration.
