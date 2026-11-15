begin;

-- Accounts created through Google (or any provider that does not send a role)
-- no longer default to caregiver. They get a profile only, and the person
-- chooses patient or caregiver in the app with choose_account_role().
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  account_role text;
  account_name text;
begin
  account_role := lower(nullif(trim(new.raw_user_meta_data ->> 'role'), ''));

  account_name := coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'name'), ''),
    nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
    'Memora user'
  );

  insert into public.profiles (id, display_name)
  values (new.id, account_name)
  on conflict (id) do update
    set display_name = excluded.display_name;

  if account_role = 'patient' then
    insert into public.patients (profile_id)
    values (new.id)
    on conflict (profile_id) do nothing;
  elsif account_role = 'caregiver' then
    insert into public.caregivers (profile_id)
    values (new.id)
    on conflict (profile_id) do nothing;
  end if;

  return new;
end;
$$;

-- Lets a signed-in user without a role become a patient or a caregiver.
-- The choice is permanent: an account that already has a role keeps it.
create function public.choose_account_role(selected_role text)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  normalized_role text := lower(trim(coalesce(selected_role, '')));
  account_name text;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  if normalized_role not in ('patient', 'caregiver') then
    raise exception 'role must be patient or caregiver' using errcode = '22023';
  end if;

  -- Serialize choices for this account so two taps cannot create both roles.
  perform pg_advisory_xact_lock(hashtext('account_role:' || auth.uid()::text));

  if exists (select 1 from public.patients where profile_id = auth.uid()) then
    return 'patient';
  end if;
  if exists (select 1 from public.caregivers where profile_id = auth.uid()) then
    return 'caregiver';
  end if;

  select coalesce(
    nullif(trim(u.raw_user_meta_data ->> 'display_name'), ''),
    nullif(trim(u.raw_user_meta_data ->> 'full_name'), ''),
    nullif(trim(u.raw_user_meta_data ->> 'name'), ''),
    nullif(split_part(coalesce(u.email, ''), '@', 1), ''),
    'Memora user'
  )
  into account_name
  from auth.users u
  where u.id = auth.uid();

  insert into public.profiles (id, display_name)
  values (auth.uid(), coalesce(account_name, 'Memora user'))
  on conflict (id) do nothing;

  if normalized_role = 'patient' then
    insert into public.patients (profile_id) values (auth.uid());
  else
    insert into public.caregivers (profile_id) values (auth.uid());
  end if;

  insert into public.audit_events (
    actor_profile_id, action, resource_type, resource_id, metadata
  ) values (
    auth.uid(),
    'account_role_selected',
    'profile',
    auth.uid(),
    jsonb_build_object('role', normalized_role)
  );

  return normalized_role;
end;
$$;

revoke all on function public.choose_account_role(text) from public;
grant execute on function public.choose_account_role(text) to authenticated;

commit;
