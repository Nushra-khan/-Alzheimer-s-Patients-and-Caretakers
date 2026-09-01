begin;

create function public.report_dose_taken(
  target_dose_instance_id uuid,
  request_idempotency_key text,
  reported_at timestamptz default now()
)
returns public.dose_instances
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  target public.dose_instances;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  if nullif(trim(request_idempotency_key), '') is null then
    raise exception 'idempotency key is required' using errcode = '22023';
  end if;

  select * into target
  from public.dose_instances
  where id = target_dose_instance_id
  for update;

  if target.id is null or not private.can_access_patient(target.patient_id) then
    raise exception 'dose not found' using errcode = 'P0002';
  end if;

  insert into public.dose_events (
    dose_instance_id,
    actor_profile_id,
    event_type,
    occurred_at,
    idempotency_key
  ) values (
    target.id,
    auth.uid(),
    'reported_taken',
    reported_at,
    request_idempotency_key
  )
  on conflict (idempotency_key) do nothing;

  update public.dose_instances
  set status = 'reported_taken'
  where id = target.id and status <> 'reported_taken'
  returning * into target;

  if target.id is null then
    select * into target from public.dose_instances where id = target_dose_instance_id;
  end if;

  return target;
end;
$$;

create function public.create_sos(
  target_patient_id uuid,
  request_idempotency_key text,
  occurred_at timestamptz default now()
)
returns uuid
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  created_alert_id uuid;
  alert_dedupe_key text;
begin
  if auth.uid() is null or not private.owns_patient(target_patient_id) then
    raise exception 'patient access required' using errcode = '42501';
  end if;

  if nullif(trim(request_idempotency_key), '') is null then
    raise exception 'idempotency key is required' using errcode = '22023';
  end if;

  alert_dedupe_key := 'sos:' || request_idempotency_key;

  insert into public.alerts (
    patient_id, type, severity, status, title, message,
    dedupe_key, occurred_at, rule_version
  ) values (
    target_patient_id,
    'sos',
    'critical',
    'created',
    'SOS requires attention',
    'The patient activated the SOS control.',
    alert_dedupe_key,
    occurred_at,
    'sos-v1'
  )
  on conflict (dedupe_key) do update set dedupe_key = excluded.dedupe_key
  returning id into created_alert_id;

  insert into public.alert_events (
    alert_id, actor_profile_id, event_type, idempotency_key
  ) values (
    created_alert_id, auth.uid(), 'created', request_idempotency_key
  ) on conflict (idempotency_key) do nothing;

  insert into public.notification_outbox (
    alert_id, recipient_profile_id, idempotency_key
  )
  select
    created_alert_id,
    c.profile_id,
    request_idempotency_key || ':' || c.profile_id::text
  from public.care_relationships cr
  join public.caregivers c on c.id = cr.caregiver_id
  where cr.patient_id = target_patient_id
    and cr.status = 'active'
    and (cr.valid_from is null or cr.valid_from <= now())
    and (cr.valid_until is null or cr.valid_until > now())
  on conflict (idempotency_key) do nothing;

  update public.alerts
  set status = case
    when exists (
      select 1 from public.notification_outbox o
      where o.alert_id = created_alert_id
    ) then 'queued'
    else 'delivery_failed'
  end
  where id = created_alert_id;

  return created_alert_id;
end;
$$;

create function public.acknowledge_alert(
  target_alert_id uuid,
  request_idempotency_key text
)
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  target_patient_id uuid;
  actor_caregiver_id uuid;
begin
  select patient_id into target_patient_id
  from public.alerts where id = target_alert_id for update;

  if target_patient_id is null or not private.is_active_caregiver(target_patient_id) then
    raise exception 'alert not found' using errcode = 'P0002';
  end if;

  select id into actor_caregiver_id
  from public.caregivers where profile_id = auth.uid();

  insert into public.alert_events (
    alert_id, actor_profile_id, event_type, idempotency_key
  ) values (
    target_alert_id, auth.uid(), 'acknowledged', request_idempotency_key
  ) on conflict (idempotency_key) do nothing;

  insert into public.caregiver_responses (
    alert_id, caregiver_id, action, idempotency_key
  ) values (
    target_alert_id, actor_caregiver_id, 'acknowledged', request_idempotency_key
  ) on conflict (idempotency_key) do nothing;

  update public.alerts
  set status = 'acknowledged'
  where id = target_alert_id
    and status not in ('resolved', 'cancelled', 'expired');
end;
$$;

create function public.resolve_alert(
  target_alert_id uuid,
  resolution_note text,
  request_idempotency_key text
)
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  target_patient_id uuid;
  actor_caregiver_id uuid;
begin
  select patient_id into target_patient_id
  from public.alerts where id = target_alert_id for update;

  if target_patient_id is null or not private.is_active_caregiver(target_patient_id) then
    raise exception 'alert not found' using errcode = 'P0002';
  end if;

  select id into actor_caregiver_id
  from public.caregivers where profile_id = auth.uid();

  insert into public.alert_events (
    alert_id, actor_profile_id, event_type, details, idempotency_key
  ) values (
    target_alert_id,
    auth.uid(),
    'resolved',
    jsonb_build_object('note', left(coalesce(resolution_note, ''), 1000)),
    request_idempotency_key
  ) on conflict (idempotency_key) do nothing;

  insert into public.caregiver_responses (
    alert_id, caregiver_id, action, note, idempotency_key
  ) values (
    target_alert_id,
    actor_caregiver_id,
    'resolved',
    left(coalesce(resolution_note, ''), 1000),
    request_idempotency_key
  ) on conflict (idempotency_key) do nothing;

  update public.alerts
  set status = 'resolved'
  where id = target_alert_id and status not in ('cancelled', 'expired');
end;
$$;

revoke all on function public.report_dose_taken(uuid, text, timestamptz) from public;
revoke all on function public.create_sos(uuid, text, timestamptz) from public;
revoke all on function public.acknowledge_alert(uuid, text) from public;
revoke all on function public.resolve_alert(uuid, text, text) from public;

grant execute on function public.report_dose_taken(uuid, text, timestamptz) to authenticated;
grant execute on function public.create_sos(uuid, text, timestamptz) to authenticated;
grant execute on function public.acknowledge_alert(uuid, text) to authenticated;
grant execute on function public.resolve_alert(uuid, text, text) to authenticated;

commit;
