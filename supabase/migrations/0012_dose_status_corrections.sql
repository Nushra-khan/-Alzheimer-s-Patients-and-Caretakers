begin;

create function public.update_dose_status(
  target_dose_instance_id uuid,
  target_status text,
  request_idempotency_key text,
  target_occurred_at timestamptz default now()
)
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  target_dose public.dose_instances;
  target_event_type text;
  existing_event public.dose_events;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  if target_status not in ('scheduled', 'reported_taken', 'skipped') then
    raise exception 'unsupported dose status' using errcode = '22023';
  end if;

  if nullif(trim(request_idempotency_key), '') is null then
    raise exception 'idempotency key is required' using errcode = '22023';
  end if;

  select * into target_dose
  from public.dose_instances
  where id = target_dose_instance_id
  for update;

  if target_dose.id is null
      or not private.owns_patient(target_dose.patient_id) then
    raise exception 'dose not found' using errcode = 'P0002';
  end if;

  target_event_type := case target_status
    when 'reported_taken' then 'reported_taken'
    when 'skipped' then 'skipped'
    else 'corrected'
  end;

  select * into existing_event
  from public.dose_events
  where idempotency_key = request_idempotency_key;

  if existing_event.id is not null then
    if existing_event.dose_instance_id <> target_dose_instance_id
        or existing_event.event_type <> target_event_type then
      raise exception 'idempotency key belongs to another dose action'
        using errcode = '22023';
    end if;
    return;
  end if;

  insert into public.dose_events (
    dose_instance_id,
    actor_profile_id,
    event_type,
    occurred_at,
    idempotency_key
  ) values (
    target_dose_instance_id,
    auth.uid(),
    target_event_type,
    target_occurred_at,
    request_idempotency_key
  );

  update public.dose_instances
  set status = target_status
  where id = target_dose_instance_id;
end;
$$;

revoke all on function public.update_dose_status(uuid, text, text, timestamptz) from public;
grant execute on function public.update_dose_status(uuid, text, text, timestamptz) to authenticated;

commit;
