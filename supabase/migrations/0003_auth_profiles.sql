begin;

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
  account_role := lower(coalesce(new.raw_user_meta_data ->> 'role', 'caregiver'));
  if account_role not in ('patient', 'caregiver') then
    account_role := 'caregiver';
  end if;

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
  else
    insert into public.caregivers (profile_id)
    values (new.id)
    on conflict (profile_id) do nothing;
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

insert into public.profiles (id, display_name)
select
  user_record.id,
  coalesce(
    nullif(trim(user_record.raw_user_meta_data ->> 'display_name'), ''),
    nullif(trim(user_record.raw_user_meta_data ->> 'full_name'), ''),
    nullif(trim(user_record.raw_user_meta_data ->> 'name'), ''),
    nullif(split_part(coalesce(user_record.email, ''), '@', 1), ''),
    'Memora user'
  )
from auth.users as user_record
on conflict (id) do nothing;

insert into public.patients (profile_id)
select user_record.id
from auth.users as user_record
where lower(coalesce(user_record.raw_user_meta_data ->> 'role', 'caregiver')) = 'patient'
on conflict (profile_id) do nothing;

insert into public.caregivers (profile_id)
select user_record.id
from auth.users as user_record
where lower(coalesce(user_record.raw_user_meta_data ->> 'role', 'caregiver')) <> 'patient'
  and not exists (
    select 1 from public.patients where patients.profile_id = user_record.id
  )
on conflict (profile_id) do nothing;

commit;
