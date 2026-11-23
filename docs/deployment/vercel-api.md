# Vercel API deployment — milestone 4

## Current project
- Vercel team: `ahmed-braieks-projects`
- Vercel project: `cv-ats-api`
- GitHub: `Ahmed-Braiek/cv-ats-platform`
- Root Directory: `services/api`
- Framework: NestJS
- Runtime region: `dub1` (Dublin, close to Supabase `eu-west-1`)
- Vercel project created on 2026-11-23.
- First deployment build: `dpl_BDLFqQMe84ooUuUP4sk1opmhHqvJ`, commit `94600f8`, READY.
- Verified `GET /v1/health` returns HTTP 200 with `{"data":{"status":"ok","service":"cv-ats-api"}}`.

**Important:** Vercel reported the first deployment target as **production** even though a staging/preview target was requested. Vercel Authentication / deployment protection was enabled. Treat the deployment as unverified for application functions; do not onboard real CVs yet.

## Runtime configuration

In Vercel, open Project Settings > Environment Variables.

Already configured (public value):
- `SUPABASE_URL=https://uqtyxhkevnyjvhwdgkyh.supabase.co`

Still required for functional Supabase reads and JWT validation:
- `SUPABASE_PUBLISHABLE_KEY` — copy the **publishable** key from the correct Supabase project's API Keys panel. Configure in Vercel environment variables; this is **not** a privileged service role key.

Optional:
- `CORS_ORIGINS` — comma-separated explicit allowed web origins. Do not enable wildcard CORS for authenticated browser clients.

Never add `DATABASE_URL`, Gemini secret keys or a Supabase privileged key to the Flutter source or GitHub. Configure a separate protected worker host with:
- `DATABASE_URL` (TLS-enforced direct or pooler database access)
- `SUPABASE_URL`
- `SUPABASE_SECRET_KEY` (worker only)
- `GEMINI_API_KEY_PRIMARY`, `GEMINI_API_KEY_SECONDARY`, `GEMINI_API_KEY_TERTIARY`
- `GEMINI_MODEL_OCR`, `GEMINI_MODEL_ANALYSIS`, `GEMINI_MODEL_FALLBACK`, `GEMINI_MODEL_TERTIARY`

Model IDs must be checked for availability and task compatibility in AI Studio. Multiple keys within one Google Cloud project share the same project-level quotas. Never bypass a quota by cycling keys.

## Verify after setting the publishable key
1. Trigger a new Vercel deployment so environment variables take effect.
2. Verify `GET /v1/health` returns 200.
3. Verify `GET /v1/plans` returns only the two active subscription plans.
4. Test `GET /v1/me` without a Bearer token returns 401.
5. Create a synthetic test account through Supabase Auth; confirm profiles/Free subscription are created.
6. Test private CV upload and owner-only metadata retrieval with two distinct test accounts.
7. Only after a separate worker is deployed, submit an analysis of a synthetic CV and verify the status changes through `queued`, processing states, and `completed`.

## CI/CD
GitHub workflow `.github/workflows/backend-checks.yml` validates NestJS builds and the worker's dependency-free scoring tests. This workflow was committed but its execution result has not yet been verified. Add generated, reviewed lockfiles (`package-lock.json` or equivalent) and switch CI to `npm ci` for reproducibility.

## Release blockers
- No verified Android build; Flutter SDK/Android SDK were unavailable in this runtime.
- AI worker not deployed and no real Gemini calls tested.
- Supabase API publishable key not yet configured in Vercel.
- CV privacy, storage deletion, two-user RLS tests, production payment/subscription flow, rate-limit controls, and end-to-end tests remain.
- The existing academic matching rubric must not be marketed as validated hiring probability or a real ATS ranking.
