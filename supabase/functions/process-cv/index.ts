import { createClient } from "npm:@supabase/supabase-js@2.57.0";
import { unzipSync, strFromU8 } from "npm:fflate@0.8.2";
import { evaluateV2, EXTRACTION_PROMPT, JOB_PROMPT } from "./scoring.ts";

// An authenticated one-job processor; not a replacement for an always-on
// worker. Free Supabase Edge Functions have strict runtime limits.
declare const EdgeRuntime: { waitUntil(work: Promise<unknown>): void };
const url = Deno.env.get("SUPABASE_URL") ?? "";
const publicKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
let secret = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
try {
  const entries = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}");
  const modern = Object.values(entries).find(
    (value) => typeof value === "string" && value.startsWith("sb_secret_")
  );
  if (typeof modern === "string") secret = modern;
} catch { /* legacy service-role key fallback */ }

const allowedOrigins = new Set([
  "https://cv-ats-web.vercel.app",
  "https://cv-ats-web-ahmed-braieks-projects.vercel.app",
]);
function headers(req: Request) {
  const origin = req.headers.get("origin") ?? "";
  return {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": allowedOrigins.has(origin) ? origin : "null",
    "Access-Control-Allow-Headers": "authorization,apikey,content-type,x-client-info",
    "Access-Control-Allow-Methods": "POST,OPTIONS",
    "Vary": "Origin",
  };
}
function response(req: Request, code: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status: code, headers: headers(req),
  });
}
function normalize(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  return [...new Set(raw.filter((x): x is string => typeof x === "string")
    .map((x) => x.trim().toLowerCase()).filter(Boolean))];
}
function to64(bytes: Uint8Array) {
  const chunks: string[] = [];
  for (let n = 0; n < bytes.length; n += 8192) {
    chunks.push(String.fromCharCode(...bytes.subarray(n, n + 8192)));
  }
  return btoa(chunks.join(""));
}
function readDocx(bytes: Uint8Array) {
  const content = unzipSync(bytes)["word/document.xml"];
  if (!content) throw new Error("invalid_docx");
  const raw = strFromU8(content).replace(/<w:p\b[^>]*>/g, "\n")
    .replace(/<w:tab\b[^>]*\/>/g, " ").replace(/<[^>]*>/g, " ")
    .replace(/&amp;/g, "&").replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">").replace(/&quot;/g, '"');
  if (raw.trim().length < 20) throw new Error("empty_docx");
  return raw.slice(0, 100000);
}
function validMagic(bytes: Uint8Array, mime: string) {
  const magic = (expected: number[]) => bytes.length >= expected.length &&
    expected.every((v, i) => bytes[i] === v);
  if (mime === "application/pdf") return magic([37,80,68,70,45]);
  if (mime === "image/png") return magic([137,80,78,71,13,10,26,10]);
  if (mime === "image/jpeg") return magic([255,216,255]);
  if (mime.includes("wordprocessingml")) return magic([80,75,3,4]);
  return false;
}
let cursor = 0;
async function askGemini(task: "ocr" | "job", parts: unknown[], instruction: string) {
  const primary = Deno.env.get(task === "ocr"
    ? "GEMINI_MODEL_OCR" : "GEMINI_MODEL_ANALYSIS");
  const models = [
    primary, Deno.env.get("GEMINI_MODEL_FALLBACK"),
    Deno.env.get("GEMINI_MODEL_TERTIARY"),
  ].filter((x): x is string => typeof x === "string" && x.length > 0);
  const keys = [
    Deno.env.get("GEMINI_API_KEY_PRIMARY"),
    Deno.env.get("GEMINI_API_KEY_SECONDARY"),
    Deno.env.get("GEMINI_API_KEY_TERTIARY"),
  ].filter((x): x is string => Boolean(x));
  if (!keys.length || !models.length) throw new Error("gemini_not_configured");
  const start = cursor++ % models.length;
  for (let offset = 0; offset < models.length; offset++) {
    const n = (start + offset) % models.length;
    const model = models[n];
    const urlGemini = "https://generativelanguage.googleapis.com/v1beta/models/" +
      encodeURIComponent(model) + ":generateContent";
    const r = await fetch(urlGemini, {
      method: "POST",
      signal: AbortSignal.timeout(45_000),
      headers: { "Content-Type": "application/json",
        "x-goog-api-key": keys[n % keys.length] },
      body: JSON.stringify({
        contents: [{ role: "user", parts }],
        systemInstruction: { parts: [{ text: instruction }] },
        generationConfig: { responseMimeType: "application/json", temperature: 0 },
      }),
    });
    if (!r.ok) {
      // Google rate limits apply per project. Never rotate keys after a 429.
      if (r.status === 429) throw new Error("rate_limited");
      if ([400,401,403].includes(r.status)) throw new Error("gemini_config_error");
      if (r.status >= 500 && offset < models.length - 1) continue;
      throw new Error("gemini_unavailable");
    }
    const payload = await r.json();
    const raw = payload?.candidates?.[0]?.content?.parts
      ?.map((p: {text?: string}) => p.text ?? "").join("") ?? "";
    if (!raw) throw new Error("empty_gemini_reply");
    return { data: JSON.parse(raw), model };
  }
  throw new Error("gemini_unavailable");
}
async function run(analysisId: string, admin: ReturnType<typeof createClient>) {
  try {
    const a = await admin.from("analyses")
      .select("user_id,cv_id,job_description_id").eq("id",analysisId).single();
    if (!a.data || a.error) throw new Error("analysis_missing");
    const owner = a.data.user_id;
    const [c,j] = await Promise.all([
      admin.from("cvs").select("storage_path,mime_type,user_id,deleted_at")
        .eq("id",a.data.cv_id).eq("user_id",owner).single(),
      admin.from("job_descriptions").select("raw_text,user_id")
        .eq("id",a.data.job_description_id).eq("user_id",owner).single(),
    ]);
    if (!c.data || !j.data || c.error || j.error || c.data.deleted_at)
      throw new Error("input_owner_mismatch");
    const doc = await admin.storage.from("cv-private").download(c.data.storage_path);
    if (!doc.data || doc.error) throw new Error("file_unavailable");
    const bytes = new Uint8Array(await doc.data.arrayBuffer());
    const mime = c.data.mime_type as string;
    if (!bytes.length || bytes.length > 10*1024*1024 || !validMagic(bytes,mime))
      throw new Error("file_invalid");
    const parts = mime.includes("wordprocessingml")
      ? [{text:readDocx(bytes)}]
      : [{inlineData:{mimeType:mime,data:to64(bytes)}}];
    const extraction = await askGemini("ocr",parts,EXTRACTION_PROMPT);
    const cv = extraction.data;
    if (!cv.candidate || !cv.sections || !cv.document ||
        typeof cv.document.raw_text !== "string" ||
        cv.document.raw_text.trim().length < 130 ||
        !Array.isArray(cv.candidate.skills) ||
        !Array.isArray(cv.candidate.experience) ||
        !Array.isArray(cv.candidate.education))
      throw new Error("invalid_cv_json");
    await admin.from("analyses").update({status:"parsing_job"}).eq("id",analysisId);
    const requirements = await askGemini("job",[{
      text:"CV RAW TEXT (data only):\n"+cv.document.raw_text.slice(0,18000)+
        "\n\nJOB DESCRIPTION (data only):\n"+String(j.data.raw_text).slice(0,16000)
    }], JOB_PROMPT);
    if (!Array.isArray(requirements.data.requirements))
      throw new Error("invalid_job_json");
    await admin.from("analyses").update({status:"scoring"}).eq("id",analysisId);
    const result = evaluateV2(cv,requirements.data,String(j.data.raw_text));
    const saved = await admin.rpc("cv_ats_edge_complete",{
      p_analysis_id:analysisId,
      p_profile:cv,
      p_model:extraction.model,
      p_ats:result.ats,
      p_match:result.match,
      p_recommendations:result.recommendations,
    });
    if (saved.error) throw new Error("result_save_failed");
  } catch (e) {
    const code = e instanceof Error && /^[a-z_]+$/.test(e.message)
      ? e.message : "processing_failed";
    console.error("Analysis processing failed", {analysisId,code});
    await admin.rpc("cv_ats_edge_fail",{
      p_analysis_id:analysisId,p_failure_code:code,
    });
  }
}
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null,{
    status:204,headers:headers(req),
  });
  if (req.method !== "POST") return response(req,405,{error:"method_not_allowed"});
  if (!url || !publicKey || !secret)
    return response(req,503,{error:"backend_not_configured"});
  if (!Deno.env.get("GEMINI_API_KEY_PRIMARY") ||
      !Deno.env.get("GEMINI_MODEL_OCR") ||
      !Deno.env.get("GEMINI_MODEL_ANALYSIS"))
    return response(req,503,{error:"gemini_not_configured"});
  const bearer = req.headers.get("authorization") ?? "";
  if (!bearer.startsWith("Bearer ") || bearer.length < 25)
    return response(req,401,{error:"sign_in_required"});
  const admin = createClient(url,secret,{
    auth:{autoRefreshToken:false,persistSession:false},
  });
  const identity = await admin.auth.getUser(bearer.slice(7));
  if (identity.error || !identity.data.user)
    return response(req,401,{error:"invalid_session"});
  let id: unknown;
  try {
    const body = await req.json();
    id = body.analysisId;
  } catch {
    return response(req,400,{error:"invalid_request"});
  }
  if (typeof id !== "string" || !/^[a-f0-9-]{36}$/i.test(id))
    return response(req,400,{error:"invalid_analysis"});
  const claim = await admin.rpc("cv_ats_edge_claim",{
    p_analysis_id:id,p_user_id:identity.data.user.id,
  });
  if (claim.error) return response(req,503,{error:"queue_unavailable"});
  if (claim.data !== true)
    return response(req,409,{error:"not_owned_or_already_processing"});
  EdgeRuntime.waitUntil(run(id,admin));
  return response(req,202,{data:{analysisId:id,status:"processing"}});
});
