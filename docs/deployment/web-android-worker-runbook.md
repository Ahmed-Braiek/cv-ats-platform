# CI/CD and live deployment runbook — Web + Android + API + worker

This runbook is for **CV ATS Analysis** in the GitHub repository
`Ahmed-Braiek/cv-ats-platform`.

## Services and responsibilities

| Component | Host | Deployment state |
| --- | --- | --- |
| Flutter Web | Vercel project `cv-ats-web`, root `apps/mobile` | Latest login-first Flutter Web release compiled READY; widget tests passed, essential assets HTTP 200 |
| Flutter Android APK | GitHub Actions workflow `flutter-release-builds.yml` | Creates a downloadable debug APK as an Actions artifact on success |
| NestJS API | Vercel project `cv-ats-api`, root `services/api` | Health and plans API validated with HTTP 200 |
| Supabase | `uqtyxhkevnyjvhwdgkyh` | Auth, database, RLS and private storage configured |
| Gemini worker | Supabase Edge Function `process-cv` | ACTIVE deploy, but Gemini secrets not configured and live analysis untested. Railway long-running worker remains blocked by expired trial. |

**Deployment is not equivalent to a validated final product.** Gemini needs its own configured worker and integration testing. Flutter's execution feature gate stays disabled until then.

## Vercel Flutter Web: https://vercel.com/ahmed-braieks-projects/cv-ats-web/settings/environment-variables

Use these exact names:

| Key | Value / location | Public? |
| --- | --- | --- |
| `SUPABASE_URL` | `https://uqtyxhkevnyjvhwdgkyh.supabase.co` | Yes; already set |
| `SUPABASE_PUBLISHABLE_KEY` | Supabase → Project Settings → API Keys → `sb_publishable_...` | Public client key already set on Vercel Web; no need to paste into chat or Git |
| `CV_ATS_API_URL` | `https://cv-ats-api-ahmed-braieks-projects.vercel.app` | Yes; already set. API domain must be reachable from public browsers without Vercel Authentication |
| `CV_ATS_ANALYSIS_ENABLED` | `false` until worker passes real end-to-end tests | Yes; already set |

All Flutter `--dart-define` values are compiled into public browser JavaScript. Never put a Supabase secret, Postgres password or Gemini API key there.

After adding the publishable key: **Redeploy** to rebuild the Web assets. Web project build command is `bash scripts/build_web.sh`; output directory `build/web`. The script downloads the pinned Flutter SDK, generates web platform scaffolding, and builds `flutter build web --release`.

## Vercel NestJS API: https://vercel.com/ahmed-braieks-projects/cv-ats-api/settings/environment-variables

| Key | Value | State |
| --- | --- | --- |
| `SUPABASE_URL` | Same project URL | Set |
| `SUPABASE_PUBLISHABLE_KEY` | Same publishable key | Set and observed by deployment |
| `CORS_ORIGINS` | `https://cv-ats-web-ahmed-braieks-projects.vercel.app` | Set; redeploy API after env changes |

Avoid wildcard CORS. Add separate allowed origins for preview domains only if you actually test them.

The app uses the Supabase publishable key plus verified user's JWT. It does **not** need service-role or Gemini secrets.

## GitHub APK builder: https://github.com/Ahmed-Braiek/cv-ats-platform/actions

Workflow: **Flutter release builds** (`.github/workflows/flutter-release-builds.yml`).

GitHub repo **Settings → Secrets and variables → Actions → Variables**:
- `SUPABASE_PUBLISHABLE_KEY` — same public Supabase publishable key.
- `CV_ATS_API_URL` — accessible HTTPS API URL.
- `CV_ATS_ANALYSIS_ENABLED` — optional; keep `false` until AI job processing passes integration tests.

These are intended **public** values: they are embedded into the web JS and APK binaries. Do not put privileged keys in GitHub variables.

Steps:
1. Open **Actions** → **Flutter release builds**.
2. Use **Run workflow** → `main`, or push a change to `apps/mobile/`.
3. Verify **Flutter Android APK and Web** job is green.
4. Under the completed workflow run, download artifact **cv-ats-android-debug-apk**.
5. Extract `app-debug.apk` from the artifact ZIP and install on an Android test device.

**This is a debug-signed installable APK for testing, not a Play Store release.** A production-signed AAB/APK requires a secure signing keystore and passwords stored in **GitHub Actions Secrets**, Play Console validation and a separate signed release workflow. Never commit a keystore.

The same workflow uploads `cv-ats-web-release` as a supplementary CI artifact.

## Persistent Gemini worker

Do not configure Gemini secrets in Vercel Web or Flutter. Use a persistent Node.js worker host:

- `DATABASE_URL`: Supabase **Connect** → direct/session-pooler DB URI (host secrets only; TLS).
- `SUPABASE_URL`: same public project URL.
- `SUPABASE_SECRET_KEY`: Supabase → API Keys → Secret key (server only).
- `GEMINI_API_KEY_PRIMARY`, `GEMINI_API_KEY_SECONDARY`, `GEMINI_API_KEY_TERTIARY`: Google AI Studio API keys: https://aistudio.google.com/apikey
- `GEMINI_MODEL_OCR`, `GEMINI_MODEL_ANALYSIS`, `GEMINI_MODEL_FALLBACK`, `GEMINI_MODEL_TERTIARY`: compatible model IDs from Google AI Studio / https://ai.google.dev/gemini-api/docs/models

Project-level rate limits apply **per Google project**, not per key. Do not rotate keys to evade quotas.

Current alternative: an authenticated Supabase Edge Function (`process-cv`) is deployed but requires protected Gemini secrets. The connected Railway account reports **trial expired**. No worker service was created; no credit card or paid service was provisioned. Alternative connected Render workspace belongs to a different account, so we did not deploy the worker there without permission.

## Smoke tests

1. Web site: returns 200 and loads `main.dart.js`, logo, navigation and login.
2. NestJS: `GET /v1/health` = 200 and `GET /v1/plans` = 200 with Free and Premium.
3. Browser console has no Flutter startup, CORS or mixed-content errors.
4. Register a synthetic user, verify email, sign in; profile and Free subscription exist.
5. Upload a synthetic PDF/JPG and view it in the CV library, only from the owning account.
6. Verify user B cannot access user A's private CV or analysis.
7. When worker configured: switch `CV_ATS_ANALYSIS_ENABLED=true` in Flutter Web and GitHub Variables only **after** successfully testing end-to-end analysis on synthetic fixtures.
8. Real input → `queued` → processing → `completed` with separate ATS/Match scores, versioned recommendations; verify errors/retries and quota enforcement.
9. Test Android debug APK on a device; a green CI build alone does not verify real-device UX.
10. Never declare production-ready until anonymous claim flow, admin, subscriptions, privacy/deletion, logging and reliable worker delivery pass their acceptance criteria.

## Production constraints

Vercel Deployment Protection currently blocks anonymous users on default protected URLs. Use a public, approved frontend domain and a reachable HTTPS API endpoint **after** app-level authorization, abuse protection and privacy controls have been tested.

The current database's `private.analysis_jobs` and `private.temporary_analysis_claims` are in an unexposed, restricted schema, but a schema advisory flags that their RLS is disabled. Review worker identity and enforce defense in depth before handling personal CV data.
