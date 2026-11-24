/**
 * Gemini model selection is independent of API-key round robin.
 * Older model IDs may return 404 for new Google AI Studio projects.
 * A stable document-capable model is always the final fallback.
 */
export const SAFE_DOCUMENT_MODEL = "gemini-3.5-flash-lite";

export function candidateModels(configured: Array<string | undefined>): string[] {
  const names = [...configured, SAFE_DOCUMENT_MODEL].map((name) =>
    (name ?? "").trim().replace(/^models\//, "")
  ).filter((name) => /^[a-zA-Z0-9._-]{3,80}$/.test(name));
  return [...new Set(names)];
}

export type GeminiHttpAction = "rate_limited" | "configuration" |
  "next_model" | "unavailable";

export function classifyGeminiHttp(status: number): GeminiHttpAction {
  if (status === 429) return "rate_limited";
  if ([400, 401, 402, 403].includes(status)) return "configuration";
  if (status === 404 || status === 408 || status >= 500 && status < 600) {
    return "next_model";
  }
  return "unavailable";
}

export function finalGeminiError(statuses: readonly number[]): string {
  return statuses.length > 0 && statuses.every((status) => status === 404)
    ? "gemini_model_unavailable"
    : "gemini_unavailable";
}
