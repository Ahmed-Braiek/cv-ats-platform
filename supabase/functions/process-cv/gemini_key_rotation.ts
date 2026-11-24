/**
 * Route Gemini calls over up to three server-side secrets. No secret values
 * are persisted to Postgres, returned to clients, or written to logs.
 */
export const GEMINI_KEY_NAMES = [
  "GEMINI_API_KEY_PRIMARY",
  "GEMINI_API_KEY_SECONDARY",
  "GEMINI_API_KEY_TERTIARY",
] as const;

export function activeGeminiKeys(
  env: (name: string) => string | undefined,
): string[] {
  return [...new Set(GEMINI_KEY_NAMES
    .map((name) => (env(name) ?? "").trim())
    .filter((key) => key.length > 0))];
}

export function keyAtSlot(keys: readonly string[], slot: number): string {
  if (!Number.isInteger(slot) || slot < 1 || slot > keys.length) {
    throw new Error("gemini_dispatch_unavailable");
  }
  return keys[slot - 1];
}
