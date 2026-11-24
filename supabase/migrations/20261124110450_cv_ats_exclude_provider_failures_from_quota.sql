-- Provider-side Gemini failures do not consume monthly analysis credits.
-- Retains authenticated ownership, plan checks, serialization and queue limits.
CREATE OR REPLACE FUNCTION private.cv_ats_enforce_analysis_quota()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  allowed_monthly integer;
  used_monthly integer;
  pending_count integer;
BEGIN
  IF auth.uid() IS NULL OR new.user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'analysis requires an authenticated owner'
      USING errcode = '42501';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(new.user_id::text, 0)
  );

  SELECT p.monthly_analysis_limit INTO allowed_monthly
  FROM public.subscriptions s
  JOIN public.subscription_plans p ON p.id = s.plan_id
  WHERE s.user_id = new.user_id
    AND s.status IN ('active','trialing')
    AND s.starts_at <= now()
    AND (s.renews_at IS NULL OR s.renews_at > now())
  ORDER BY s.created_at DESC LIMIT 1;

  IF allowed_monthly IS NULL THEN
    RAISE EXCEPTION 'no active subscription' USING errcode = '42501';
  END IF;

  SELECT count(*) INTO used_monthly
  FROM public.analyses a
  WHERE a.user_id = new.user_id
    AND a.created_at >= date_trunc('month', now())
    AND a.created_at < date_trunc('month', now()) + interval '1 month'
    AND NOT (
      a.status = 'failed'
      AND a.failure_code IN (
        'gemini_unavailable', 'gemini_model_unavailable',
        'gemini_config_error', 'gemini_not_configured',
        'gemini_dispatch_unavailable', 'rate_limited'
      )
    );

  IF used_monthly >= allowed_monthly THEN
    RAISE EXCEPTION 'monthly analysis quota exceeded' USING errcode = '23514';
  END IF;

  SELECT count(*) INTO pending_count
  FROM public.analyses a
  WHERE a.user_id = new.user_id
    AND a.status IN ('queued','extracting','parsing_job','scoring','recommending');

  IF pending_count >= 2 THEN
    RAISE EXCEPTION 'too many outstanding analyses' USING errcode = '23514';
  END IF;
  RETURN new;
END
$function$
;
