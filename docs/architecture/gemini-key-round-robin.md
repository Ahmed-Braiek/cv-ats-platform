# Gemini API key routing - three-key round robin

**Runtime:** Supabase Edge Function `process-cv`.
**SQL migration:** `supabase/migrations/20261124102947_gemini_three_key_round_robin_v1.sql`.
**Implementation:** `supabase/functions/process-cv/index.ts` and `gemini_key_rotation.ts`.

## Configure secrets in Supabase

Go to the CV-ATS Supabase dashboard > Edge Functions > Secrets.
Create or update these *server-only* secrets:

- `GEMINI_API_KEY_PRIMARY`
- `GEMINI_API_KEY_SECONDARY`
- `GEMINI_API_KEY_TERTIARY`

Only configured, nonempty, distinct values are used; one or two keys are supported too.
Do not put Gemini keys in Flutter, Vercel frontend variables, database rows, or GitHub code.
The model configuration remains `GEMINI_MODEL_OCR`, `GEMINI_MODEL_ANALYSIS`,
`GEMINI_MODEL_FALLBACK`, and optionally `GEMINI_MODEL_TERTIARY`.

## Selection

Each outbound Gemini request asks the database for the next slot through the
service-only RPC `public.cv_ats_next_gemini_slot(active_slots)`.

With three configured distinct keys:

1. OCR request -> key 1
2. Job-requirements request -> key 2
3. Next request -> key 3
4. Next request -> key 1 (repeats)

This sequence is **global across Edge Function isolates** because Postgres
atomically updates one counter under a row lock. It is not per-device, per-user,
or a counter stored in volatile function memory.

Only the counter and timestamp are stored in a private table.
The database never receives the Gemini credential itself.
Authenticated/anonymous users cannot execute the slot RPC.

## Failure and quota handling

- The selected key stays the same if a model returns a transient HTTP 5xx and
  the worker tries another configured *model*.
- HTTP 429 immediately stops that request with `rate_limited`; do **not**
  switch keys or models to evade Gemini provider quotas.
- HTTP 400/401/403 produces `gemini_config_error`, without trying another key.
- A missing or invalid slot produces `gemini_dispatch_unavailable` and no
  provider request.
- A completed analysis consumes two key slots in normal operation: one for
  CV extraction and one for parsing job requirements.

**Quotas are applied at the Google project level**, not separately to each
API key. Three keys associated with one Google project do not triple the quota.
This rotation is for predictable distribution and key management, not an
attempt to bypass Google quotas.

## Verification

The database migration has been applied to the CV-ATS project.
SQL smoke checks observed `[1,2,3,1,2,3]` and confirmed that only
`service_role` can execute the RPC.
The unit tests are in `gemini_key_rotation.test.mjs`:

```sh
node --experimental-strip-types --test supabase/functions/process-cv/gemini_key_rotation.test.mjs
```

Do not send real personal CVs as test fixtures without explicit consent and
a data-handling review.
