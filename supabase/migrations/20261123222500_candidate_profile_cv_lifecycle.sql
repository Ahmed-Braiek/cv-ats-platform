-- Self-service profile editing without any ability to update role.
grant update(display_name) on public.profiles to authenticated;
drop policy if exists "edit own display name" on public.profiles;
create policy "edit own display name" on public.profiles
for update to authenticated
using ((select auth.uid())=id)
with check ((select auth.uid())=id);

-- Delete CV metadata and associated results only after the Storage API
-- actually removed the object. The actor can only delete their own CV.
create or replace function public.cv_ats_delete_own_cv(p_cv_id uuid)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_user uuid:=auth.uid(); v_path text; removed integer;
begin
 if v_user is null then raise exception 'authentication_required';end if;
 select storage_path into v_path from public.cvs
 where id=p_cv_id and user_id=v_user and deleted_at is null for update;
 if v_path is null then raise exception 'cv_not_found';end if;
 if exists(select 1 from storage.objects
   where bucket_id='cv-private' and name=v_path) then
   raise exception 'remove_private_file_first';
 end if;
 delete from private.analysis_jobs where analysis_id in
   (select id from public.analyses where cv_id=p_cv_id);
 delete from private.temporary_analysis_claims where analysis_id in
   (select id from public.analyses where cv_id=p_cv_id);
 delete from public.analyses where cv_id=p_cv_id and user_id=v_user;
 get diagnostics removed=row_count;
 delete from public.cvs where id=p_cv_id and user_id=v_user;
 delete from public.job_descriptions jd where jd.user_id=v_user
   and not exists(select 1 from public.analyses a where a.job_description_id=jd.id);
 return jsonb_build_object('deleted',true,'analyses_removed',removed);
end $$;
revoke all on function public.cv_ats_delete_own_cv(uuid)
 from public,anon,authenticated;
grant execute on function public.cv_ats_delete_own_cv(uuid) to authenticated;
