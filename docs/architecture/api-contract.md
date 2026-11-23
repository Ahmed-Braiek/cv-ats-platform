# REST API planning contract (v0)

All authenticated endpoints accept a Supabase access token as `Authorization: Bearer <token>` and must validate its signature, issuer, audience and expiry on the backend.

| Method | Route | Purpose |
| --- | --- | --- |
| GET | `/health` | readiness (no private information) |
| POST | `/v1/analyses/visitor` | start temporary analysis with CV + job description; rate limited |
| GET | `/v1/analyses/visitor/:id/status` | anonymous status using one-time capability token |
| POST | `/v1/analyses/:id/claim` | authenticate and claim eligible temporary analysis |
| POST | `/v1/analyses` | authenticated new analysis |
| GET | `/v1/analyses/:id/status` | owner-only processing status |
| GET | `/v1/analyses/:id` | full ATS + matching + recommendations after auth |
| GET | `/v1/analyses` | owner's paginated analysis history |
| GET | `/v1/cvs` | owner's CV metadata |
| POST | `/v1/cvs/upload-url` | validated signed private storage upload |
| GET | `/v1/subscription` | current plan, usage and feature flags |
| GET | `/v1/plans` | public plan information |
| GET | `/v1/analyses/:id/report` | Premium PDF export, owner only |
| GET | `/v1/admin/summary` | restricted system counters |

Responses: `{data,meta}` success envelope, `{error:{code,message,requestId}}` for errors. No stack traces or user CV text in logs.

## Analysis states
`queued -> extracting -> parsing_job -> scoring -> recommending -> completed`
Terminal: `failed`, `cancelled`, `expired`. Fallback/retries remain internal worker states; never claim success without validated persisted results.

## Core AI JSON contracts
```json
{
  "schema_version": "1",
  "candidate_profile": {
    "full_name": null,
    "skills": [],
    "experiences": [],
    "education": []
  },
  "source_evidence": [],
  "warnings": []
}
```

The backend validates AI output with a strict schema. Values without evidence remain unknown. Model names and keys are environment configuration, not embedded in Flutter or Git.
