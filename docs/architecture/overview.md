# System architecture — v0

## Application boundaries
```text
Flutter Android client
    | HTTPS + Supabase Auth access token
    v
NestJS REST API on Vercel
    |--> Supabase Auth (JWT validation)
    |--> Supabase PostgreSQL (owner-scoped domain data, audit)
    |--> Supabase private Storage (CV originals)
    |--> durable analysis job queue
                   |
                   v
             Node.js worker (separately hosted)
                   |--> text-first PDF / DOCX extraction
                   |--> Gemini visual extraction for scanned PDF/images
                   |--> JSON schema and evidence validation
                   |--> ATS rubric + job-match rubric
                   |--> Gemini recommendations grounded in evidence
                   '--> persist results and status
```

## Responsibilities
- **Flutter:** views matching Figma, form validation, upload UX, authentication, status polling, result rendering. No AI API keys.
- **NestJS API:** authorized operations, validation, rate limits, subscription usage, staged visitor analyses and claims, job enqueueing, signed file URLs, OpenAPI.
- **Supabase:** managed Auth, PostgreSQL, private Storage, access isolation. Secret/service role credentials only on trusted server.
- **Worker:** asynchronous idempotent jobs with extraction/parsing fallback, Gemini health-aware router, classification and scoring. Do not depend on Vercel request lifetime.
- **Admin:** a minimal role for managing users/plans/limits/stats; never read private CV contents by default.

## Decisions
1. Android first, but Flutter code remains cross-platform.
2. NestJS + TypeScript and explicit DTO validation.
3. Supabase Auth is the source of identity; `profiles.id` maps to `auth.users.id`. No duplicate password store.
4. Exposed schema tables use RLS; internal job tables and model-call logs live in a private schema.
5. Preserve visitor-first analysis: create short-lived opaque claim token for anonymous analysis; store only its *hash*, set expiry, bind to authenticated user in one server-side transaction. Apply anonymous abuse protection.
6. Analysis has immutable results and explicit stages/status to make history repeatable and support academic evaluation.
7. Free/Premium are subscription plans, not separate user entity classes.

## AI design
- Extract document text locally when possible; use vision/PDF Gemini only when necessary.
- Require versioned structured output with source evidence and `unknown` for missing facts.
- Calculate ATS and matching scores using versioned deterministic rubrics; do not output a hiring probability.
- Route among configured models only if compatible and eligible, observing *project-level* quotas. Use jittered backoff, retry-after, circuit-breakers, provider-budget tracking.
- Never use multiple API keys to evade quotas; multiple keys in the same project do not increase the project rate limit.
- Human-readable recommendations must never invent skills, degrees, job titles or experience.

## Deployment
- Vercel: REST API and later web/landing dashboard.
- Worker: separately hosted long-running process; selection pending.
- Supabase: managed database/Auth/private Storage.
- Flutter: Android APK/AAB; Play Store release only after signing and review.
