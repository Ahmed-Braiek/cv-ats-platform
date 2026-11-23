import pg from 'pg';
import mammoth from 'mammoth';
import { createClient } from '@supabase/supabase-js';
import { EVALUATOR_VERSION, evaluate } from './scoring.mjs';
import { extractCandidate, analyzeJob } from './gemini.mjs';

const { Pool } = pg;
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 2,
  connectionTimeoutMillis: 15000,
  ssl: { rejectUnauthorized: true },
});
const supabase = createClient(
  process.env.SUPABASE_URL ?? '',
  process.env.SUPABASE_SECRET_KEY ?? '',
  { auth: { persistSession: false, autoRefreshToken: false } },
);
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const maxBytes = 10 * 1024 * 1024;

function checkFile(bytes, mime) {
  if (!bytes.length || bytes.length > maxBytes)
    throw new Error('CV outside maximum 10 MiB size');
  const magic = mime === 'application/pdf'
    ? bytes.subarray(0,5).equals(Buffer.from('%PDF-'))
    : mime === 'image/png'
      ? bytes.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]))
      : mime === 'image/jpeg'
        ? bytes.length > 3 && bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255
        : mime === 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
          ? bytes.subarray(0,4).equals(Buffer.from([80,75,3,4])) : false;
  if (!magic) throw new Error('Invalid CV signature');
}

async function claim() {
  const c = await pool.connect();
  try {
    await c.query('BEGIN');
    const r = await c.query(`
      select j.id,j.analysis_id
      from private.analysis_jobs j
      join public.analyses a on a.id=j.analysis_id
      where (j.stage='queued' or (j.stage='retry' and j.retry_at<=now())
             or (j.stage='processing' and j.leased_until<now()))
        and a.status not in ('completed','cancelled','expired')
      order by j.created_at
      limit 1 for update of j skip locked`);
    if (!r.rowCount) { await c.query('COMMIT'); return null; }
    const job = r.rows[0];
    await c.query(`
      update private.analysis_jobs
      set stage='processing', attempts=attempts+1,
          leased_until=now()+interval '3 minutes', retry_at=null
      where id=$1`,[job.id]);
    await c.query('COMMIT');
    return job;
  } catch (err) {
    await c.query('ROLLBACK');
    throw err;
  } finally {
    c.release();
  }
}

async function processJob(job) {
  const c = await pool.connect();
  try {
    const r = await c.query(`
      select a.id,a.user_id,a.cv_id,a.job_description_id,
             cv.storage_path,cv.mime_type, j.raw_text
      from public.analyses a
      join public.cvs cv on cv.id=a.cv_id
      join public.job_descriptions j on j.id=a.job_description_id
      where a.id=$1 and a.status not in ('completed','cancelled','expired')
        and cv.user_id=a.user_id and j.user_id=a.user_id
        and cv.deleted_at is null`, [job.analysis_id]);
    if (r.rowCount !== 1) throw new Error('Analysis input ownership invalid');
    const input = r.rows[0];
    await c.query(`update public.analyses set status='extracting' where id=$1`,
      [job.analysis_id]);
    const file = await supabase.storage.from('cv-private').download(input.storage_path);
    if (file.error || !file.data) throw new Error('Private CV download failed');
    const bytes = Buffer.from(await file.data.arrayBuffer());
    checkFile(bytes, input.mime_type);

    const source = input.mime_type ===
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      ? Buffer.from((await mammoth.extractRawText({ buffer: bytes })).value, 'utf8')
      : bytes;
    const contentType = source === bytes ? input.mime_type : 'text/plain';
    const extracted = await extractCandidate(source,contentType);
    await c.query(`update public.analyses set status='parsing_job' where id=$1`,[job.analysis_id]);
    const jobResult = await analyzeJob(input.raw_text);
    await c.query(`update public.analyses set status='scoring' where id=$1`,[job.analysis_id]);
    const { ats, match, recommendations } = evaluate(
      extracted.json,jobResult.json);
    if (match.overall === null) throw new Error(
      'No explicit job skill requirements: match score cannot be calculated');
    // Save an all-or-nothing result. All public result tables remain client read-only.
    await c.query('BEGIN');
    await c.query(`
      insert into public.candidate_profiles(cv_id,extracted,extraction_model)
      values ($1,$2,$3)
      on conflict(cv_id) do update
      set extracted=excluded.extracted,extraction_model=excluded.extraction_model,
          updated_at=now()`,[input.cv_id,JSON.stringify(extracted.json),extracted.model]);
    await c.query(`
      insert into public.ats_results(analysis_id,overall,rubric_json,evaluator_version)
      values ($1,$2,$3,$4)
      on conflict(analysis_id) do update
      set overall=excluded.overall,rubric_json=excluded.rubric_json,
          evaluator_version=excluded.evaluator_version
      `,[job.analysis_id,ats.overall,JSON.stringify(ats.rubric),EVALUATOR_VERSION]);
    await c.query(`
      insert into public.match_results(analysis_id,overall,rubric_json,evaluator_version)
      values ($1,$2,$3,$4)
      on conflict(analysis_id) do update
      set overall=excluded.overall,rubric_json=excluded.rubric_json,
          evaluator_version=excluded.evaluator_version
      `,[job.analysis_id,match.overall,JSON.stringify(match.rubric),EVALUATOR_VERSION]);
    await c.query(`delete from public.recommendations where analysis_id=$1`,[job.analysis_id]);
    for (const rec of recommendations) await c.query(`
      insert into public.recommendations(analysis_id,priority,category,message)
      values ($1,$2,$3,$4)`,[job.analysis_id,rec.priority,rec.category,rec.message]);
    await c.query(`update public.analyses
      set status='completed',completed_at=now(),evaluator_version=$2,
      failure_code=null where id=$1`,[job.analysis_id,EVALUATOR_VERSION]);
    await c.query(`update private.analysis_jobs
      set stage='completed',leased_until=null where id=$1`,[job.id]);
    await c.query('COMMIT');
  } catch (error) {
    try { await c.query('ROLLBACK'); } catch {}
    throw error;
  } finally { c.release(); }
}
async function failOrRetry(job,error) {
  const status = Number(error?.status ?? 0);
  const code = status === 429 ? 'rate_limited' :
    status >= 500 ? 'ai_unavailable' : 'processing_error';
  const retryAfter = Math.min(3600, Math.max(60,
    Number.parseInt(error?.retryAfter ?? '60', 10) || 60));
  const c=await pool.connect();
  try {
    await c.query('BEGIN');
    const { rows } = await c.query(
      'select attempts from private.analysis_jobs where id=$1 for update',[job.id]);
    const attempts = rows[0]?.attempts ?? 5;
    const retry = attempts < 3 && (status===429 || status>=500 || status===0);
    await c.query(`update private.analysis_jobs
      set stage=$2, retry_at=case when $2='retry' then now()+($3::int * interval '1 second') else null end,
      leased_until=null
      where id=$1`,[job.id,retry?'retry':'failed',retryAfter]);
    await c.query(`update public.analyses
      set status=$2, failure_code=$3 where id=$1`,
      [job.analysis_id,retry?'queued':'failed',code]);
    await c.query('COMMIT');
  } catch (err) { await c.query('ROLLBACK'); throw err; } finally {c.release();}
  console.error('CV job error', {analysisId:job.analysis_id,code});
}
async function main() {
  for (const key of ['DATABASE_URL','SUPABASE_URL','SUPABASE_SECRET_KEY']) {
    if (!process.env[key]) throw new Error(`Missing worker env: ${key}`);
  }
  console.log('CV ATS worker started');
  let stopping=false;
  process.on('SIGTERM',()=>{stopping=true;});
  process.on('SIGINT',()=>{stopping=true;});
  while (!stopping) {
    try {
      const job=await claim();
      if (job) {
        try {await processJob(job);} catch(error){await failOrRetry(job,error);}
      } else await sleep(3000);
    } catch (error) {
      console.error('Worker polling unavailable', {message:error.message});
      await sleep(5000);
    }
  }
  await pool.end();
}
main().catch(err=>{console.error('Worker stopped',err.message);process.exitCode=1;});
