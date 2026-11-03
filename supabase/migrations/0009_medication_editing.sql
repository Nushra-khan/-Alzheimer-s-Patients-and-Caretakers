begin;

create function public.update_medication_details(
  target_patient_id uuid,
  target_medication_id uuid,
  medicine_name text,
  medicine_dosage text,
  medicine_instructions text
)
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
begin
  if auth.uid() is null or not private.is_active_caregiver(target_patient_id) then
    raise exception 'caregiver access required' using errcode = '42501';
  end if;

  if nullif(trim(medicine_name), '') is null
      or nullif(trim(medicine_dosage), '') is null then
    raise exception 'medicine and dosage are required' using errcode = '22023';
  end if;

  update public.medications
  set name = trim(medicine_name),
      dosage = trim(medicine_dosage),
      instructions = nullif(trim(medicine_instructions), '')
  where id = target_medication_id
    and patient_id = target_patient_id
    and active = true;

  if not found then
    raise exception 'active medication not found' using errcode = 'P0002';
  end if;

  insert into public.audit_events (
    actor_profile_id,
    action,
    resource_type,
    resource_id,
    metadata
  ) values (
    auth.uid(),
    'medication_details_updated',
    'medication',
    target_medication_id,
    jsonb_build_object(
      'patient_id', target_patient_id,
      'changed_fields', jsonb_build_array('name', 'dosage', 'instructions')
    )
  );
end;
$$;

revoke all on function public.update_medication_details(uuid, uuid, text, text, text) from public;
grant execute on function public.update_medication_details(uuid, uuid, text, text, text) to authenticated;

commit;
