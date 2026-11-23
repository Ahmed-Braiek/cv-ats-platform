# CV ATS Analysis Platform

A production-oriented, academic CV analysis platform: **Flutter (Android first)** + **Node.js/NestJS API** + **Supabase** + **Gemini**.

## Product scope
A candidate uploads a PDF/DOCX CV and provides a job description. The backend extracts a structured candidate profile, calculates **ATS compatibility** and **job alignment** as separate explainable scores, and produces truthful actionable recommendations. Visitors can initiate an analysis before signup; the complete results require login/registration. Registered users have history and subscription access. A minimal administrator manages users, plans/limits, and statistics.

This is **not** a recruitment marketplace, recruiter ATS, hiring-probability predictor, or auto-apply platform.

## Architecture
- `apps/mobile` — Flutter Android-first application (Riverpod + GoRouter proposed)
- `apps/web` — optional admin/marketing web app (later)
- `services/api` — NestJS REST API, validation, Supabase JWT verification, quotas
- `services/worker` — queued document processing and Gemini integration
- `packages/contracts` — API schemas and generated OpenAPI client contract
- `supabase` — PostgreSQL schema migrations, policies, storage setup and database tests
- `docs` — architecture decisions, data model, API, AI reliability and release plan

See [architecture](docs/architecture/overview.md), [data model](docs/architecture/database-plan.md), and [delivery plan](docs/architecture/delivery-plan.md).

## Development principles
- **No secrets in Git.** Configure keys only in service environment settings or local ignored `.env` files.
- **CV privacy by default.** Store PDFs/images in private Supabase Storage; enable per-owner RLS for user-visible tables.
- **Deterministic explainability.** AI extracts facts and recommends actions; the backend computes ATS/Job Match rubrics.
- **One analysis at a time per job.** Workers are idempotent, retry boundedly, and respect provider limits.
- **Synthetic data for demos.** Do not send real CVs to free-tier AI without informed consent and a privacy review.
- **Shipping is incremental.** Architecture documentation first; implementation, tests, secrets, and deployment follow.

## Status
Initial planning scaffold. No deployed API, database project, credentials, or production mobile application yet.
