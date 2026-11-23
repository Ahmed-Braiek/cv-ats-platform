-- Candidate CV removal may only be performed via authenticated Edge gateway.
-- Service-role caller provides the actor ID after verifying a Supabase token.
drop function if exists public.cv_ats_delete_own_cv(uuid);
create or replace function public.cv_ats_delete_owned_cv(p_actor uuid,p_cv_id uuid)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_path text; removed integer;
begin
 if p_actor is null or p_cv_id is null then raise exception 'invalid_request';end if;
 select storage_path into v_path from public.cvs
 where id=p_cv_id and user_id=p_actor and deleted_at is null for update;
 if v_path is null then raise exception 'cv_not_found';end if;
 if exists(select 1 from storage.objects
   where bucket_id='cv-private' and name=v_path) then
   raise exception 'remove_private_file_first';
 end if;
 delete from private.analysis_jobs where analysis_id in
   (select id from public.analyses where cv_id=p_cv_id and user_id=p_actor);
 delete from private.temporary_analysis_claims where analysis_id in
   (select id from public.analyses where cv_id=p_cv_id and user_id=p_actor);
 delete from public.analyses where cv_id=p_cv_id and user_id=p_actor;
 get diagnostics removed=row_count;
 delete from public.cvs where id=p_cv_id and user_id=p_actor;
 delete from public.job_descriptions jd where jd.user_id=p_actor
   and not exists(select 1 from public.analyses a where a.job_description_id=jd.id);
 return jsonb_build_object('deleted',true,'analyses_removed',removed);
end $$;
revoke all on function public.cv_ats_delete_owned_cv(uuid,uuid) from public,anon,authenticated;
grant execute on function public.cv_ats_delete_owned_cv(uuid,uuid) to service_role;