# Database design and security plan — DRAFT

**This document is a reviewable data model, not an applied migration.** Final SQL will follow selection of the correct Supabase organization and project.

## Identity and ownership
| Table | Essential columns / ownership |
| --- | --- |
| `public.profiles` | `id uuid PK = auth.users.id`, display_name, role, created_at |
| `public.subscription_plans` | id, code (free/premium), name, monthly_analysis_limit, saved_cv_limit, history_days, pdf_export_enabled |
| `public.subscriptions` | id, user_id, plan_id, status, starts_at, renews_at, usage_period_start |
| `public.usage_ledger` | id, user_id, analysis_id, units, usage_period, idempotency_key |
| `public.cvs` | id, user_id, storage_path, original_name, mime_type, size_bytes, uploaded_at, deleted_at |
| `public.candidate_profiles` | id, cv_id, full_name, email, phone, summary, extraction_version |
| `public.experiences` | id, candidate_profile_id, employer, title, start_date, end_date, description |
| `public.education` | id, candidate_profile_id, school, qualification, start_date, end_date |
| `public.skills` | id, candidate_profile_id, name, category, evidence |
| `public.job_descriptions` | id, user_id nullable, title, company, raw_text, created_at |
| `public.job_requirements` | id, job_description_id, type, value, mandatory, weight |
| `public.analyses` | id, user_id nullable, cv_id, job_description_id, status, created_at, completed_at, evaluator_version |
| `public.ats_results` | analysis_id PK, overall, structure, formatting, readability, keywords, completeness, rubric_json |
| `public.match_results` | analysis_id PK, overall, skills, experience, education, semantic, mandatory_coverage, rubric_json |
| `public.recommendations` | id, analysis_id, priority, category, issue, reason, action, related_section |
| `public.payments` | id, subscription_id, amount, currency, status, provider_reference (no card details) |

## Private processing
| Table | Purpose |
| --- | --- |
| `private.analysis_jobs` | analysis_id, stage, attempts, lease, retry_at, error_code, idempotency key |
| `private.temporary_analysis_claims` | analysis_id, token_hash, expires_at, claimed_at; no raw token |
| `private.model_invocations` | analysis_id, task, model_id, provider_project, outcome, latency_ms, token counts; no CV text |
| `private.admin_audit_events` | actor_id, action, target_type, target_id, timestamp |

## Relationships
- One user has many CVs and analyses, optionally one active subscription.
- One CV has one extracted CandidateProfile; each profile owns many experiences, education items and skills.
- Each analysis references a CV and JobDescription, and owns exactly one ATSResult, one MatchResult, many Recommendations.
- Job descriptions own many requirements. Free/Premium use rows in SubscriptionPlan.
- Anonymous analysis inputs remain server-controlled until a validated one-use claim binds them to an authenticated user.

## Supabase security checklist
1. Every `public` table must have RLS enabled; revoke all grants by default, then grant only required operations.
2. Owner-scoped SELECT/INSERT/UPDATE/DELETE policies must use `(select auth.uid()) = user_id` or equivalent ownership joins. Never trust editable `user_metadata` for admin rights.
3. Admin access is mediated by a server-verified role; avoid client-controlled `role` fields and public bypass functions.
4. Keep `private` schema **outside exposed Data API schemas**; only trusted server/worker gets private jobs/model logs.
5. Use a **private** storage bucket for originals; object names are opaque and linked to owner; signed upload/download URLs have short lifetimes.
6. Validate MIME + file magic, content length and scan/limit uploads; support deletion and retention policy.
7. Test authenticated owner, other user, anonymous visitor and administrator access for every operation.
8. No free-tier real CV submissions without privacy review and consent.
9. Store JSONB evidence/version metadata for reproducible scoring; avoid storing the same raw text unnecessarily.
10. Use atomic subscription-usage reservations and idempotency keys to prevent duplicate charging on retries.

## Pending decisions before SQL migration
- Supabase account/organization/project and target region.
- Exact subscription quotas; payment provider optional.
- Visitor claim-token TTL and original-file retention periods.
- Worker transport (Supabase Queues / Redis / alternative) and region.
- Whether any public direct Supabase reads are necessary or all domain access goes through NestJS.

## Migration plan
Start with `profiles`, `subscription_plans`, `subscriptions`, `cvs`, `job_descriptions`, `analyses`, and private job/claim tables; add extracted-profile and result tables next. Test RLS and cross-user isolation before enabling mobile access.
