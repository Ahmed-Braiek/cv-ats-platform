# Exact environment variables — CV ATS

**Verified 2026-11-23** using the connected Vercel project `cv-ats-api`:
- Existing: `SUPABASE_URL`
- Configured: `SUPABASE_PUBLISHABLE_KEY`
- Project: https://vercel.com/ahmed-braieks-projects/cv-ats-api/settings/environment-variables
- Supabase: https://supabase.com/dashboard/project/uqtyxhkevnyjvhwdgkyh/settings/api-keys

## 1. Vercel — NestJS API (`services/api`)

| Variable | Required | Where to obtain | Notes |
| --- | --- | --- | --- |
| `SUPABASE_URL` | Yes | Supabase dashboard → Project Settings → Data API / Project URL, or Connect dialog | Already configured as `https://uqtyxhkevnyjvhwdgkyh.supabase.co` |
| `SUPABASE_PUBLISHABLE_KEY` | **Yes** | Supabase dashboard → Settings → API Keys → **Publishable key** (starts `sb_publishable_`) | Already configured for Vercel API and Vercel Web |
| `CORS_ORIGINS` | Yes for Flutter Web | `https://cv-ats-web-ahmed-braieks-projects.vercel.app` | Already configured for the API; redeploy required when changed. |

Save changes and **redeploy** the API; a prior deployment will not inherit newly added variables.

**Do not** add a Gemini key, Supabase secret/service role key or Postgres database URL to this Vercel API for the current design. The API uses a publishable key + validated end-user token and Supabase RLS. The worker needs privileged credentials separately.

**Do not set** `PORT`, `VERCEL_TOKEN`, `VERCEL_PROJECT_ID`, or `VERCEL_ORG_ID` as application runtime variables. The first is platform-managed; the others are only required for a custom CLI deployment workflow, not Vercel's Git integration.

## 2. Flutter Android — launch/build configuration (NOT Vercel)

| Define | Source | Notes |
| --- | --- | --- |
| `SUPABASE_PUBLISHABLE_KEY` | Same Supabase project publishable key | Public client identifier, never use service-role key |
| `SUPABASE_URL` | Project URL from Supabase | Already defaults to this academic project URL in Dart |
| `CV_ATS_API_URL` | Accessible HTTPS endpoint of Vercel API, e.g. your verified public API hostname | Must be reachable by Android without browser-based Vercel Authentication |
| `CV_ATS_ANALYSIS_ENABLED` | Set to `true` only after worker integration test passes | Deliberate release gate; defaults to `false` |

Use `--dart-define` or a local ignored `--dart-define-from-file` configuration, and never place credentials in the repository.

Example:
```sh
flutter run \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLIC_KEY \
  --dart-define=CV_ATS_API_URL=https://YOUR-PUBLIC-API-HOST
```

## 3. Persistent worker hosting — not on Vercel Functions

| Variable | Source |
| --- | --- |
| `DATABASE_URL` | Supabase dashboard → **Connect** → database connection string (direct or session pooler, with TLS). Supply current database password through the host secret manager; never Git. |
| `SUPABASE_URL` | Same public project URL |
| `SUPABASE_SECRET_KEY` | Supabase → Settings → API Keys → **Secret keys** (`sb_secret_`). Trusted worker ONLY. |
| `GEMINI_API_KEY_PRIMARY` | Google AI Studio → API keys: https://aistudio.google.com/apikey |
| `GEMINI_API_KEY_SECONDARY` | AI Studio API keys, only if required for independent, authorized configuration |
| `GEMINI_API_KEY_TERTIARY` | AI Studio API keys, same caution |
| `GEMINI_MODEL_OCR` | Compatible PDF/image model ID from https://ai.google.dev/gemini-api/docs/models |
| `GEMINI_MODEL_ANALYSIS` | Compatible text/structured-output model ID from the same catalogue |
| `GEMINI_MODEL_FALLBACK` | Eligible fallback model ID |
| `GEMINI_MODEL_TERTIARY` | Optional third eligible model slot |

**Provider constraint:** Google Gemini rate limits apply per Google project, not per API key. Keys in the same project do not supply three independent quotas. The router must respect 429s, retry-after and service limits.

## 4. Deployment protection and privacy

Vercel currently reports deployment protection enabled for non-custom domains. A Flutter Android app cannot complete a browser-based Vercel Authentication challenge. When we are ready for testing, configure an accessible HTTPS API hostname and check Vercel Settings → Deployment Protection. **Do not expose unprotected sensitive endpoints before authorization, quotas and abuse controls are tested.**

Real CVs may contain sensitive personal information. Test only with synthetic documents or fully consented fixtures until Gemini data-handling obligations and account deletion/retention workflows are finalized.

## 5. Step-by-step Vercel configuration

1. Open Supabase API Keys: https://supabase.com/dashboard/project/uqtyxhkevnyjvhwdgkyh/settings/api-keys
2. Copy the **Publishable** `sb_publishable_...` key. Do not copy a secret.
3. Open Vercel Environment Variables: https://vercel.com/ahmed-braieks-projects/cv-ats-api/settings/environment-variables
4. Name = `SUPABASE_PUBLISHABLE_KEY`, value = copied key.
5. Choose Production, Preview and Development, save as encrypted/sensitive if offered.
6. Redeploy and verify `/v1/health` and `/v1/plans` with the intended URL and deployment protection rules.

Official references:
- https://supabase.com/docs/guides/getting-started/api-keys
- https://vercel.com/docs/environment-variables
- https://ai.google.dev/gemini-api/docs/rate-limits

## 5. Supabase Edge Function `process-cv` (new active deployment)

The Edge processor is deployed, but **live Gemini analysis is NOT enabled** until you configure the private model API key, test with synthetic files and explicitly enable the mobile feature flag.

Open: https://supabase.com/dashboard/project/uqtyxhkevnyjvhwdgkyh/functions/secrets

Required variables:
- `GEMINI_API_KEY_PRIMARY` — create in Google AI Studio https://aistudio.google.com/apikey
- `GEMINI_MODEL_OCR` — a supported PDF/image-capable Gemini model ID (e.g. `gemini-2.5-flash-lite` if available)
- `GEMINI_MODEL_ANALYSIS` — compatible job-extraction model (can initially be the same model ID)

Optional `GEMINI_API_KEY_SECONDARY`, `GEMINI_API_KEY_TERTIARY`, `GEMINI_MODEL_FALLBACK`, `GEMINI_MODEL_TERTIARY`.

**Do not** add Supabase service-role keys to GitHub/Vercel Web/Flutter. Hosted Edge Functions receive protected Supabase context automatically. The API key stays inside Edge Function Secrets.

For GitHub Actions → Settings → Secrets and variables → Actions → **Variables**, set:
- `SUPABASE_PUBLISHABLE_KEY` — public client key
- `CV_ATS_API_URL` — `https://cv-ats-api-ahmed-braieks-projects.vercel.app`
- `CV_ATS_ANALYSIS_ENABLED` — optional; `false` until end-to-end AI testing succeeds.

See [Supabase Edge worker guide](supabase-edge-worker.md) and [email verification template](../auth/email-code-setup.md).
