begin;

-- Medication schedules are daily, but create_medication_schedule only creates
-- the first dose. This function fills in the doses for a given local day and
-- marks doses past their grace period as overdue, raising one alert per dose.
-- The app calls it before loading the day's doses, so doses appear and become
-- overdue whenever the patient or a caregiver opens Memora.
create function public.ensure_dose_instances(
  target_patient_id uuid,
  target_local_date date
)
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
begin
  if auth.uid() is null or not private.can_access_patient(target_patient_id) then
    raise exception 'patient access required' using errcode = '42501';
  end if;

  if target_local_date is null then
    raise exception 'local date is required' using errcode = '22023';
  end if;

  insert into public.dose_instances (schedule_id, patient_id, scheduled_for)
  select
    ms.id,
    m.patient_id,
    (target_local_date + ms.local_time) at time zone ms.timezone
  from public.medication_schedules ms
  join public.medications m on m.id = ms.medication_id
  where m.patient_id = target_patient_id
    and m.active = true
    and ms.active = true
    and ms.starts_on <= target_local_date
    and (ms.ends_on is null or ms.ends_on >= target_local_date)
    and coalesce(ms.recurrence ->> 'frequency', 'daily') = 'daily'
    and not exists (
      select 1
      from public.dose_instances existing
      where existing.schedule_id = ms.id
        and (existing.scheduled_for at time zone ms.timezone)::date
          = target_local_date
    )
  on conflict (schedule_id, scheduled_for) do nothing;

  with newly_overdue as (
    update public.dose_instances di
    set status = 'overdue'
    from public.medication_schedules ms
    where di.schedule_id = ms.id
      and di.patient_id = target_patient_id
      and di.status = 'scheduled'
      and ms.active = true
      and di.scheduled_for + ms.grace_period < now()
    returning di.id, di.scheduled_for, ms.medication_id
  )
  insert into public.alerts (
    patient_id, type, severity, status, title, message,
    source_id, rule_version, dedupe_key, occurred_at
  )
  select
    target_patient_id,
    'overdue_dose',
    'warning',
    'created',
    'Overdue dose: ' || m.name,
    m.name || ' (' || m.dosage || ') has not been reported taken.',
    overdue.id,
    'overdue-dose-v1',
    'overdue_dose:' || overdue.id::text,
    now()
  from newly_overdue overdue
  join public.medications m on m.id = overdue.medication_id
  -- Do not flood caregivers with alerts for doses missed long ago.
  where overdue.scheduled_for > now() - interval '24 hours'
  on conflict (dedupe_key) do nothing;
end;
$$;

revoke all on function public.ensure_dose_instances(uuid, date) from public;
grant execute on function public.ensure_dose_instances(uuid, date) to authenticated;

commit;
