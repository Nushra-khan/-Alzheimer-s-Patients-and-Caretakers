begin;

create function public.deactivate_medication(
  target_patient_id uuid,
  target_medication_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  target_medication_name text;
begin
  if auth.uid() is null or not private.is_active_caregiver(target_patient_id) then
    raise exception 'caregiver access required' using errcode = '42501';
  end if;

  select name into target_medication_name
  from public.medications
  where id = target_medication_id
    and patient_id = target_patient_id
    and active = true
  for update;

  if target_medication_name is null then
    raise exception 'active medication not found' using errcode = 'P0002';
  end if;

  update public.medications
  set active = false
  where id = target_medication_id;

  update public.medication_schedules
  set active = false
  where medication_id = target_medication_id
    and active = true;

  update public.dose_instances
  set status = 'skipped'
  where patient_id = target_patient_id
    and schedule_id in (
      select id
      from public.medication_schedules
      where medication_id = target_medication_id
    )
    and status = 'scheduled'
    and scheduled_for > now();

  insert into public.audit_events (
    actor_profile_id,
    action,
    resource_type,
    resource_id,
    metadata
  ) values (
    auth.uid(),
    'medication_deactivated',
    'medication',
    target_medication_id,
    jsonb_build_object(
      'patient_id', target_patient_id,
      'medication_name', target_medication_name
    )
  );
end;
$$;

revoke all on function public.deactivate_medication(uuid, uuid) from public;
grant execute on function public.deactivate_medication(uuid, uuid) to authenticated;

commit;
