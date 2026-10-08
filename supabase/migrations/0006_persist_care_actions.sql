begin;

alter table public.patients
  add column if not exists location_sharing_enabled boolean not null default false;

alter table public.medication_schedules
  add column if not exists client_request_key text unique;

create table public.routine_completions (
  routine_schedule_id uuid not null references public.routine_schedules(id) on delete cascade,
  patient_id uuid not null references public.patients(id) on delete cascade,
  local_date date not null,
  completed_at timestamptz not null default now(),
  primary key (routine_schedule_id, local_date)
);

create index routine_completions_patient_date_idx
  on public.routine_completions(patient_id, local_date);

alter table public.routine_completions enable row level security;

create policy routine_completions_authorized_select
on public.routine_completions for select
using (private.can_access_patient(patient_id));

create function public.create_medication_schedule(
  target_patient_id uuid,
  medicine_name text,
  medicine_dosage text,
  medicine_instructions text,
  target_scheduled_for timestamptz,
  target_timezone text,
  request_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  created_medication_id uuid;
  created_schedule_id uuid;
  created_dose_id uuid;
  existing_record record;
  local_scheduled timestamp;
begin
  if auth.uid() is null or not private.is_active_caregiver(target_patient_id) then
    raise exception 'caregiver access required' using errcode = '42501';
  end if;

  if nullif(trim(medicine_name), '') is null
      or nullif(trim(medicine_dosage), '') is null
      or nullif(trim(request_idempotency_key), '') is null then
    raise exception 'medicine, dosage, and request key are required' using errcode = '22023';
  end if;

  select ms.id as schedule_id, ms.medication_id, di.id as dose_id
  into existing_record
  from public.medication_schedules ms
  left join public.dose_instances di on di.schedule_id = ms.id
  where ms.client_request_key = request_idempotency_key
  order by di.scheduled_for
  limit 1;

  if existing_record.schedule_id is not null then
    return jsonb_build_object(
      'medication_id', existing_record.medication_id,
      'schedule_id', existing_record.schedule_id,
      'dose_id', existing_record.dose_id
    );
  end if;

  local_scheduled := target_scheduled_for at time zone target_timezone;

  insert into public.medications (
    patient_id, name, dosage, instructions
  ) values (
    target_patient_id,
    trim(medicine_name),
    trim(medicine_dosage),
    nullif(trim(medicine_instructions), '')
  ) returning id into created_medication_id;

  insert into public.medication_schedules (
    medication_id,
    local_time,
    timezone,
    recurrence,
    starts_on,
    client_request_key
  ) values (
    created_medication_id,
    local_scheduled::time,
    target_timezone,
    jsonb_build_object('frequency', 'daily'),
    local_scheduled::date,
    request_idempotency_key
  ) returning id into created_schedule_id;

  insert into public.dose_instances (
    schedule_id, patient_id, scheduled_for
  ) values (
    created_schedule_id, target_patient_id, target_scheduled_for
  ) returning id into created_dose_id;

  return jsonb_build_object(
    'medication_id', created_medication_id,
    'schedule_id', created_schedule_id,
    'dose_id', created_dose_id
  );
end;
$$;

create function public.set_routine_completed(
  target_routine_id uuid,
  completed boolean,
  target_local_date date
)
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  target_patient_id uuid;
begin
  select patient_id into target_patient_id
  from public.routine_schedules
  where id = target_routine_id and active = true;

  if target_patient_id is null or not private.owns_patient(target_patient_id) then
    raise exception 'routine not found' using errcode = 'P0002';
  end if;

  if completed then
    insert into public.routine_completions (
      routine_schedule_id, patient_id, local_date
    ) values (
      target_routine_id, target_patient_id, target_local_date
    ) on conflict (routine_schedule_id, local_date) do update
      set completed_at = now();
  else
    delete from public.routine_completions
    where routine_schedule_id = target_routine_id
      and local_date = target_local_date;
  end if;
end;
$$;

create function public.set_location_sharing(
  target_patient_id uuid,
  enabled boolean
)
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
begin
  if not private.owns_patient(target_patient_id) then
    raise exception 'patient access required' using errcode = '42501';
  end if;

  update public.patients
  set location_sharing_enabled = enabled
  where id = target_patient_id;
end;
$$;

create function public.update_safe_zone_radius(
  target_safe_zone_id uuid,
  target_radius_meters integer
)
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  target_patient_id uuid;
begin
  if target_radius_meters not between 25 and 10000 then
    raise exception 'radius must be between 25 and 10000 meters' using errcode = '22023';
  end if;

  select patient_id into target_patient_id
  from public.safe_zones
  where id = target_safe_zone_id and active = true;

  if target_patient_id is null or not private.can_access_patient(target_patient_id) then
    raise exception 'safe zone not found' using errcode = 'P0002';
  end if;

  update public.safe_zones
  set radius_meters = target_radius_meters
  where id = target_safe_zone_id;
end;
$$;

revoke all on function public.create_medication_schedule(uuid, text, text, text, timestamptz, text, text) from public;
revoke all on function public.set_routine_completed(uuid, boolean, date) from public;
revoke all on function public.set_location_sharing(uuid, boolean) from public;
revoke all on function public.update_safe_zone_radius(uuid, integer) from public;

grant execute on function public.create_medication_schedule(uuid, text, text, text, timestamptz, text, text) to authenticated;
grant execute on function public.set_routine_completed(uuid, boolean, date) to authenticated;
grant execute on function public.set_location_sharing(uuid, boolean) to authenticated;
grant execute on function public.update_safe_zone_radius(uuid, integer) to authenticated;

do $$
declare
  realtime_table text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach realtime_table in array array[
      'patients',
      'dose_instances',
      'alerts',
      'routine_schedules',
      'routine_completions',
      'safe_zones',
      'care_relationships',
      'emergency_contacts'
    ] loop
      if not exists (
        select 1
        from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = realtime_table
      ) then
        execute format(
          'alter publication supabase_realtime add table public.%I',
          realtime_table
        );
      end if;
    end loop;
  end if;
end;
$$;

commit;
