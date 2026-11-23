CREATE OR REPLACE FUNCTION public.cv_ats_admin_overview()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select jsonb_build_object(
  'users',(select count(*) from public.profiles),
  'new_users_30d',(select count(*) from public.profiles where created_at>=now()-interval '30 days'),
  'verified_users',(select count(*) from auth.users where email_confirmed_at is not null),
  'stored_cvs',(select count(*) from public.cvs where deleted_at is null),
  'analyses',(select count(*) from public.analyses),
  'analyses_30d',(select count(*) from public.analyses where created_at>=now()-interval '30 days'),
  'completed',(select count(*) from public.analyses where status='completed'),
  'failed',(select count(*) from public.analyses where status='failed'),
  'processing',(select count(*) from public.analyses where status in ('queued','extracting','parsing_job','scoring','recommending')),
  'average_ats',(select round(avg(overall)::numeric,1) from public.ats_results where evaluator_version='ats-match-v0.2'),
  'average_match',(select round(avg(overall)::numeric,1) from public.match_results where evaluator_version='ats-match-v0.2'),
  'evaluator_versions',coalesce((select jsonb_agg(to_jsonb(t)) from (select coalesce(evaluator_version,'unknown') as version,count(*)::int as total from public.analyses group by 1 order by 1) t),'[]'::jsonb),
  'subscriptions',coalesce((
    select jsonb_agg(to_jsonb(t)) from (
      select pl.code,count(*)::int as count from public.subscriptions s
      join public.subscription_plans pl on pl.id=s.plan_id
      where s.status='active' group by pl.code order by pl.code
    ) t
  ),'[]'::jsonb),
  'trend',coalesce((
    select jsonb_agg(to_jsonb(t) order by t.day) from (
      select to_char(a.created_at at time zone 'UTC','YYYY-MM-DD') as day,
       count(*)::int as total,
       count(*) filter(where a.status='completed')::int as completed
      from public.analyses a where a.created_at >=now()-interval '14 days'
      group by 1 order by 1
    ) t
  ),'[]'::jsonb),
  'recent_failures',coalesce((
    select jsonb_agg(to_jsonb(t)) from (
      select failure_code,count(*)::int as count from public.analyses
      where status='failed' and created_at>=now()-interval '30 days'
      group by failure_code order by count(*) desc limit 5
    ) t
  ),'[]'::jsonb)
 )
$function$;
