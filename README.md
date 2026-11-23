# CV ATS Analysis Platform

Flutter Android-first app + NestJS/TypeScript API + Supabase + Gemini worker.

A candidate can upload a CV and compare it to a job description. The system extracts evidence, scores **ATS compatibility** and **Job Match** independently, and presents explainable recommendations. It is **not** a recruitment marketplace, a commercial ATS or a hiring-probability model.

## Current implementation

| Area | Current state |
| --- | --- |
| Flutter UI | Modern responsive screen code for authentication-first login/create-account tabs, pasteable email OTP, password recovery, candidate dashboard, CV/job form, progress, four results tabs, history, CV library, plans, account, help, appearance, privacy and guarded admin shells |
| Flutter Android build | CI workflow added; successful APK and device testing not yet confirmed |
| Supabase | Tables, private storage, auth-linked profiles, subscriptions, RLS, queued analyses and result tables |
| NestJS API | Deployed to Vercel; health/plans HTTP 200; publishable configuration set, authenticated tests pending |
| Gemini worker | Supabase Edge function `process-cv` deployed ACTIVE; real Gemini calls await protected API credentials and validation. Dedicated Node worker code remains |
| Visitor-before-login analysis | Planned; current upload requires sign-in |
| Premium payment and admin management | UI only; secure backend workflows pending |

**Do not use real CVs for free-tier Gemini testing without appropriate consent, privacy review and data-processing safeguards.**

## Architecture

- `apps/mobile` — Flutter Android client and responsive Material 3 design system
- `services/api` — NestJS REST API using Supabase JWT and RLS
- `services/worker` — separate long-running Node.js worker for document extraction, Gemini and scoring
- `supabase` — database planning and migrations (live migrations managed through connected Supabase project)
- `docs` — architecture, product workflows, deployment and evaluation

## Key references

- **All Flutter pages / workflows:** [Screen and workflow map](docs/product/flutter-screen-and-workflow-map.md)
- **Flutter developer setup:** [Mobile README](apps/mobile/README.md)
- **Vercel variables and where to get them:** [Environment variable map](docs/deployment/environment-variable-map.md)
- **System architecture:** [Architecture overview](docs/architecture/overview.md)
- **Database design:** [Data model](docs/architecture/database-plan.md)
- **AI pipeline and safety:** [Gemini milestone](docs/architecture/gemini-analysis-milestone.md)
- **Deployment:** [Vercel API guide](docs/deployment/vercel-api.md)
- **Web + APK + Worker release:** [Release runbook](docs/deployment/web-android-worker-runbook.md)

## Development checks

GitHub workflows:
- `backend-checks.yml`: API build and scoring tests
- `flutter-android.yml`: Android platform generation, static analysis, widget tests, debug APK

The Flutter feature flag `CV_ATS_ANALYSIS_ENABLED` is disabled by default until worker deployment and end-to-end tests pass.

## Secrets

Never commit Gemini keys, Supabase secret/service-role keys, database passwords, PDFs containing private personal information, or local `.env` files. Flutter only receives public Supabase configuration and the approved backend API URL.
