/**
 * Gemini REST adapter using built-in fetch to avoid shipping secrets into Flutter.
 * Configure compatible model IDs through environment variables; no model ID is assumed free.
 * Project quotas are shared across API keys. A 429 always stops this attempt; never
 * rotate credentials to evade project-level rate limits.
 */
const API_BASE = 'https://generativelanguage.googleapis.com/v1beta/models';
const DEFAULT_TIMEOUT_MS = 65_000;

function configurations(kind) {
  const ids = (kind === 'extract'
    ? [process.env.GEMINI_MODEL_OCR, process.env.GEMINI_MODEL_FALLBACK, process.env.GEMINI_MODEL_TERTIARY]
    : [process.env.GEMINI_MODEL_ANALYSIS, process.env.GEMINI_MODEL_FALLBACK, process.env.GEMINI_MODEL_TERTIARY]).filter(Boolean);
  const keys = [
    process.env.GEMINI_API_KEY_PRIMARY,
    process.env.GEMINI_API_KEY_SECONDARY,
    process.env.GEMINI_API_KEY_TERTIARY,
  ].filter(Boolean);
  if (!keys.length || !ids.length) throw new Error('Gemini models/API keys are not configured');
  // Each entry can be configured to a different provider project but that alone
  // does not imply independent quotas or permission to exceed a project limit.
  return ids.map((model, index) => ({ model, key: keys[index % keys.length] }));
}
const nextIndex = new Map();

export async function generateJson(kind, parts, instruction) {
  const candidates = configurations(kind);
  const start = nextIndex.get(kind) ?? 0;
  nextIndex.set(kind, (start + 1) % candidates.length);
  for (let offset = 0; offset < candidates.length; offset++) {
    const { model, key } = candidates[(start + offset) % candidates.length];
    const aborter = new AbortController();
    const timer = setTimeout(() => aborter.abort(), DEFAULT_TIMEOUT_MS);
    try {
      const response = await fetch(
        `${API_BASE}/${encodeURIComponent(model)}:generateContent`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': key,
          },
          signal: aborter.signal,
          body: JSON.stringify({
            contents: [{ role: 'user', parts }],
            systemInstruction: { parts: [{ text: instruction }] },
            generationConfig: {
              responseMimeType: 'application/json',
              temperature: 0,
            },
          }),
        },
      );
      if (!response.ok) {
        const text = (await response.text()).slice(0, 600);
        const error = new Error(`Gemini status ${response.status}: ${text}`);
        error.status = response.status;
        error.retryAfter = response.headers.get('retry-after');
        // Rate limits apply at project level. Do not try alternate keys.
        if (response.status === 429) throw error;
        // Authentication/config issues are not solved by cycling models.
        if ([400, 401, 403].includes(response.status)) throw error;
        // Only transient server errors permit a compatible fallback.
        if (response.status >= 500 && offset < candidates.length - 1) continue;
        throw error;
      }
      const payload = await response.json();
      const output = payload?.candidates?.[0]?.content?.parts
        ?.map(item => item.text ?? '').join('') ?? '';
      if (!output) throw new Error('Gemini returned no textual JSON result');
      const json = JSON.parse(output);
      return { json, model };
    } finally {
      clearTimeout(timer);
    }
  }
  throw new Error('No Gemini model was available');
}

export async function extractCandidate(bytes, mime) {
  const instruction = [
    'Read the attached CV. Return strictly JSON.',
    'Do not invent any claims. Use null or an empty array if unavailable.',
    'Schema: {"candidate":{"name":string|null,"email":string|null,',
    '"skills":string[],"experience":object[],"education":object[]},',
    '"sections":{"skills":boolean,"experience":boolean,"education":boolean,',
    '"standard_headings":boolean,"selectable_text":boolean}}.',
    'Keep original skill terminology, without adding inferred skills.',
    'For images/scanned PDFs, selectable_text should be false.',
  ].join(' ');
  const input = mime === 'text/plain'
    ? [{ text: bytes.toString('utf8') }]
    : [{ inlineData: { mimeType: mime, data: bytes.toString('base64') } }];
  const result = await generateJson('extract', input, instruction);
  const c = result.json;
  if (!c || typeof c !== 'object' || !c.candidate ||
      !Array.isArray(c.candidate.skills) || !c.sections ||
      typeof c.sections !== 'object') {
    throw new Error('Gemini candidate extraction failed schema validation');
  }
  return result;
}

export async function analyzeJob(text) {
  const instruction = [
    'Read this job description and extract ONLY explicit skills.',
    'Return strictly JSON: {"required_skills":string[], "preferred_skills":string[]}.',
    'Do not infer missing requirements or include unrelated words.',
    'The same skill must not appear in both arrays.',
  ].join(' ');
  const result = await generateJson('analysis', [{ text }], instruction);
  const x = result.json;
  if (!x || !Array.isArray(x.required_skills) || !Array.isArray(x.preferred_skills))
    throw new Error('Gemini job extraction failed schema validation');
  return result;
}
