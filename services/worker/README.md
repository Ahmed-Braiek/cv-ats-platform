# CV analysis worker

Planned long-running Node.js worker for local PDF/DOCX extraction, Gemini vision fallback, evidence-backed structured extraction, deterministic ATS/job scoring and grounded recommendations.

Worker must be idempotent and respect project-level Gemini quota, retry-after, cooldowns and provider privacy constraints. The worker will not be deployed as a long-running process on Vercel Functions.
