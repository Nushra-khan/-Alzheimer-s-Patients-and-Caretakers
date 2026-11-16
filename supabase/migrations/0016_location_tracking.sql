begin;

-- Battery level reported by the patient's phone with each location.
alter table public.devices
  add column if not exists battery_level smallint
    check (battery_level between 0 and 100);

create index if not exists location_observations_patient_time_idx
  on public.location_observations (patient_id, observed_at desc);
create index if not exists safe_zone_transitions_zone_time_idx
  on public.safe_zone_transitions (safe_zone_id, occurred_at desc);

-- Queues a notification for every active caregiver of a patient and marks
-- the alert queued (or delivery_failed when nobody can be notified).
create function private.queue_alert_notifications(
  target_alert_id uuid,
  target_patient_id uuid,
  key_prefix text
)
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
begin
  insert into public.notification_outbox (
    alert_id, recipient_profile_id, idempotency_key
  )
  select target_alert_id, c.profile_id, key_prefix || ':' || c.profile_id::text
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
      select 1 from public.notification_outbox o where o.alert_id = target_alert_id
    ) then 'queued'
    else 'delivery_failed'
  end
  where id = target_alert_id and status = 'created';
end;
$$;

revoke all on function private.queue_alert_notifications(uuid, uuid, text) from public;

-- Called by the patient's phone. Saves a location, updates "last seen" and
-- battery, checks the safe zone, and records entering/leaving it. Leaving
-- raises a critical alert for caregivers. Returns how many seconds the phone
-- should wait before the next update: 60 while outside the zone or during an
-- active SOS, otherwise 300.
create function public.record_location(
  target_latitude double precision,
  target_longitude double precision,
  target_accuracy_meters double precision,
  target_observed_at timestamptz,
  target_battery_level integer,
  request_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, extensions, pg_temp
as $$
declare
  actor_patient public.patients;
  actor_device_id uuid;
  observed timestamptz;
  observation_id uuid;
  point_value extensions.geography;
  active_zone public.safe_zones;
  distance_m double precision;
  previous_transition text;
  is_inside boolean;
  new_transition text;
  transition_id uuid;
  exit_alert_id uuid;
  has_active_sos boolean;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  select * into actor_patient
  from public.patients
  where profile_id = auth.uid();

  if actor_patient.id is null then
    raise exception 'patient access required' using errcode = '42501';
  end if;

  if not actor_patient.location_sharing_enabled then
    raise exception 'location sharing is turned off' using errcode = '42501';
  end if;

  if target_latitude is null or target_longitude is null
      or target_latitude not between -90 and 90
      or target_longitude not between -180 and 180 then
    raise exception 'invalid coordinates' using errcode = '22023';
  end if;

  if nullif(trim(request_idempotency_key), '') is null then
    raise exception 'idempotency key is required' using errcode = '22023';
  end if;

  -- Phones with a wrong clock must not create locations in the future.
  observed := least(coalesce(target_observed_at, now()), now());

  -- One active device row per patient profile tracks last seen and battery.
  select id into actor_device_id
  from public.devices
  where profile_id = auth.uid() and active = true
  order by last_seen_at desc nulls last
  limit 1;

  if actor_device_id is null then
    insert into public.devices (profile_id, platform, last_seen_at, battery_level)
    values (
      auth.uid(),
      'android',
      now(),
      case when target_battery_level between 0 and 100
        then target_battery_level end
    )
    returning id into actor_device_id;
  else
    update public.devices
    set last_seen_at = now(),
        battery_level = case when target_battery_level between 0 and 100
          then target_battery_level else battery_level end
    where id = actor_device_id;
  end if;

  point_value := extensions.st_setsrid(
    extensions.st_makepoint(target_longitude, target_latitude), 4326
  )::extensions.geography;

  insert into public.location_observations (
    patient_id, device_id, position, accuracy_meters, observed_at,
    idempotency_key
  ) values (
    actor_patient.id,
    actor_device_id,
    point_value,
    greatest(coalesce(target_accuracy_meters, 0), 0),
    observed,
    request_idempotency_key
  )
  on conflict (idempotency_key) do nothing
  returning id into observation_id;

  select * into active_zone
  from public.safe_zones
  where patient_id = actor_patient.id and active = true
  order by updated_at desc
  limit 1;

  if active_zone.id is not null and observation_id is not null then
    distance_m := extensions.st_distance(point_value, active_zone.center);

    select transition into previous_transition
    from public.safe_zone_transitions
    where safe_zone_id = active_zone.id
    order by occurred_at desc
    limit 1;

    -- GPS readings wobble. Count the patient as outside only when even the
    -- most generous reading (distance minus accuracy, capped at 150 m) is
    -- beyond the radius, and inside only when the reading is within it.
    if distance_m - least(greatest(coalesce(target_accuracy_meters, 0), 0), 150)
        > active_zone.radius_meters then
      is_inside := false;
    elsif distance_m <= active_zone.radius_meters then
      is_inside := true;
    else
      is_inside := coalesce(previous_transition, 'entered') = 'entered';
    end if;

    if is_inside and previous_transition is distinct from 'entered' then
      new_transition := 'entered';
    elsif not is_inside and previous_transition is distinct from 'exited' then
      new_transition := 'exited';
    end if;

    if new_transition is not null then
      insert into public.safe_zone_transitions (
        patient_id, safe_zone_id, transition, occurred_at,
        source_observation_id, dedupe_key
      ) values (
        actor_patient.id, active_zone.id, new_transition, observed,
        observation_id, 'transition:' || observation_id::text
      )
      on conflict (dedupe_key) do nothing
      returning id into transition_id;

      if new_transition = 'exited' and transition_id is not null then
        insert into public.alerts (
          patient_id, type, severity, status, title, message,
          source_id, rule_version, dedupe_key, occurred_at
        ) values (
          actor_patient.id,
          'safe_zone_exit',
          'critical',
          'created',
          'Left the safe zone',
          'The patient is about ' || round(distance_m)::text
            || ' m from ' || active_zone.name || '.',
          transition_id,
          'safe-zone-v1',
          'safe_zone_exit:' || transition_id::text,
          observed
        )
        on conflict (dedupe_key) do nothing
        returning id into exit_alert_id;

        if exit_alert_id is not null then
          perform private.queue_alert_notifications(
            exit_alert_id, actor_patient.id, 'safe_zone_exit:' || transition_id::text
          );
        end if;
      end if;
    end if;
  end if;

  select exists (
    select 1 from public.alerts
    where patient_id = actor_patient.id
      and type = 'sos'
      and status not in ('resolved', 'cancelled', 'expired')
      and occurred_at > now() - interval '2 hours'
  ) into has_active_sos;

  return jsonb_build_object(
    'inside_safe_zone', is_inside,
    'distance_meters', round(distance_m),
    'next_update_seconds',
      case when has_active_sos or is_inside = false then 60 else 300 end
  );
end;
$$;

-- Creates or moves the patient's safe zone. Any earlier zone is switched off
-- so the patient always has exactly one active zone.
create function public.save_safe_zone(
  target_patient_id uuid,
  zone_name text,
  target_latitude double precision,
  target_longitude double precision,
  target_radius_meters integer
)
returns uuid
language plpgsql
security definer
set search_path = public, private, extensions, pg_temp
as $$
declare
  new_zone_id uuid;
begin
  if auth.uid() is null or not private.can_access_patient(target_patient_id) then
    raise exception 'patient access required' using errcode = '42501';
  end if;

  if target_latitude is null or target_longitude is null
      or target_latitude not between -90 and 90
      or target_longitude not between -180 and 180 then
    raise exception 'invalid coordinates' using errcode = '22023';
  end if;

  if target_radius_meters not between 25 and 10000 then
    raise exception 'radius must be between 25 and 10000 meters' using errcode = '22023';
  end if;

  update public.safe_zones
  set active = false
  where patient_id = target_patient_id and active = true;

  insert into public.safe_zones (patient_id, name, center, radius_meters)
  values (
    target_patient_id,
    coalesce(nullif(left(trim(zone_name), 80), ''), 'Home'),
    extensions.st_setsrid(
      extensions.st_makepoint(target_longitude, target_latitude), 4326
    )::extensions.geography,
    target_radius_meters
  )
  returning id into new_zone_id;

  insert into public.audit_events (
    actor_profile_id, action, resource_type, resource_id, metadata
  ) values (
    auth.uid(),
    'safe_zone_saved',
    'safe_zone',
    new_zone_id,
    jsonb_build_object('radius_meters', target_radius_meters)
  );

  return new_zone_id;
end;
$$;

-- Everything the caregiver's map needs in one call, with coordinates as
-- plain numbers. When sharing is on but the phone has been silent for
-- 20 minutes, raises one "device offline" alert for that silent period.
create function public.get_location_status(target_patient_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, private, extensions, pg_temp
as $$
declare
  target_patient public.patients;
  latest public.location_observations;
  active_zone public.safe_zones;
  device public.devices;
  latest_transition text;
  location_state text;
  offline_alert_id uuid;
begin
  if auth.uid() is null or not private.can_access_patient(target_patient_id) then
    raise exception 'patient access required' using errcode = '42501';
  end if;

  select * into target_patient from public.patients where id = target_patient_id;

  select * into latest
  from public.location_observations
  where patient_id = target_patient_id
  order by observed_at desc
  limit 1;

  select * into active_zone
  from public.safe_zones
  where patient_id = target_patient_id and active = true
  order by updated_at desc
  limit 1;

  select d.* into device
  from public.devices d
  where d.profile_id = target_patient.profile_id and d.active = true
  order by d.last_seen_at desc nulls last
  limit 1;

  if active_zone.id is not null then
    select transition into latest_transition
    from public.safe_zone_transitions
    where safe_zone_id = active_zone.id
    order by occurred_at desc
    limit 1;
  end if;

  location_state := case
    when not target_patient.location_sharing_enabled then 'sharing_off'
    when device.last_seen_at is null
      or device.last_seen_at < now() - interval '20 minutes' then 'offline'
    when active_zone.id is null or latest_transition is null then 'unknown'
    when latest_transition = 'exited' then 'outside'
    else 'inside'
  end;

  if location_state = 'offline' and device.last_seen_at is not null then
    insert into public.alerts (
      patient_id, type, severity, status, title, message,
      rule_version, dedupe_key, occurred_at
    ) values (
      target_patient_id,
      'device_unavailable',
      'warning',
      'created',
      'Patient''s phone is offline',
      'No location update for over 20 minutes. The phone may be off, '
        || 'out of battery, or without internet.',
      'device-offline-v1',
      'device_unavailable:' || target_patient_id::text || ':'
        || extract(epoch from device.last_seen_at)::bigint::text,
      device.last_seen_at + interval '20 minutes'
    )
    on conflict (dedupe_key) do nothing
    returning id into offline_alert_id;

    if offline_alert_id is not null then
      perform private.queue_alert_notifications(
        offline_alert_id, target_patient_id, 'device_unavailable:' || offline_alert_id::text
      );
    end if;
  end if;

  return jsonb_build_object(
    'status', location_state,
    'sharing_enabled', target_patient.location_sharing_enabled,
    'last_seen_at', device.last_seen_at,
    'battery_level', device.battery_level,
    'location', case when latest.id is null then null else jsonb_build_object(
      'latitude', extensions.st_y(latest.position::extensions.geometry),
      'longitude', extensions.st_x(latest.position::extensions.geometry),
      'accuracy_meters', latest.accuracy_meters,
      'observed_at', latest.observed_at
    ) end,
    'safe_zone', case when active_zone.id is null then null else jsonb_build_object(
      'id', active_zone.id,
      'name', active_zone.name,
      'latitude', extensions.st_y(active_zone.center::extensions.geometry),
      'longitude', extensions.st_x(active_zone.center::extensions.geometry),
      'radius_meters', active_zone.radius_meters,
      'updated_at', active_zone.updated_at
    ) end
  );
end;
$$;

revoke all on function public.record_location(
  double precision, double precision, double precision, timestamptz, integer, text
) from public;
revoke all on function public.save_safe_zone(
  uuid, text, double precision, double precision, integer
) from public;
revoke all on function public.get_location_status(uuid) from public;

grant execute on function public.record_location(
  double precision, double precision, double precision, timestamptz, integer, text
) to authenticated;
grant execute on function public.save_safe_zone(
  uuid, text, double precision, double precision, integer
) to authenticated;
grant execute on function public.get_location_status(uuid) to authenticated;

-- Let caregivers' apps hear about new locations and safe-zone changes live.
do $$
declare
  realtime_table text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach realtime_table in array array[
      'location_observations', 'safe_zone_transitions'
    ]
    loop
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
