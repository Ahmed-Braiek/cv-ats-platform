CREATE OR REPLACE FUNCTION public.cv_ats_admin_users(p_search text DEFAULT ''::text, p_offset integer DEFAULT 0, p_limit integer DEFAULT 20)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
       u.email,u.email_confirmed_at,u.last_sign_in_at,
       case when u.banned_until > now() then 'suspended' else 'active' end as account_status,
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
end $function$

drop policy if exists admin_audit_service_only on public.admin_audit_events;
create policy admin_audit_service_only on public.admin_audit_events
for all to service_role using (true) with check (true);
