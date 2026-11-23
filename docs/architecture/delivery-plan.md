# Delivery plan — Android first

## Phase 0 — architecture (now)
- [x] Confirm repo and stack.
- [x] Document user journeys, backend boundaries, and logical data model.
- [ ] Select Supabase organization and provision dedicated project.
- [ ] Review actual Figma components and confirm mobile final screens.
- [ ] Freeze initial functional acceptance tests.

## Phase 1 — foundation
- [ ] Create Flutter app skeleton with Riverpod, GoRouter, theme and app shell.
- [ ] Create NestJS project with health endpoint, request validation, lint, tests, OpenAPI.
- [ ] Set up secure local development configuration and GitHub CI.
- [ ] Create/apply first Supabase schema migration and test RLS.

## Phase 2 — working user flow
- [ ] Supabase email-based auth and profile.
- [ ] CV PDF/DOCX upload to private storage and job-description submission.
- [ ] Visitor temporary analysis claim and post-auth attachment.
- [ ] Analysis status polling, error handling and result rendering.

## Phase 3 — AI evaluation
- [ ] PDF selectable-text parser + DOCX extractor.
- [ ] Scanned PDF/image extraction using configured Gemini model.
- [ ] JSON schema validation and evidence retention.
- [ ] Job requirement parsing; versioned ATS and match rubrics.
- [ ] Model router: compatible model selection, rate limits, retry budgets and audit.
- [ ] Explainable recommendations with no fabricated facts.
- [ ] Synthetic CV benchmark, metrics and academic write-up.

## Phase 4 — release hardening
- [ ] History, subscription limits, Premium PDF export and minimal admin.
- [ ] Tests: unit, integration, security, RLS, Flutter widget, E2E.
- [ ] Android signing, Play policy review, privacy policy, account deletion, monitoring.
- [ ] Vercel API + dedicated worker deployment and rollback plan.

## Quality gates
Do not call the project production-ready until authentication, cross-account isolation, privacy, quota enforcement, API errors, job retry safety, backups and release builds have been tested.
