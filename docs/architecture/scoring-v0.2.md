# Scoring v0.2 — evidence first, transferable fit, explainable mobile report

**Implementation:** `supabase/functions/process-cv/scoring.ts` and `index.ts`.
**Live Edge Function:** `process-cv` v7 (scoring upgrade plus storage minimization).
**Version:** `ats-match-v0.2`.

The old 100% ATS / 0% Job Match on a well-extracted CV showed a real evaluation bug, not missing OCR: the database had 43 skill strings and 3 experience entries, but the evaluator compared exact strings and awarded section-presence points. The old rows remain marked `ats-match-v0.1` and should not be silently re-scored.

## Two independently explained assessments

**Document readiness (0–100):** a *CV structure and extraction review*, not a score from any employer's ATS.
The deterministic rubric has seven checks and weights:

| Check | Maximum |
| --- | ---: |
| Contact details (name/email/phone) | 15 |
| Readable content/text extractability | 20 |
| Recognizable sections | 20 |
| Work chronology and dates | 15 |
| Visible competencies | 10 |
| Layout/length risks | 10 |
| Concrete and quantified achievements | 10 |

The actual CV's three-page length may prompt a relevance/readability review without automatically making the CV invalid. Selectable text is only credited when verified; AI vision extraction alone does not prove an original document is selectable. Layout notes are advisory and not a substitute for viewing the original document.

**Job alignment (0–100):** criteria from the *specific pasted job description*.
Gemini must extract at most 22 distinct criteria, including role responsibilities, skills, experience, education, software and communication requirements. The output is structurally validated by deterministic code.

- Each criterion must have a verbatim `source_quote` demonstrably present in the original job posting.
- **Direct evidence** earns 100% of that criterion's points, only when the Gemini-proposed `evidence_quote` appears in the extracted CV text.
- **Transferable but nonidentical evidence** earns **40%** of that criterion's points. E.g. managing software projects versus marketing campaign coordination, without claiming campaign work.
- **Missing or unverifiable evidence** earns 0% for that criterion. Users should be shown *missing evidence*, never told they definitively lack the skill.
- Required criteria receive a multiplier of 1.00; preferred criteria receive 0.35. Type multipliers: tools 1.50, hard skills 1.40, experience 1.35, responsibilities 1.25, education 1.15, soft skills 0.75. Scores are normalized by the sum of weights for **only the criteria that actually exist** in the job.
- Named tools such as HubSpot, Salesforce, Google Analytics or GA4 are **not direct matches** to generic ERP/data dashboards. Related experience may be marked transferable only with a genuine CV excerpt.
- Fabricated CV quotes or job-description quotes are rejected. Too few grounded criteria fails the analysis instead of manufacturing a 0% or 100%.
- The score is a directional *evidence-alignment* assessment, **not a probability of being interviewed, hired or shortlisted**.

## What your example should communicate

For a Full-Stack/AI CV compared with a Marketing Coordinator role, the engine should recognize potentially transferable project coordination, client communication, SEO/UI work, reporting dashboards and relevant marketing certifications **only when supported by CV excerpts**. However, it should *not* assert experience with Google Analytics, HubSpot, Salesforce, paid ads or social/email campaigns unless explicitly evidenced.

A new analysis is required to produce a fresh v0.2 report. Existing v0.1 records retain the original scores and show a **legacy** warning in Flutter.

## Mobile report sections

1. **Overview:** separate readiness and alignment; counts for evidenced / transferable / gap criteria; concise strengths and priorities.
2. **CV Readiness:** seven weighted scores, progress bars and diagnostic explanation.
3. **Job Match:** fit by requirement category, required/preferred coverage, filters for evidenced/related/gaps, verbatim CV evidence and corresponding job text.
4. **Next steps:** ordered priority, actionable, truthful improvements.

## Regression and release quality gates

- `node --experimental-strip-types --test supabase/functions/process-cv/scoring.test.mjs` is the deterministic scorer test.
- Flutter widget tests cover report navigation and the visual score breakdown.
- `process-cv` runs with JWT identity validation, private CV Storage access, quota-aware job claiming and service-role-only result persistence.
- Live E2E must be tested with synthetic documents, multiple job types, no-evidence cases, OCR failures, prompt injection, language variation, provider 429 and queue retries before declaring precision or production readiness.
- Do not expose service role/Gemini keys to Flutter or publish personal CVs as test fixtures.
- Because Gemini generates the transcription and tentative statuses, exact human accuracy is **not yet established**. An evaluation set with human-reviewed ground truth and measured precision/recall is required.

## Product research that informed the feature breakdown

We studied publicly described approaches and reproduced *concepts*, not proprietary UX, visuals or ranking formulas:

- [Teal's Job Matcher](https://help.tealhq.com/en/articles/12060992-using-the-job-matcher): included vs missing keywords, actionable detail.
- [Teal's Resume Analyzer](https://help.tealhq.com/en/articles/9524748-using-the-resume-analyzer): separate resume quality from match scoring; evidence/issue cards.
- [Jobscan's Match Report](https://www.jobscan.co/jobscan-tutorial): hard skills, role experience, education and searchability considered separately.
- [Resume Worded scoring explanation](https://help.resumeworded.com/article/33-how-is-my-score-calculated): weighted checks and explanatory reports.

Our formula is explicitly versioned and independent; no undocumented claim of parity with any of these vendors or an employer ATS.
