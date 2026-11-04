begin;

alter table public.emergency_contacts
  add column if not exists client_request_key text unique;

drop policy if exists emergency_contacts_authorized_all
  on public.emergency_contacts;

create policy emergency_contacts_authorized_select
on public.emergency_contacts for select
using (private.can_access_patient(patient_id));

create function public.create_emergency_contact(
  target_patient_id uuid,
  contact_name text,
  contact_relationship text,
  contact_phone text,
  contact_priority smallint,
  request_idempotency_key text
)
returns uuid
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  created_contact_id uuid;
begin
  if auth.uid() is null or not private.can_access_patient(target_patient_id) then
    raise exception 'patient access required' using errcode = '42501';
  end if;

  if nullif(trim(contact_name), '') is null
      or nullif(trim(contact_phone), '') is null
      or nullif(trim(request_idempotency_key), '') is null then
    raise exception 'name, phone, and request key are required'
      using errcode = '22023';
  end if;

  if contact_priority not between 1 and 100 then
    raise exception 'priority must be between 1 and 100'
      using errcode = '22023';
  end if;

  if trim(contact_phone) !~ '^\+?[0-9][0-9 ()-]{6,24}$' then
    raise exception 'phone number format is invalid' using errcode = '22023';
  end if;

  select id into created_contact_id
  from public.emergency_contacts
  where client_request_key = request_idempotency_key
    and patient_id = target_patient_id;

  if created_contact_id is not null then
    return created_contact_id;
  end if;

  insert into public.emergency_contacts (
    patient_id,
    name,
    relationship,
    phone,
    priority,
    client_request_key
  ) values (
    target_patient_id,
    trim(contact_name),
    nullif(trim(contact_relationship), ''),
    trim(contact_phone),
    contact_priority,
    request_idempotency_key
  )
  on conflict (client_request_key) do nothing
  returning id into created_contact_id;

  if created_contact_id is null then
    select id into created_contact_id
    from public.emergency_contacts
    where client_request_key = request_idempotency_key
      and patient_id = target_patient_id;
    if created_contact_id is null then
      raise exception 'request key belongs to another contact'
        using errcode = '22023';
    end if;
    return created_contact_id;
  end if;

  insert into public.audit_events (
    actor_profile_id,
    action,
    resource_type,
    resource_id,
    metadata
  ) values (
    auth.uid(),
    'emergency_contact_created',
    'emergency_contact',
    created_contact_id,
    jsonb_build_object('patient_id', target_patient_id)
  );

  return created_contact_id;
end;
$$;

create function public.update_emergency_contact(
  target_contact_id uuid,
  contact_name text,
  contact_relationship text,
  contact_phone text,
  contact_priority smallint
)
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  target_patient_id uuid;
begin
  if nullif(trim(contact_name), '') is null
      or nullif(trim(contact_phone), '') is null then
    raise exception 'name and phone are required' using errcode = '22023';
  end if;

  if contact_priority not between 1 and 100 then
    raise exception 'priority must be between 1 and 100'
      using errcode = '22023';
  end if;

  if trim(contact_phone) !~ '^\+?[0-9][0-9 ()-]{6,24}$' then
    raise exception 'phone number format is invalid' using errcode = '22023';
  end if;

  select patient_id into target_patient_id
  from public.emergency_contacts
  where id = target_contact_id
  for update;

  if target_patient_id is null
      or not private.can_access_patient(target_patient_id) then
    raise exception 'emergency contact not found' using errcode = 'P0002';
  end if;

  update public.emergency_contacts
  set name = trim(contact_name),
      relationship = nullif(trim(contact_relationship), ''),
      phone = trim(contact_phone),
      priority = contact_priority
  where id = target_contact_id;

  insert into public.audit_events (
    actor_profile_id,
    action,
    resource_type,
    resource_id,
    metadata
  ) values (
    auth.uid(),
    'emergency_contact_updated',
    'emergency_contact',
    target_contact_id,
    jsonb_build_object(
      'patient_id', target_patient_id,
      'changed_fields', jsonb_build_array(
        'name', 'relationship', 'phone', 'priority'
      )
    )
  );
end;
$$;

create function public.delete_emergency_contact(target_contact_id uuid)
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  target_patient_id uuid;
begin
  select patient_id into target_patient_id
  from public.emergency_contacts
  where id = target_contact_id
  for update;

  if target_patient_id is null
      or not private.can_access_patient(target_patient_id) then
    raise exception 'emergency contact not found' using errcode = 'P0002';
  end if;

  delete from public.emergency_contacts
  where id = target_contact_id;

  insert into public.audit_events (
    actor_profile_id,
    action,
    resource_type,
    resource_id,
    metadata
  ) values (
    auth.uid(),
    'emergency_contact_deleted',
    'emergency_contact',
    target_contact_id,
    jsonb_build_object('patient_id', target_patient_id)
  );
end;
$$;

revoke all on function public.create_emergency_contact(uuid, text, text, text, smallint, text) from public;
revoke all on function public.update_emergency_contact(uuid, text, text, text, smallint) from public;
revoke all on function public.delete_emergency_contact(uuid) from public;

grant execute on function public.create_emergency_contact(uuid, text, text, text, smallint, text) to authenticated;
grant execute on function public.update_emergency_contact(uuid, text, text, text, smallint) to authenticated;
grant execute on function public.delete_emergency_contact(uuid) to authenticated;

commit;
