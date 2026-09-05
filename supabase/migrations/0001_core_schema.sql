begin;

create extension if not exists pgcrypto with schema extensions;
create extension if not exists postgis with schema extensions;
create schema if not exists private;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 120),
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.patients (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null unique references public.profiles(id) on delete cascade,
  date_of_birth date,
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.caregivers (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null unique references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.care_relationships (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete cascade,
  caregiver_id uuid not null references public.caregivers(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'active', 'revoked', 'expired')),
  permissions jsonb not null default '{}'::jsonb,
  valid_from timestamptz,
  valid_until timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (patient_id, caregiver_id)
);

create table public.care_invitations (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null,
  accepted_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  check (expires_at > created_at)
);

create table public.consents (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete cascade,
  purpose text not null,
  notice_version text not null,
  granted_by uuid not null references public.profiles(id),
  granted_at timestamptz not null default now(),
  revoked_at timestamptz,
  metadata jsonb not null default '{}'::jsonb
);

create table public.emergency_contacts (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete cascade,
  name text not null,
  relationship text,
  phone text not null,
  priority smallint not null default 1 check (priority > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.medications (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete cascade,
  name text not null,
  dosage text not null,
  instructions text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.medication_schedules (
  id uuid primary key default gen_random_uuid(),
  medication_id uuid not null references public.medications(id) on delete cascade,
  local_time time not null,
  timezone text not null,
  recurrence jsonb not null,
  starts_on date not null,
  ends_on date,
  grace_period interval not null default interval '30 minutes'
    check (grace_period >= interval '0 minutes'),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_on is null or ends_on >= starts_on)
);

create table public.dose_instances (
  id uuid primary key default gen_random_uuid(),
  schedule_id uuid not null references public.medication_schedules(id) on delete cascade,
  patient_id uuid not null references public.patients(id) on delete cascade,
  scheduled_for timestamptz not null,
  status text not null default 'scheduled'
    check (status in ('scheduled', 'reported_taken', 'skipped', 'overdue')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (schedule_id, scheduled_for)
);

create table public.dose_events (
  id uuid primary key default gen_random_uuid(),
  dose_instance_id uuid not null references public.dose_instances(id) on delete cascade,
  actor_profile_id uuid not null references public.profiles(id),
  event_type text not null check (event_type in ('reported_taken', 'skipped', 'corrected')),
  occurred_at timestamptz not null,
  idempotency_key text not null unique,
  created_at timestamptz not null default now()
);

create table public.routine_schedules (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete cascade,
  title text not null,
  description text,
  local_time time not null,
  timezone text not null,
  recurrence jsonb not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.safe_zones (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete cascade,
  name text not null,
  center extensions.geography(point, 4326) not null,
  radius_meters integer not null check (radius_meters between 25 and 10000),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.location_observations (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete cascade,
  device_id uuid,
  position extensions.geography(point, 4326) not null,
  accuracy_meters double precision not null check (accuracy_meters >= 0),
  observed_at timestamptz not null,
  received_at timestamptz not null default now(),
  idempotency_key text not null unique
);

create table public.safe_zone_transitions (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete cascade,
  safe_zone_id uuid not null references public.safe_zones(id) on delete cascade,
  transition text not null check (transition in ('entered', 'exited')),
  occurred_at timestamptz not null,
  source_observation_id uuid references public.location_observations(id),
  dedupe_key text not null unique,
  created_at timestamptz not null default now()
);

create table public.devices (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  platform text not null check (platform in ('android', 'ios')),
  push_token text,
  push_token_updated_at timestamptz,
  last_seen_at timestamptz,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.location_observations
  add constraint location_observations_device_fk
  foreign key (device_id) references public.devices(id) on delete set null;

create table public.alerts (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete cascade,
  type text not null check (type in ('sos', 'overdue_dose', 'safe_zone_exit', 'device_unavailable')),
  severity text not null check (severity in ('critical', 'warning', 'info')),
  status text not null default 'created'
    check (status in ('created', 'queued', 'delivered', 'acknowledged', 'action_taken', 'resolved', 'cancelled', 'expired', 'delivery_failed')),
  title text not null,
  message text not null,
  source_id uuid,
  rule_version text,
  dedupe_key text not null unique,
  occurred_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.alert_events (
  id uuid primary key default gen_random_uuid(),
  alert_id uuid not null references public.alerts(id) on delete cascade,
  actor_profile_id uuid references public.profiles(id),
  event_type text not null,
  details jsonb not null default '{}'::jsonb,
  idempotency_key text unique,
  created_at timestamptz not null default now()
);

create table public.caregiver_responses (
  id uuid primary key default gen_random_uuid(),
  alert_id uuid not null references public.alerts(id) on delete cascade,
  caregiver_id uuid not null references public.caregivers(id),
  action text not null,
  note text,
  idempotency_key text not null unique,
  created_at timestamptz not null default now()
);

create table public.notification_outbox (
  id uuid primary key default gen_random_uuid(),
  alert_id uuid not null references public.alerts(id) on delete cascade,
  recipient_profile_id uuid not null references public.profiles(id),
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'sent', 'retry', 'failed')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  next_attempt_at timestamptz not null default now(),
  idempotency_key text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.notification_attempts (
  id uuid primary key default gen_random_uuid(),
  outbox_id uuid not null references public.notification_outbox(id) on delete cascade,
  provider_message_id text,
  outcome text not null,
  error_code text,
  created_at timestamptz not null default now()
);

create table public.audit_events (
  id bigint generated always as identity primary key,
  actor_profile_id uuid references public.profiles(id),
  action text not null,
  resource_type text not null,
  resource_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index care_relationships_patient_idx on public.care_relationships(patient_id, status);
create index care_relationships_caregiver_idx on public.care_relationships(caregiver_id, status);
create index dose_instances_patient_time_idx on public.dose_instances(patient_id, scheduled_for);
create index location_observations_patient_time_idx on public.location_observations(patient_id, observed_at desc);
create index alerts_patient_status_time_idx on public.alerts(patient_id, status, occurred_at desc);
create index notification_outbox_due_idx on public.notification_outbox(status, next_attempt_at);

create function private.set_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'profiles', 'patients', 'caregivers', 'care_relationships',
    'emergency_contacts', 'medications', 'medication_schedules',
    'dose_instances', 'routine_schedules', 'safe_zones', 'devices',
    'alerts', 'notification_outbox'
  ]
  loop
    execute format(
      'create trigger set_updated_at before update on public.%I '
      'for each row execute function private.set_updated_at()',
      table_name
    );
  end loop;
end;
$$;

create function private.owns_patient(target_patient_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.patients p
    where p.id = target_patient_id and p.profile_id = auth.uid()
  );
$$;

create function private.is_active_caregiver(target_patient_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.care_relationships cr
    join public.caregivers c on c.id = cr.caregiver_id
    where cr.patient_id = target_patient_id
      and c.profile_id = auth.uid()
      and cr.status = 'active'
      and (cr.valid_from is null or cr.valid_from <= now())
      and (cr.valid_until is null or cr.valid_until > now())
  );
$$;

create function private.can_access_patient(target_patient_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select private.owns_patient(target_patient_id)
      or private.is_active_caregiver(target_patient_id);
$$;

revoke all on function private.owns_patient(uuid) from public;
revoke all on function private.is_active_caregiver(uuid) from public;
revoke all on function private.can_access_patient(uuid) from public;
grant usage on schema private to authenticated;
grant execute on function private.owns_patient(uuid) to authenticated;
grant execute on function private.is_active_caregiver(uuid) to authenticated;
grant execute on function private.can_access_patient(uuid) to authenticated;

alter table public.profiles enable row level security;
alter table public.patients enable row level security;
alter table public.caregivers enable row level security;
alter table public.care_relationships enable row level security;
alter table public.care_invitations enable row level security;
alter table public.consents enable row level security;
alter table public.emergency_contacts enable row level security;
alter table public.medications enable row level security;
alter table public.medication_schedules enable row level security;
alter table public.dose_instances enable row level security;
alter table public.dose_events enable row level security;
alter table public.routine_schedules enable row level security;
alter table public.safe_zones enable row level security;
alter table public.location_observations enable row level security;
alter table public.safe_zone_transitions enable row level security;
alter table public.devices enable row level security;
alter table public.alerts enable row level security;
alter table public.alert_events enable row level security;
alter table public.caregiver_responses enable row level security;
alter table public.notification_outbox enable row level security;
alter table public.notification_attempts enable row level security;
alter table public.audit_events enable row level security;

create policy profiles_self_select on public.profiles for select
  using (id = auth.uid());
create policy profiles_linked_patient_select on public.profiles for select
  using (
    exists (
      select 1 from public.patients p
      where p.profile_id = profiles.id and private.can_access_patient(p.id)
    )
  );
create policy profiles_self_update on public.profiles for update
  using (id = auth.uid()) with check (id = auth.uid());

create policy patients_authorized_select on public.patients for select
  using (private.can_access_patient(id));
create policy caregivers_self_select on public.caregivers for select
  using (profile_id = auth.uid());
create policy relationships_participant_select on public.care_relationships for select
  using (
    private.owns_patient(patient_id)
    or exists (
      select 1 from public.caregivers c
      where c.id = caregiver_id and c.profile_id = auth.uid()
    )
  );

create policy invitations_patient_select on public.care_invitations for select
  using (private.owns_patient(patient_id));
create policy consents_authorized_select on public.consents for select
  using (private.can_access_patient(patient_id));

create policy emergency_contacts_authorized_all on public.emergency_contacts for all
  using (private.can_access_patient(patient_id))
  with check (private.can_access_patient(patient_id));
create policy medications_authorized_all on public.medications for all
  using (private.can_access_patient(patient_id))
  with check (private.can_access_patient(patient_id));
create policy medication_schedules_authorized_all on public.medication_schedules for all
  using (
    exists (
      select 1 from public.medications m
      where m.id = medication_id and private.can_access_patient(m.patient_id)
    )
  )
  with check (
    exists (
      select 1 from public.medications m
      where m.id = medication_id and private.can_access_patient(m.patient_id)
    )
  );
create policy dose_instances_authorized_select on public.dose_instances for select
  using (private.can_access_patient(patient_id));
create policy dose_events_authorized_select on public.dose_events for select
  using (
    exists (
      select 1 from public.dose_instances d
      where d.id = dose_instance_id and private.can_access_patient(d.patient_id)
    )
  );
create policy routines_authorized_all on public.routine_schedules for all
  using (private.can_access_patient(patient_id))
  with check (private.can_access_patient(patient_id));
create policy safe_zones_authorized_all on public.safe_zones for all
  using (private.can_access_patient(patient_id))
  with check (private.can_access_patient(patient_id));
create policy locations_authorized_select on public.location_observations for select
  using (private.can_access_patient(patient_id));
create policy transitions_authorized_select on public.safe_zone_transitions for select
  using (private.can_access_patient(patient_id));
create policy alerts_authorized_select on public.alerts for select
  using (private.can_access_patient(patient_id));
create policy alert_events_authorized_select on public.alert_events for select
  using (
    exists (
      select 1 from public.alerts a
      where a.id = alert_id and private.can_access_patient(a.patient_id)
    )
  );
create policy responses_authorized_select on public.caregiver_responses for select
  using (
    exists (
      select 1 from public.alerts a
      where a.id = alert_id and private.can_access_patient(a.patient_id)
    )
  );
create policy devices_self_all on public.devices for all
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());

-- Tables without client write policies are intentionally server-owned. All
-- invitations, dose events, alerts, responses, location writes, audit records,
-- and notification work must be created through reviewed security-definer RPCs
-- or backend workers added in subsequent migrations.

commit;
