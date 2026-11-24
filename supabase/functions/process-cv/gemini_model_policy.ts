/** Model selection is independent of the 3-key round-robin allocator. */
export const SAFE_DOCUMENT_MODEL = "gemini-3.5-flash-lite";
export const SUPPORTED_DOCUMENT_FALLBACKS = [
  "gemini-3.8-flash",
  SAFE_DOCUMENT_MODEL,
  "gemini-3.6-flash",
  "gemini-3.1-flash-lite",
] as const;

/** Exclude legacy 2.x models and non-text-generation endpoints (image, TTS, etc.). */
export function textGenerationModel(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const name = value.trim().replace(/^models\//, "");
  if (!/^gemini-3\.[0-9]+-flash(?:-lite)?(?:-[a-z0-9]+)?$/.test(name)) return null;
  if (/-image(?:-|$)|-tts(?:-|$)|-audio(?:-|$)|-preview$|-exp$/.test(name))
    return null;
  return name;
}

/** Parse Google's GET /v1beta/models response, not a guessed model catalogue. */
export function listedContentModels(payload: unknown): string[] {
  if (payload === null || typeof payload !== "object") return [];
  const models = (payload as {models?: unknown}).models;
  if (!Array.isArray(models)) return [];
  const eligible: string[] = [];
  for (const raw of models) {
    if (!raw || typeof raw !== "object") continue;
    const item = raw as {name?: unknown; supportedGenerationMethods?: unknown};
    const name = textGenerationModel(item.name);
    if (!name || !Array.isArray(item.supportedGenerationMethods) ||
        !item.supportedGenerationMethods.includes("generateContent")) continue;
    eligible.push(name);
  }
  return [...new Set(eligible)];
}

/** Prefer current models; intersect with this API key's listed capabilities. */
export function candidateModels(
  configured: Array<string | undefined>,
  inventory: readonly string[] | null = null,
  task: "ocr" | "job" = "job",
): string[] {
  const priority = task === "job" ? SUPPORTED_DOCUMENT_FALLBACKS :
    [SAFE_DOCUMENT_MODEL, "gemini-3.8-flash", "gemini-3.1-flash-lite",
      "gemini-3.6-flash"] as const;
  const configuredNames = configured.map(textGenerationModel)
    .filter((name): name is string => name !== null);
  const discovered = inventory?.map(textGenerationModel)
    .filter((name): name is string => name !== null) ?? [];
  const allowed = inventory === null ? null : new Set(discovered);
  const candidates = [...new Set([...priority, ...configuredNames, ...discovered])];
  return candidates.filter((name) => !allowed || allowed.has(name)).slice(0, 4);
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
  if (task === "job") return Array.isArray(data.requirements) &&
    data.requirements.length >= 2;
  const candidate = data.candidate as Record<string, unknown> | null;
  const document = data.document as Record<string, unknown> | null;
  return candidate !== null && typeof candidate === "object" &&
    !Array.isArray(candidate) && !!document && typeof document === "object" &&
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
