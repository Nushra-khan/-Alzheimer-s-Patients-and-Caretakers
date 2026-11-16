begin;

-- Lets a caregiver change the daily time of an active medication. Today's
-- dose moves to the new time if it has not been taken or skipped yet.
create function public.update_medication_time(
  target_patient_id uuid,
  target_medication_id uuid,
  target_local_time time,
  target_timezone text
)
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  target_schedule_id uuid;
  local_today date;
begin
  if auth.uid() is null or not private.is_active_caregiver(target_patient_id) then
    raise exception 'caregiver access required' using errcode = '42501';
  end if;

  if target_local_time is null or nullif(trim(target_timezone), '') is null then
    raise exception 'time and timezone are required' using errcode = '22023';
  end if;

  -- Raises for an unknown timezone name.
  local_today := (now() at time zone target_timezone)::date;

  select ms.id into target_schedule_id
  from public.medication_schedules ms
  join public.medications m on m.id = ms.medication_id
  where m.id = target_medication_id
    and m.patient_id = target_patient_id
    and m.active = true
    and ms.active = true
  order by ms.created_at desc
  limit 1
  for update of ms;

  if target_schedule_id is null then
    raise exception 'active medication not found' using errcode = 'P0002';
  end if;

  update public.medication_schedules
  set local_time = target_local_time,
      timezone = target_timezone
  where id = target_schedule_id;

  update public.dose_instances
  set scheduled_for = (local_today + target_local_time) at time zone target_timezone,
      status = 'scheduled'
  where schedule_id = target_schedule_id
    and status in ('scheduled', 'overdue')
    and (scheduled_for at time zone target_timezone)::date = local_today;

  insert into public.audit_events (
    actor_profile_id, action, resource_type, resource_id, metadata
  ) values (
    auth.uid(),
    'medication_time_updated',
    'medication',
    target_medication_id,
    jsonb_build_object('local_time', target_local_time, 'timezone', target_timezone)
  );
end;
$$;

revoke all on function public.update_medication_time(uuid, uuid, time, text) from public;
grant execute on function public.update_medication_time(uuid, uuid, time, text) to authenticated;

-- Caregivers' apps refresh the medication list when it changes.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
      and not exists (
        select 1 from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = 'medications'
      ) then
    alter publication supabase_realtime add table public.medications;
  end if;
end;
$$;

commit;
