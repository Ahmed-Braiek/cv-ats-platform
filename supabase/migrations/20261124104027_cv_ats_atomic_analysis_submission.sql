-- CV ATS: create the job description and analysis atomically.
-- SECURITY INVOKER preserves Supabase RLS and the database quota trigger.
CREATE OR REPLACE FUNCTION public.cv_ats_submit_analysis(
  p_cv_id uuid,
  p_job_description text,
  p_job_title text DEFAULT NULL
)
RETURNS TABLE(id uuid, status text, created_at timestamptz)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $function$
DECLARE
  v_user_id uuid;
  v_job_id uuid;
  v_analysis_id uuid;
  v_description text;
  v_title text;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'sign_in_required' USING ERRCODE = '42501';
  END IF;
  IF p_cv_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.cvs c
    WHERE c.id = p_cv_id AND c.user_id = v_user_id AND c.deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'cv_not_found' USING ERRCODE = '22023';
  END IF;

  v_description := pg_catalog.btrim(p_job_description);
  v_title := nullif(pg_catalog.btrim(p_job_title), '');
  IF v_description IS NULL OR pg_catalog.char_length(v_description) NOT BETWEEN 20 AND 16000 THEN
    RAISE EXCEPTION 'job_description_length_invalid' USING ERRCODE = '22023';
  END IF;
  IF v_title IS NOT NULL AND pg_catalog.char_length(v_title) > 200 THEN
    RAISE EXCEPTION 'job_title_length_invalid' USING ERRCODE = '22023';
  END IF;

  -- Quota failure on the analysis INSERT also rolls back the job description.
  INSERT INTO public.job_descriptions AS j (user_id, title, raw_text)
    VALUES (v_user_id, v_title, v_description)
    RETURNING j.id INTO v_job_id;

  INSERT INTO public.analyses AS a (user_id, cv_id, job_description_id, status)
    VALUES (v_user_id, p_cv_id, v_job_id, 'queued')
    RETURNING a.id INTO v_analysis_id;

  RETURN QUERY
    SELECT a.id, a.status, a.created_at
    FROM public.analyses a WHERE a.id = v_analysis_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.cv_ats_submit_analysis(uuid, text, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cv_ats_submit_analysis(uuid, text, text)
  TO authenticated;
COMMENT ON FUNCTION public.cv_ats_submit_analysis(uuid, text, text)
  IS 'RLS-protected transactional submission: quota rejection rolls back the job description.';
