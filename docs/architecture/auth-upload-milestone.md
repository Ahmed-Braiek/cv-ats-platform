# Authentication and private CV upload — milestone 2

## Applied database changes

Supabase project: `uqtyxhkevnyjvhwdgkyh` (EU West 1).

A migration named `cv_ats_auth_profile_and_private_uploads` has been applied using the connected Supabase integration.

- New `auth.users` rows invoke `public.cv_ats_on_auth_user_created`.
- The function creates a `public.profiles` row with trusted role `candidate`, and a Free subscription by looking up `subscription_plans.code='free'`.
- The function has a fixed empty search path and references database objects with qualified names. It is a security-definer auth trigger; it is not intended to be called by application clients.
- Existing auth users were backfilled into profiles and assigned a Free subscription if needed.
- The private `cv-private` bucket now supports authenticated INSERT, SELECT, DELETE for objects whose first path folder equals the signed-in user ID. UPDATE / upsert is not granted.
- Authenticated users can INSERT CV metadata only when the path is under their own UUID and an object already exists in `cv-private`. Existing owner-only SELECT RLS remains.
- Confirmed: signup trigger and 3 storage object policies exist; Supabase security advisor returned no lint findings.

## Flutter application flow

1. Visitor opens the landing and New Analysis screens without signing in.
2. Tapping the upload card requests sign in / registration. Supabase Auth handles email/password and email verification according to project settings.
3. The file picker accepts PDF, DOCX, PNG or JPG/JPEG up to 10 MiB.
4. Flutter validates basic magic bytes (a helpful client check, **not** a security boundary).
5. The client generates an opaque filename under `<auth-user-uuid>/<random-uuid>.<ext>`.
6. It uploads bytes into the private `cv-private` bucket using the authenticated user's JWT and upsert disabled.
7. It registers metadata in `public.cvs`, whose RLS verifies user ownership and the existing storage object.
8. If metadata insert fails, the client attempts to remove the uploaded object.

## Current limits and next engineering requirements

- This milestone is **authenticated upload only**. The visitor-first *pre-signup analysis* flow is not yet implemented. The visitor can explore the screens before authentication but cannot submit a document anonymously.
- Text fields for a job description are not yet persisted. There is no analysis worker or Gemini integration yet.
- Client magic-byte checks are not sufficient for production; the NestJS API/worker must perform server-side MIME, archive integrity and size validation, malware-risk assessment, rate limiting and file lifecycle enforcement.
- Supabase Auth email confirmation must be tested using a real development account (do not disable it simply to make a demo easier).
- Configure the mobile app with a **publishable** Supabase key only. Never embed privileged Supabase secrets or Gemini keys in Dart code.
- All Flutter dependencies and Android platform files must be installed/generated and committed with a verified lockfile. Flutter SDK is unavailable in the current execution environment; **no Android build or widget-test pass is claimed**.
- Add two-user RLS negative tests and end-to-end upload tests before using real personal CVs.
- On release, backend-side cleanup must detect and remove orphaned objects and enforce retention/deletion.
- Dedicated Vercel API deployment and production-grade Gemini worker are pending.

## Local preparation

```sh
cd apps/mobile
flutter create --platforms=android .
flutter pub get
flutter test
flutter run --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLIC_KEY
```

`SUPABASE_URL` defaults to this academic project's public endpoint, but can be changed using `--dart-define`. Use a local, ignored config file or IDE launch argument for publishable keys. Inspect generated Android files before committing.

## Related source

- `apps/mobile/lib/config/supabase_config.dart`
- `apps/mobile/lib/features/auth/auth_screen.dart`
- `apps/mobile/lib/features/cv/cv_upload_service.dart`
- `apps/mobile/lib/main.dart`
- `services/api/src/app.controller.ts`
