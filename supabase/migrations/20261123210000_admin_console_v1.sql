
-- Admin v1: RLS-protected audit history and service-role-only reporting/actions.
create table if not exists public.admin_audit_events (
  id bigint generated always as identity primary key,
  actor_id uuid not null,
  target_id uuid,
  action text not null check (char_length(action) between 3 and 80),
  reason text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
alter table public.admin_audit_events enable row level security;
revoke all on public.admin_audit_events from public, anon, authenticated;
revoke all on sequence public.admin_audit_events_id_seq from public, anon, authenticated;
grant select,insert on public.admin_audit_events to service_role;
grant usage,select on sequence public.admin_audit_events_id_seq to service_role;
create index if not exists admin_audit_events_date_idx on public.admin_audit_events(created_at desc);
create index if not exists admin_audit_events_target_idx on public.admin_audit_events(target_id,created_at desc);

create or replace function public.cv_ats_admin_users(p_search text default '', p_offset integer default 0, p_limit integer default 20)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare q text := left(trim(coalesce(p_search,'')),100); result jsonb;
begin
 if p_offset < 0 or p_offset > 100000 or p_limit < 1 or p_limit > 50 then
   raise exception 'invalid_pagination';
 end if;
 select jsonb_build_object(
   'total',(select count(*) from public.profiles p
     join auth.users u on u.id=p.id
     where q='' or p.display_name ilike '%'||q||'%'
       or u.email ilike '%'||q||'%' or p.id::text=q),
   'items',coalesce((select jsonb_agg(to_jsonb(t)) from (
     select p.id,p.display_name,p.role,p.created_at,
       u.email,u.email_confirmed_at,
       coalesce(sub.plan_code,'free') as plan_code,
       coalesce(sub.subscription_status,'none') as subscription_status,
       (select count(*) from public.analyses a where a.user_id=p.id) as analysis_count,
       (select count(*) from public.cvs cv where cv.user_id=p.id and cv.deleted_at is null) as cv_count
     from public.profiles p
     join auth.users u on u.id=p.id
     left join lateral (
       select pl.code as plan_code,s.status as subscription_status
       from public.subscriptions s
       join public.subscription_plans pl on pl.id=s.plan_id
       where s.user_id=p.id and s.status in ('active','trialing')
       order by s.created_at desc limit 1
     ) sub on true
     where q='' or p.display_name ilike '%'||q||'%'
       or u.email ilike '%'||q||'%' or p.id::text=q
     order by p.created_at desc,p.id
     limit p_limit offset p_offset
   ) t),'[]'::jsonb)
 ) into result;
 return result;
end $$;

create or replace function public.cv_ats_admin_analyses(p_status text default '',p_offset integer default 0,p_limit integer default 20)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare result jsonb;
begin
 if p_offset<0 or p_offset>100000 or p_limit<1 or p_limit>50 or length(coalesce(p_status,''))>40 then
   raise exception 'invalid_pagination';
 end if;
 select jsonb_build_object(
   'total',(select count(*) from public.analyses where p_status='' or status=p_status),
   'items',coalesce((select jsonb_agg(to_jsonb(t)) from (
     select a.id,a.user_id,a.created_at,a.completed_at,a.status,
       a.evaluator_version,a.failure_code,
       u.email as user_email,
       jd.title as job_title,
       at.overall as ats_score,ma.overall as match_score
     from public.analyses a
     left join auth.users u on u.id=a.user_id
     left join public.job_descriptions jd on jd.id=a.job_description_id
     left join public.ats_results at on at.analysis_id=a.id
     left join public.match_results ma on ma.analysis_id=a.id
     where p_status='' or a.status=p_status
     order by a.created_at desc,a.id limit p_limit offset p_offset
   ) t),'[]'::jsonb)
 ) into result;
 return result;
end $$;

create or replace function public.cv_ats_admin_overview()
returns jsonb language sql stable security definer set search_path=''
as $$
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
  'average_ats',(select round(avg(overall)::numeric,1) from public.ats_results),
  'average_match',(select round(avg(overall)::numeric,1) from public.match_results),
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
$$;

create or replace function public.cv_ats_admin_grant_plan(p_actor uuid,p_target uuid,p_plan_code text,p_reason text)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare plan_id uuid; existing_plan text;
begin
 if p_actor=p_target or trim(coalesce(p_reason,''))='' or length(p_reason)>500 then
   raise exception 'invalid_request';
 end if;
 if not exists(select 1 from public.profiles where id=p_actor and role='admin') then
   raise exception 'admin_required';
 end if;
 perform 1 from public.profiles where id=p_target and role='candidate' for update;
 if not found then raise exception 'candidate_not_found';end if;
 select id into plan_id from public.subscription_plans
 where code=p_plan_code and active=true;
 if plan_id is null then raise exception 'plan_not_found';end if;
 select pl.code into existing_plan from public.subscriptions s
 join public.subscription_plans pl on pl.id=s.plan_id
 where s.user_id=p_target and s.status='active'
 order by s.created_at desc limit 1;
 if existing_plan=p_plan_code then
   return jsonb_build_object('status','unchanged','plan',p_plan_code);
 end if;
 update public.subscriptions set status='cancelled'
 where user_id=p_target and status in ('active','trialing');
 insert into public.subscriptions(user_id,plan_id,status,starts_at,renews_at)
 values(p_target,plan_id,'active',now(),null);
 insert into public.admin_audit_events(actor_id,target_id,action,reason,details)
 values(p_actor,p_target,'subscription.manual_change',left(p_reason,500),
  jsonb_build_object('from',existing_plan,'to',p_plan_code,'billing','not_charged'));
 return jsonb_build_object('status','updated','plan',p_plan_code);
end $$;

create or replace function public.cv_ats_admin_update_plan(
 p_actor uuid,p_code text,p_monthly integer,p_saved integer,
 p_history integer,p_export boolean,p_reason text)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare previous jsonb;
begin
 if not exists(select 1 from public.profiles where id=p_actor and role='admin') then
   raise exception 'admin_required';
 end if;
 if p_code not in ('free','premium') or p_monthly not between 1 and 10000
 or p_saved not between 1 and 10000
 or (p_history is not null and p_history not between 1 and 3650)
 or trim(coalesce(p_reason,''))='' or length(p_reason)>500 then
   raise exception 'invalid_plan';
 end if;
 select to_jsonb(pl) into previous from public.subscription_plans pl
 where pl.code=p_code for update;
 if previous is null then raise exception 'plan_not_found';end if;
 update public.subscription_plans set monthly_analysis_limit=p_monthly,
 saved_cv_limit=p_saved,history_days=p_history,pdf_export_enabled=p_export
 where code=p_code;
 insert into public.admin_audit_events(actor_id,action,reason,details)
 values(p_actor,'plan.limits_updated',left(p_reason,500),
  jsonb_build_object('code',p_code,'before',jsonb_build_object(
  'monthly',previous->'monthly_analysis_limit','saved',previous->'saved_cv_limit',
  'history',previous->'history_days','pdf',previous->'pdf_export_enabled'),
  'after',jsonb_build_object('monthly',p_monthly,'saved',p_saved,
  'history',p_history,'pdf',p_export)));
 return jsonb_build_object('status','updated','plan',p_code);
end $$;

-- Deletes dependent app data only AFTER Storage API cleanup has succeeded.
-- The caller must then call auth.admin.deleteUser. Not transactional across Auth.
create or replace function public.cv_ats_admin_purge_candidate(p_actor uuid,p_target uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare role_value text; deleted_analyses integer;
begin
 if p_actor=p_target or trim(coalesce(p_reason,''))='' or length(p_reason)>500
 then raise exception 'invalid_request';end if;
 if not exists(select 1 from public.profiles where id=p_actor and role='admin')
 then raise exception 'admin_required';end if;
 select role into role_value from public.profiles where id=p_target for update;
 if role_value='admin' then raise exception 'admin_deletion_forbidden';end if;
 -- A missing profile may be a retry after an earlier partial Auth API failure.
 delete from private.analysis_jobs where analysis_id in
 (select id from public.analyses where user_id=p_target or cv_id in
  (select id from public.cvs where user_id=p_target));
 delete from private.temporary_analysis_claims where analysis_id in
 (select id from public.analyses where user_id=p_target or cv_id in
  (select id from public.cvs where user_id=p_target));
 delete from public.analyses where user_id=p_target or cv_id in
 (select id from public.cvs where user_id=p_target);
 get diagnostics deleted_analyses=row_count;
 delete from public.job_descriptions where user_id=p_target;
 delete from public.cvs where user_id=p_target;
 delete from public.subscriptions where user_id=p_target;
 delete from public.profiles where id=p_target;
 insert into public.admin_audit_events(actor_id,target_id,action,reason,details)
 values(p_actor,p_target,'account.data_purged',left(p_reason,500),
   jsonb_build_object('analyses_removed',deleted_analyses));
 return jsonb_build_object('status','data_purged','analyses_removed',deleted_analyses);
end $$;

-- All admin definer functions are callable by the service role ONLY.
revoke all on function public.cv_ats_admin_users(text,integer,integer) from public,anon,authenticated;
revoke all on function public.cv_ats_admin_analyses(text,integer,integer) from public,anon,authenticated;
revoke all on function public.cv_ats_admin_overview() from public,anon,authenticated;
revoke all on function public.cv_ats_admin_grant_plan(uuid,uuid,text,text) from public,anon,authenticated;
revoke all on function public.cv_ats_admin_update_plan(uuid,text,integer,integer,integer,boolean,text) from public,anon,authenticated;
revoke all on function public.cv_ats_admin_purge_candidate(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.cv_ats_admin_users(text,integer,integer) to service_role;
grant execute on function public.cv_ats_admin_analyses(text,integer,integer) to service_role;
grant execute on function public.cv_ats_admin_overview() to service_role;
grant execute on function public.cv_ats_admin_grant_plan(uuid,uuid,text,text) to service_role;
grant execute on function public.cv_ats_admin_update_plan(uuid,text,integer,integer,integer,boolean,text) to service_role;
grant execute on function public.cv_ats_admin_purge_candidate(uuid,uuid,text) to service_role;
