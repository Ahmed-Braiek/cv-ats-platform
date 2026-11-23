# Flutter product screen map and workflow contract

This document is the canonical **mobile implementation checklist**, not a Figma remake.
Design tokens and UI components live in `apps/mobile/lib/ui/ats_design.dart`.
Reference: supplied screenshot 'Group 1.png' (visitor, candidate, admin, responsive flows) and project UML.

## Product principles

- Android first, with responsive layouts for narrow phones and tablets.
- Modern Material 3 interface: white / pale-grey canvas, deep navy headings, vivid blue primary actions, cyan success accents, roomy cards, readable typography.
- Dark mode, accessible contrast, scalable text, minimum 48dp hit targets, explicit focus order, semantic labels and non-color error messages.
- Every network page includes **loading, empty, error, retry, success** states; no fabricated scores, testimonials, payment success or user statistics.
- Separate, **explainable** ATS Score and Job Match; no hiring probability.
- Users may explore without login; personal data and full results require authentication.
- All API errors should be turned into actionable, non-technical messages.
- Progressive disclosure: Overview → breakdown → recommendations. Persist analysis progress so users can leave/re-enter.

## Visitor journey

| Screen | User experience | Implementation state |
| --- | --- | --- |
| Landing / product intro | Clear headline, ATS vs Job Match explanation, primary Analyze CTA, sign-in CTA | UI coded |
| New Analysis | CV file picker + job description, validation, upload progress | UI coded for authenticated upload |
| Processing steps | Input validation, extraction, scoring, recommendations, result readiness | Polling and status UI coded; no fine-grained step display yet |
| Public preview | Partial, non-sensitive scores and locked detailed result | Planned; requires privacy-safe server API |
| Unlock analysis | Sign in / register after analysis and claim anonymous session | Planned; currently login before upload |
| Login | Email/password, visibility toggle, loading, API error handling | UI coded |
| Register | Name/email/password, confirmation-email state, signup validation | UI coded |
| Forgot password | Recovery email request | Request UI coded; deep-link reset completion pending |
| Confirm email | Guidance for checking email and returning | UI coded; dedicated deep-link handler pending |
| Plans preview | Free vs Premium plan comparison without misleading payment CTA | UI coded; server-sourced |

## Registered candidate

| Screen | Key actions | State |
| --- | --- | --- |
| Dashboard | Real analysis counts, empty state, new analysis, latest activity | UI/data coded |
| New analysis | Upload CV, job description, submit analysis | API submission coded |
| Analysis progress | Poll persisted job status, handle failure and retry | UI/data coded |
| Results overview | Independent ATS and Job Match scores and recommendation count | UI/data coded |
| ATS detail | Components, source-readable structure and document parsing caveats | UI/data coded |
| Job Match detail | Matched required / missing required / missing preferred skills | UI/data coded |
| Recommendations | Prioritized evidence-based actions | UI/data coded |
| History | Filter and reopen previous analyses | UI/data coded |
| CV library | Private uploaded file metadata list and details | UI/data coded |
| CV preview / deletion | Secure viewer, deletion confirmation, cleanup | Planned |
| Candidate profile | Extracted experiences, education, skills, verification of AI facts | Planned |
| Subscription / usage | Current plan, available plans, limits and remaining usage | Plans UI coded; usage details pending |
| Premium checkout | Payment provider, confirmation, invoices and cancellation | Planned; checkout disabled |
| PDF export | Owner-only report download with Premium feature enforcement | Planned |
| Account | Profile identity, email, theme, help, sign out | UI coded |
| Settings | Theme preferences, language choice, notifications, data controls | Theme in-session; other settings planned |
| Help / FAQs | Product and privacy answers | UI coded |
| Privacy and deletion | Consent, retention, delete account/data | Privacy info UI coded; deletion flow planned |
| Notifications | Analysis complete, payment and quota alerts | Planned |

## Administrator

| Screen | Actions | State |
| --- | --- | --- |
| Admin overview | System health and summary statistics | Protected UI shell; no backend data |
| User management | Search/filter/suspend users, admin audit trail | Protected UI shell; APIs pending |
| Plans and limits | Manage Free/Premium quota and settings | Protected UI shell; APIs pending |
| System statistics | Usage, analysis success/failure, AI budget, queue latency | Protected UI shell; APIs pending |
| Admin security | Server role verification, audit log, no bulk CV exposure | Planned |

**Critical:** Administrator UI must be guarded by authoritative server permissions; a client-visible screen never grants authorization. The current account screen shows its navigation only for a database `profiles.role='admin'` record.

## State machine and exceptional journeys

1. **Guest** → landing → optional CV / job details → anonymous analysis → partial preview → login/register → claim completed analysis (pending implementation).
2. **Candidate** → login → dashboard → file validation → upload → submit → queued → processing → completed → ATS/Match/recommendations → history.
3. **Candidate, error** → invalid file / upload failure / rejected quota / Gemini 429 / job failed → meaningful explanation and retry without duplicating consumption.
4. **Email recovery** → recovery request → email link → deep-linked set-new-password screen → sign in (deep link pending).
5. **Billing** → plan comparison → checkout provider → webhook verification → updated subscription → receipt/cancel (pending).
6. **Account deletion** → reauthentication → export data if requested → confirmation → deletion job/storage cleanup/audit (pending).
7. **Admin** → verified admin login → overview → users / plans / stats and audit (pending secure APIs).

## Navigation and development rules

Current candidate shell uses bottom navigation (Overview, Analyze, History, My CVs, Account) on phones and NavigationRail on tablets.
Result details are 4 tab pages: Overview, ATS, Job Match, Recommendations.

Use `AtsPage`, `AtsPanel`, `AtsEmptyState`, `AtsStatusChip`, `AtsMetric` and `AtsTheme` rather than independent ad-hoc styling.

Do not create false success states. Keep a button disabled or show a clear explanation if its backend is not implemented.

## Required acceptance tests

- Responsive layouts at 320px, 360px, 412px phone widths, 600px and 1024px landscape/tablet.
- VoiceOver/TalkBack: form labels and progress updates. Contrast >= 4.5:1 for body text.
- Keyboard input, autofill, focus handling, back gesture/navigation, large text and reduced motion.
- Two-user RLS isolation for profile, CVs, analysis, extracted profile, result tables, and Storage.
- Download/file deletion retention, duplicate submissions, quota race and network failures.
- AI fixtures: selectable PDF, scanned PDF, JPG/PNG, DOCX, duplicate skills, French/English, no job criteria, low-quality scans.
- Rate-limit and retry tests, output schema validation, no fabricated skills, consent and deletion.
- Flutter widget/integration tests, Android debug and release builds, backend TypeScript build, unit tests and end-to-end tests.

**This checklist tracks UI coverage and real backend completion separately**; a screen being coded does not imply all its workflows are live.
