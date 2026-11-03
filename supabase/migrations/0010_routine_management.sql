begin;

alter table public.routine_schedules
  add column if not exists client_request_key text unique;

create function public.create_routine_schedule(
  target_patient_id uuid,
  routine_title text,
  routine_description text,
  target_local_time time,
  target_timezone text,
  request_idempotency_key text
)
returns uuid
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  created_routine_id uuid;
begin
  if auth.uid() is null or not private.is_active_caregiver(target_patient_id) then
    raise exception 'caregiver access required' using errcode = '42501';
  end if;

  if nullif(trim(routine_title), '') is null
      or nullif(trim(target_timezone), '') is null
      or nullif(trim(request_idempotency_key), '') is null then
    raise exception 'title, timezone, and request key are required'
      using errcode = '22023';
  end if;

  select id into created_routine_id
  from public.routine_schedules
  where client_request_key = request_idempotency_key
    and patient_id = target_patient_id;

  if created_routine_id is not null then
    return created_routine_id;
  end if;

  insert into public.routine_schedules (
    patient_id,
    title,
    description,
    local_time,
    timezone,
    recurrence,
    client_request_key
  ) values (
    target_patient_id,
    trim(routine_title),
    nullif(trim(routine_description), ''),
    target_local_time,
    trim(target_timezone),
    jsonb_build_object('frequency', 'daily'),
    request_idempotency_key
  )
  on conflict (client_request_key) do nothing
  returning id into created_routine_id;

  if created_routine_id is null then
    select id into created_routine_id
    from public.routine_schedules
    where client_request_key = request_idempotency_key
      and patient_id = target_patient_id;
    if created_routine_id is null then
      raise exception 'request key belongs to another routine'
        using errcode = '22023';
    end if;
    return created_routine_id;
  end if;

  insert into public.audit_events (
    actor_profile_id,
    action,
    resource_type,
    resource_id,
    metadata
  ) values (
    auth.uid(),
    'routine_schedule_created',
    'routine_schedule',
    created_routine_id,
    jsonb_build_object('patient_id', target_patient_id)
  );

  return created_routine_id;
end;
$$;

create function public.update_routine_schedule(
  target_routine_id uuid,
  routine_title text,
  routine_description text,
  target_local_time time,
  target_timezone text
)
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  target_patient_id uuid;
begin
  if nullif(trim(routine_title), '') is null
      or nullif(trim(target_timezone), '') is null then
    raise exception 'title and timezone are required' using errcode = '22023';
  end if;

  select patient_id into target_patient_id
  from public.routine_schedules
  where id = target_routine_id
    and active = true
  for update;

  if target_patient_id is null
      or not private.is_active_caregiver(target_patient_id) then
    raise exception 'active routine not found' using errcode = 'P0002';
  end if;

  update public.routine_schedules
  set title = trim(routine_title),
      description = nullif(trim(routine_description), ''),
      local_time = target_local_time,
      timezone = trim(target_timezone)
  where id = target_routine_id;

  insert into public.audit_events (
    actor_profile_id,
    action,
    resource_type,
    resource_id,
    metadata
  ) values (
    auth.uid(),
    'routine_schedule_updated',
    'routine_schedule',
    target_routine_id,
    jsonb_build_object(
      'patient_id', target_patient_id,
      'changed_fields', jsonb_build_array(
        'title', 'description', 'local_time', 'timezone'
      )
    )
  );
end;
$$;

create function public.deactivate_routine_schedule(target_routine_id uuid)
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
  where id = target_routine_id
    and active = true
  for update;

  if target_patient_id is null
      or not private.is_active_caregiver(target_patient_id) then
    raise exception 'active routine not found' using errcode = 'P0002';
  end if;

  update public.routine_schedules
  set active = false
  where id = target_routine_id;

  insert into public.audit_events (
    actor_profile_id,
    action,
    resource_type,
    resource_id,
    metadata
  ) values (
    auth.uid(),
    'routine_schedule_deactivated',
    'routine_schedule',
    target_routine_id,
    jsonb_build_object('patient_id', target_patient_id)
  );
end;
$$;

revoke all on function public.create_routine_schedule(uuid, text, text, time, text, text) from public;
revoke all on function public.update_routine_schedule(uuid, text, text, time, text) from public;
revoke all on function public.deactivate_routine_schedule(uuid) from public;

grant execute on function public.create_routine_schedule(uuid, text, text, time, text, text) to authenticated;
grant execute on function public.update_routine_schedule(uuid, text, text, time, text) to authenticated;
grant execute on function public.deactivate_routine_schedule(uuid) to authenticated;

commit;
