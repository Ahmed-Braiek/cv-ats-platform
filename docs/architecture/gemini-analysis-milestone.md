# Milestone 3 — Gemini processing and explainable ATS / Job Match

## Database changes applied to the live Supabase project

Supabase project: `uqtyxhkevnyjvhwdgkyh`.

- Migration `cv_ats_analysis_processing_and_results`
  - Adds `candidate_profiles`, `ats_results`, `match_results`, `recommendations`.
  - Enables RLS on all four new public tables with owner-scoped read policies.
  - Permits authenticated users to submit their own job descriptions and queued analyses; RLS checks the ownership of the CV and job description.
  - A trusted trigger queues analyses in `private.analysis_jobs` after insertion.
- Migration `cv_ats_enforce_analysis_quota`
  - Checks current Free/Premium plan, counts analyses in the calendar month and limits outstanding queued/processing jobs to two per user.
  - Uses a transaction-scoped advisory lock to prevent concurrent requests racing past the quota.
  - Checks the authenticated owner again before allowing an insert.

Migration history is stored by Supabase and can be inspected in its dashboard. **Do not run these migrations again manually.**

## Code

- `services/worker/src/index.mjs`: Postgres `FOR UPDATE SKIP LOCKED` lease/claim, private CV retrieval, retry scheduling, atomic result writes.
- `services/worker/src/gemini.mjs`: PDF/image OCR-like document understanding, DOCX text input and JSON-only Gemini responses.
- `services/worker/src/scoring.mjs`: deterministic and explicitly versioned ATS and job-skills matching rubric.
- `services/worker/test/scoring.test.mjs`: dependency-free Node tests for scoring.
- `services/api/src/app.controller.ts`: JWT-validated `POST /v1/analyses`, owner-only `GET /v1/analyses/:id/results`.
- `apps/mobile/lib/features/analysis`: job submission, status polling and ATS vs Job Match display.
- `apps/mobile/lib/main.dart`: connects the upload form to submission and results.

## Current AI limitations

- The ATS rubric is a first **academic baseline**: email, headings, sections and selectable-text indicators. It has not been validated against real ATS platforms.
- Job Match v0.1 only measures exact normalized overlap of explicitly extracted skills; it **does not yet implement semantic embeddings**, evidence-based experience weighting or nuanced education matching.
- Missing required skills are reported as gaps, not automatically recommended as invented experience.
- A job description without extracted explicit skill requirements is rejected instead of receiving a fabricated high match score.
- The CV extractor currently processes original PDFs through Gemini and DOCX through `mammoth`. Robust local PDF text extraction, scanned/document segmentation, semantic comparisons and structured schema versioning are next.
- Gemini model routing supports three configurable model slots. HTTP 429 halts the current run and queues a retry **without rotating keys to circumvent Google project-level quotas**.
- AI JSON validation is currently partial; full JSON Schema validation, model-version evaluation and content-safe logging must be added before real-user production use.
- CV source PDF files are private, but Gemini will receive CV contents. Use synthetic/consented examples while data-use terms and privacy arrangements remain under review.

## Local setup and verification

This environment does not have Flutter, a reachable npm registry or configured Gemini secrets. No end-to-end analysis is claimed.

Worker requires a dedicated **secret** `DATABASE_URL` with database privileges appropriate for Postgres job processing, project URL, Supabase backend secret and Gemini API keys. The worker must be deployed on a persistent process host, **not as an always-running Vercel serverless function**.

```sh
cd services/worker
npm install
npm test
npm start
```

```sh
cd services/api
npm install
npm run build
npm run dev
```

```sh
cd apps/mobile
flutter create --platforms=android .
flutter pub get
flutter test
flutter run --dart-define=SUPABASE_PUBLISHABLE_KEY=<PUBLIC_PUBLISHABLE_KEY> \
  --dart-define=CV_ATS_API_URL=http://10.0.2.2:3000
```

The HTTP emulator URL is for **local development only**. Production must use HTTPS and the Android application must be configured accordingly. Configure secrets only in local ignored environment files or the hosting environment. Never commit API tokens, database passwords, raw CVs or private training/evaluation samples.

## Remaining before a real production release

1. Install/lock dependencies and build/test Android and NestJS.
2. Resolve schema warnings around private job RLS according to the worker execution role.
3. Add full JSON Schema validation, CV parsing safety hardening, artifact cleanup, idempotent retry tests, usage/latency monitoring and proper worker lease renewal.
4. Run two-account RLS isolation and genuine synthetic PDF/DOCX/image fixture tests.
5. Set Vercel API deployment and a separate long-running worker deployment.
6. Restore visitor-before-signup analysis/claim flow.
7. Complete admin, history, Premium PDF export and user data deletion.
