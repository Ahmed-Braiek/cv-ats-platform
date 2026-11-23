# CV ATS — mobile-first product design & administration release

This is a Flutter implementation, **not a Figma-only mockup**. The components in `apps/mobile/lib/ui/ats_design.dart` are reused by candidate and administrator journeys. The source and backend features described here are committed; a release is only verified after Flutter tests/compilation and live role-based E2E checks pass.

## Global experience principles

1. **Clarity before decoration:** separate CV document-readiness and job-fit assessments; use explicit titles, explanations and no fabricated scores.
2. **Progress is factual:** show server statuses and indeterminate progress, never fake a predictable extraction percentage or completion ETA.
3. **Meaningful empty/loading/error states:** skeletons for actual data, clear offline failure, self-serve refresh, action-specific messages.
4. **Mobile-first hierarchy:** single-column cards, generous tap targets, fixed bottom navigation for five core destinations, desktop NavigationRail.
5. **Safe account management:** privacy and delete actions explain consequences, require confirmations and operate under owner/admin identity policies.
6. **Calm visual language:** navy hero surfaces, saturated but restrained indigo actions, teal highlights, semantic success/warn/error accents.
7. **Accessible by construction:** labels, logical focus traversal, readable body text, status text as well as color, no color-only meaning.
8. **Honest subscriptions:** plan benefits vs billing — manual Premium access never implies a payment happened.

## Candidate experience map

| Journey or page | What the app does now |
| --- | --- |
| Launch and resume | Open Sign in/Create account directly, or restore signed-in user and fetch role; spinner + retry on identity lookup failure |
| Sign in / Sign up | Segmented auth tabs, validation, password recovery, pasteable variable-length email OTP |
| Dashboard | Strong visual headline, new-analysis action, actual activity metrics, recent history, skeletons and recovery |
| New analysis | Two-stage CV + job posting input; private file upload validation and progress cues; availability from real inputs |
| Processing | Five stages from backend `queued/extracting/parsing_job/scoring/recommending`; manual refresh, queued restart, errors |
| Report | Overview, CV readiness, job match and next-step tabs; per-requirement evidence and grounded advice |
| History | Filterable saved analyses with status and navigation back to each report |
| CV library | Private file details, expiring viewing links and confirmed owner-scoped CV/results deletion through Edge |
| Account | Profile identity, safe display-name edit, current membership summary, settings, privacy and sign-out |
| Plans | View Free/Premium limits; billing/checkout **not** connected |
| Appearance | Light/dark/device choice in session; preference persistence **not** connected |
| Help & privacy | Explanations of ATS and AI limitations, data/privacy guidance |

## Administrator experience map

Admin users are routed into a distinct responsive **Control room**, not added as a public sixth navigation tab.

| Tab | Read-only analytics | Controls |
| --- | --- | --- |
| Overview | Registered/verified users, stored CVs, job totals, completed/in-progress/failed, versioned ATS/match averages, active subscriptions and 14-day trend | Refresh |
| People | Searchable user list, email verification, CV count, analyses count, plan and status | User inspector; manual plan assignment, suspend, restore, permanent delete |
| Analyses | Latest jobs, user, status, version, scores and error code | Filter and cancel queued/in-progress processing |
| Plans | Free/Premium entitlements (monthly quota, CV storage, retention, report export) | Audited edits to limits |
| Audit | Action, actor, reason, timestamp, target | Paginated inspection and copy currently visible rows as CSV |

No public registration creates an admin. First admin account must be manually promoted after verifying ownership in Supabase SQL Editor; see [operations guide](../admin/operations.md). Admin calls use their own Supabase Edge gateway and fresh role verification; service-role secrets never ship to Flutter.

## Shared design tokens and components

- `AtsPalette`: primary indigo, navy for feature hero, teal for informative emphasis, muted secondary copy; semantics for success/attention/danger.
- `AtsTheme`: typography ladder, legible body line-height, Material 3 text-input and button sizes, platform-appropriate transitions.
- `AtsPanel`: consistent white/dark surface with border, radius and touch affordance.
- `AtsSectionTitle`/`AtsEyebrow`/`AtsHeader`: hierarchy across screens.
- `AtsSkeleton`/`AtsLoadingCards`: indeterminate loading without fake data.
- `AtsInfoStrip`/`AtsEmptyState`/`AtsStatusChip`: helpful feedback with visible text.

## Five stages of CV parsing

```
Queued (file stored privately)
  → Extracting (PDF/image/DOCX text + experiences)
  → Parsing job (explicit requirements)
  → Scoring (evidence-grounded ATS + match)
  → Recommending (prioritized guidance)
  → Completed (persisted report ready)
```

Failure and cancellation are alternate terminal states. The UI uses *indeterminate* progress, not an invented percentage. The processor may stay queued or fail due to provider quotas, unsupported file content, missing job criteria or runtime limits. The user can inspect status and recover.

## Production readiness outstanding

- Flutter admin/recent UX branch must pass `flutter analyze`, widget tests, Web release build, Android APK builder, real-device screenshots and role E2E. **Source commits alone are not a release.**
- Auth: enable leaked-password protection in Supabase dashboard if available.
- Add durable user-account deletion retries and audited reconciliation across Auth, Storage and DB.
- Add password/session revocation strategy for immediate suspension of already-authorized devices.
- Add provider health dashboards, queue recovery and alerting. Supabase short-lived background functions have execution limits.
- Add live billing integration, refunds, invoices, payment webhooks and billing audit before offering paid Premium subscriptions.
- Add saved theme preference, localized content, live file preview and full WCAG accessibility test matrix.
- Add consent/privacy terms and retention schedule for AI-processed personal CV information.
- Test on narrow Android widths (320/360dp), text scale 200%, screen readers, slow network/offline, keyboard overlays and orientation transitions.
