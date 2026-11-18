begin;

alter table public.safe_zones
  add column if not exists configured_by_profile_id uuid
    references public.profiles(id) on delete set null,
  add column if not exists configured_at timestamptz;

update public.safe_zones
set configured_at = coalesce(configured_at, updated_at, created_at)
where configured_at is null;

create or replace function private.stamp_safe_zone_configuration()
returns trigger
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
begin
  if tg_op = 'INSERT'
      or new.name is distinct from old.name
      or new.center is distinct from old.center
      or new.radius_meters is distinct from old.radius_meters then
    new.configured_by_profile_id := auth.uid();
    new.configured_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists safe_zones_stamp_configuration
  on public.safe_zones;
create trigger safe_zones_stamp_configuration
before insert or update of name, center, radius_meters
on public.safe_zones
for each row execute function private.stamp_safe_zone_configuration();

revoke all on function private.stamp_safe_zone_configuration() from public;

commit;
