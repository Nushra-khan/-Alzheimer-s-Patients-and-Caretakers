begin;

create function public.revoke_caregiver_access(
  target_patient_id uuid,
  target_caregiver_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  target_relationship_id uuid;
begin
  if auth.uid() is null or not private.owns_patient(target_patient_id) then
    raise exception 'patient access required' using errcode = '42501';
  end if;

  select id into target_relationship_id
  from public.care_relationships
  where patient_id = target_patient_id
    and caregiver_id = target_caregiver_id
    and status = 'active'
  for update;

  if target_relationship_id is null then
    raise exception 'active caregiver relationship not found'
      using errcode = 'P0002';
  end if;

  update public.care_relationships
  set status = 'revoked',
      valid_until = now()
  where id = target_relationship_id;

  insert into public.audit_events (
    actor_profile_id,
    action,
    resource_type,
    resource_id,
    metadata
  ) values (
    auth.uid(),
    'caregiver_access_revoked',
    'care_relationship',
    target_relationship_id,
    jsonb_build_object(
      'patient_id', target_patient_id,
      'caregiver_id', target_caregiver_id
    )
  );
end;
$$;

revoke all on function public.revoke_caregiver_access(uuid, uuid) from public;
grant execute on function public.revoke_caregiver_access(uuid, uuid) to authenticated;

commit;
