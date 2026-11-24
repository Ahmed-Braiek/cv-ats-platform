/** Gemini model fallback is independent of server-only API-key round robin. */
export const SAFE_DOCUMENT_MODEL = "gemini-3.5-flash-lite";
export const SUPPORTED_DOCUMENT_FALLBACKS = [
  SAFE_DOCUMENT_MODEL,
  "gemini-3.1-flash-lite",
  "gemini-3.8-flash",
] as const;

/** Keep explicit model preferences, then try independent supported model pools. */
export function candidateModels(configured: Array<string | undefined>): string[] {
  const names = [...configured, ...SUPPORTED_DOCUMENT_FALLBACKS].map((name) =>
    (name ?? "").trim().replace(/^models\//, "")
  ).filter((name) => /^[a-zA-Z0-9._-]{3,80}$/.test(name));
  return [...new Set(names)];
}

export type GeminiHttpAction = "rate_limited" | "configuration" |
  "next_model" | "unavailable";

export function classifyGeminiHttp(status: number): GeminiHttpAction {
  if (status === 429) return "rate_limited";
  if ([400,401,402,403].includes(status)) return "configuration";
  if (status === 404 || status === 408 || status >= 500 && status < 600)
    return "next_model";
  return "unavailable";
}

/** Retry temporary provider/network errors only, never invalid credentials or quota. */
export function canRetryTransientStatus(status: number): boolean {
  return status === 408 || status >= 500 && status < 600;
}

export function transientBackoffMs(retry: number, jitter: number): number {
  const boundedRetry = Math.max(0, Math.min(3, Math.floor(retry)));
  const boundedJitter = Math.max(0, Math.min(1, jitter));
  return 800 * 2 ** boundedRetry + Math.floor(400 * boundedJitter);
}

export function expectedGeminiShape(task: "ocr" | "job", raw: unknown): boolean {
  if (raw === null || typeof raw !== "object" || Array.isArray(raw)) return false;
  const data = raw as Record<string, unknown>;
  if (task === "job") return Array.isArray(data.requirements);
  const candidate = data.candidate as Record<string, unknown> | null;
  const document = data.document as Record<string, unknown> | null;
  return candidate !== null && typeof candidate === "object" &&
    !Array.isArray(candidate) &&
    !!document && typeof document === "object" &&
    typeof document.raw_text === "string" &&
    !!data.sections && typeof data.sections === "object" &&
    Array.isArray(candidate.skills) && Array.isArray(candidate.experience) &&
    Array.isArray(candidate.education);
}

export function finalGeminiError(statuses: readonly number[]): string {
  return statuses.length > 0 && statuses.every((status) => status === 404)
    ? "gemini_model_unavailable"
    : "gemini_unavailable";
}
