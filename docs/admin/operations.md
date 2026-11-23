# CV ATS — Administrator operations

The Flutter application has a separate mobile-first **Control room** for authorized administrators. It is not a mockup. The controls call the deployed Supabase Edge Function `admin-console`, which validates the signed-in user's JWT with Supabase Auth and checks the current `public.profiles.role = 'admin'` on **every** request. The private Supabase secret/service-role key stays in the Edge runtime and is never available in Flutter or Vercel Web.

## Activation: create the first administrator

There is intentionally **no default admin**, no public admin-registration form, and no first-user auto-promotion. This prevents ordinary candidates from becoming administrators.

1. Register and verify a **dedicated administrator email account** through the existing Flutter app. Do not reuse your main candidate login if you want to keep a normal candidate workspace.
2. Open [Supabase SQL Editor](https://supabase.com/dashboard/project/uqtyxhkevnyjvhwdgkyh/sql/new).
3. Replace `ADMIN_EMAIL_TO_VERIFY@example.com` in this SQL with the exact email of the **verified** account you control, then run it in the protected Supabase Dashboard:

```sql
do $$
declare v_id uuid;
begin
  select id into v_id
  from auth.users
  where lower(email) = lower('ADMIN_EMAIL_TO_VERIFY@example.com')
    and email_confirmed_at is not null;
  if v_id is null then
    raise exception 'A verified user with this email was not found';
  end if;
  update public.profiles set role = 'admin' where id = v_id;
  if not found then
    raise exception 'User profile was not found';
  end if;
end $$;
```

4. Sign out and sign back in, so the Flutter role gate reloads. The application now opens **Control room** instead of the candidate dashboard.
5. Never execute this on an account you have not independently identified and verified. Don't put a real admin email, secrets, or an SQL promotion credential in the public repository.

## Administrator pages and actions

| Screen | Real functionality |
| --- | --- |
| Overview | Live user count, confirmed accounts, saved CV count, analyses, completion/failure status, subscriptions, 14-day activity and version-specific average scores |
| People | Search by display name, email or ID; paginate; inspect registration/verification, Free/Premium plan and activity counts |
| Account inspector | Manual membership grant, sign-in suspension/restoration, irreversible user+CV+result deletion with email confirmation, explanation and audit |
| Analyses | Filter statuses; inspect date, user, job title, evaluator version, ATS/readiness score, match score and failure code; cancel queued/running tasks |
| Plans | Edit current plan entitlements (monthly analyses, saved CVs, history days, PDF export); changes take effect through existing quota checks |
| Audit | Timestamped, append-only server-side record of plan changes, account actions, and analysis cancellations; copy the visible subset as CSV |

**Subscription limitations:** manual Free/Premium grants change entitlements; **no money is collected**. Payment provider, refunds, invoices, pricing, automated renewals, billing webhooks and transactional email notifications need a future verified billing integration. Do not describe manual Premium assignments as paid subscriptions.

**Suspension limitation:** banning a user prevents new sign-ins, but existing JWTs may remain usable until expiry. Do not promise immediate universal session revocation until all RLS/client access is additionally bound to active session status. For urgent security issues, delete the Auth account and review access-token lifetimes.

**Deletion limitation:** deleting an account removes the user's private Storage objects, app records, analyses, subscriptions and Supabase Auth identity. Storage/API/SQL changes span several systems rather than a single database transaction; in the event of a partial failure the operator must retry and audit the remaining Auth record. Always test with synthetic accounts before real user deletion.

## Security boundaries

- Admin status is stored in `profiles.role`, not user-editable JWT user metadata.
- `cv_ats_admin_*` reporting/mutation RPCs grant EXECUTE **only to `service_role`**; anonymous and ordinary authenticated roles have no permission. `admin_audit_events` has RLS and grants only the service role.
- `admin-console` performs Auth verification and a fresh role lookup on every call. Even a Flutter user manually invoking its endpoint does not bypass that role check.
- No account can delete or ban itself. Candidate actions cannot target an administrator.
- Deletion requires the full email and the literal `DELETE` confirmation; all membership/moderation actions require a reason.
- List endpoints bound `limit <= 50` and offset; server outputs do not include raw CV text or documents.
- CV file removal uses the Storage API, not raw SQL.
- Per-role administration is **one global admin role** for now. Multi-tenant organizations, scoped admin subroles, multi-party deletion approval, notifications and anomaly alerts are future features.

## Deployment and smoke tests

- Edge function: [admin-console](https://supabase.com/dashboard/project/uqtyxhkevnyjvhwdgkyh/functions)
- Database migrations:
  `supabase/migrations/20261123210000_admin_console_v1.sql`,
  `20261123213500_admin_account_status.sql`,
  `20261123220000_admin_analytics_versioned.sql`
- Flutter code: `apps/mobile/lib/features/admin/`
- CV lifecycle: `supabase/migrations/20261123222500_candidate_profile_cv_lifecycle.sql`, refined by `20261123225500_cv_delete_edge_gateway.sql`; deletion is through the verified `delete-cv` Edge Function, not through a user-executable privileged RPC.
- No additional secrets are required in Flutter beyond the existing Supabase publishable key.
- Supabase Security Advisor currently reports **Leaked Password Protection Disabled**; enabling it is a dashboard setting if available on the plan.

Required release tests using **synthetic** accounts:

1. Candidate login shows only candidate pages; direct Edge admin invocation gets HTTP 403.
2. Verified admin login opens Control room; live counts match Supabase read-only SQL.
3. Searching user records works with case-insensitive names/emails; paginated results are stable.
4. Manually change test user's plan Free → Premium → Free, verify quotas and two audit events. No payment is charged.
5. Suspend and restore test account; document JWT expiry limitations.
6. Cancel an active synthetic analysis and verify no later completion overwrites cancellation.
7. Delete a synthetic candidate with an uploaded CV and completed analysis; verify Storage object, Auth identity and dependent rows are all gone.
8. Verify admins cannot delete/suspend other admins or themselves.
9. Test dark/light mode, 360px narrow-phone navigation, keyboard overlap, offline error/retry, pagination and screen-reader labels.
10. Run `flutter analyze`, `flutter test`, `flutter build web --release`, Android APK CI and browser/API/Edge integration tests before production rollout.

## Privacy and security follow-up

Supabase Security Advisor may report leaked-password protection disabled. Enable it in Auth settings if supported by your plan. A production-ready app also needs retention policy enforcement, account deletion notifications, durable audit retention, backing up operational statistics, abuse-rate limits, accessible UX tests, and privacy/AI processor consent disclosures.
