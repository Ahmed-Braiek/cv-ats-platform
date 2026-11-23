# Gemini worker — Supabase Edge fallback

## Current status
- Function `process-cv` deployed as ACTIVE in project `uqtyxhkevnyjvhwdgkyh`.
- Source: `supabase/functions/process-cv/index.ts`.
- Three service-role-only RPC functions are deployed: `cv_ats_edge_claim`, `cv_ats_edge_complete`, and `cv_ats_edge_fail`. Ordinary authenticated/anonymous database roles have no EXECUTE access.
- The function requires a valid Supabase user session and an analysis that belongs to that user. Unauthenticated access is rejected in the function itself.
- The function was deployed with gateway JWT verification disabled **because its handler performs explicit JWT identity validation against Supabase Auth**. This is intentional but must stay under security review.
- Supabase provides project URL and backend keys to hosted Edge Functions by default. Do not add privileged values to the browser or GitHub.
- **NOT YET processing live CVs** — Gemini secrets and a successful end-to-end integration test are missing. Keep `CV_ATS_ANALYSIS_ENABLED=false`.

## Activate with private Supabase Edge Function secrets

Open:
https://supabase.com/dashboard/project/uqtyxhkevnyjvhwdgkyh/functions/secrets

Add:
- `GEMINI_API_KEY_PRIMARY` — Google AI Studio https://aistudio.google.com/apikey
- `GEMINI_MODEL_OCR` — image/PDF-capable Gemini model available to your Google project
- `GEMINI_MODEL_ANALYSIS` — structured-output Gemini model available to your Google project

Optional:
- `GEMINI_API_KEY_SECONDARY`, `GEMINI_API_KEY_TERTIARY`
- `GEMINI_MODEL_FALLBACK`, `GEMINI_MODEL_TERTIARY`

Model availability, current quotas and free tiers must be checked in **your** Google AI Studio account. Google quota is per Google project, not per API key. HTTP 429 is not treated as an opportunity to rotate keys.

Once configured, use a synthetic PDF/PNG/JPG/DOCX test fixture and a synthetic job description. Enable the analysis feature in Flutter build defines only after successful authorization and result tests.

## How the Edge processor works

1. Signed-in Flutter client calls NestJS to create an analysis record. Supabase enforces ownership and plan quotas.
2. If the Flutter feature gate is enabled, it invokes the `process-cv` Edge Function with the returned analysis ID and its Supabase user token.
3. The Edge Function verifies that token against Supabase Auth.
4. A service-role-only SQL function claims a short-lived lease on the matching private processing job.
5. The Edge Function reads the private CV and job description, validates file signatures, asks Gemini to extract evidence, calculates separate ATS and Job Match scores, and writes results atomically through a privileged SQL RPC.
6. The Flutter result page polls the NestJS API.

## Limits and production hardening

- This is **on-demand bounded background processing**, not a persistent always-on worker. Supabase Free has a 150-second wall-clock limit, 256 MB memory and tight CPU limits.
- An interrupted task may require a scheduled queue recovery mechanism. Recovery/cron is not yet deployed.
- DOCX extraction uses ZIP decompression; prevent zip bombs and malformed documents before processing real private files.
- Add full JSON schema validation, provider safety rules, file retention/deletion, consent, monitoring and failure retry tests.
- No real CVs until consent and Gemini data-processing terms are assessed.
- A dedicated Node.js worker remains in `services/worker`, but its preferred Railway host is blocked by an expired trial.

References:
- https://supabase.com/docs/guides/functions/background-tasks
- https://supabase.com/docs/guides/functions/limits
- https://supabase.com/docs/guides/functions/secrets
