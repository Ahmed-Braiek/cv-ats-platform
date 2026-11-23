# NestJS REST API

Node.js + TypeScript API planned for Vercel deployment. The server validates Supabase access tokens and handles ownership, subscription quotas, staged anonymous analyses, signed storage access, and job enqueueing.

Do not run long OCR/AI jobs in HTTP request handlers. See `docs/architecture/api-contract.md` and `docs/architecture/overview.md`.
