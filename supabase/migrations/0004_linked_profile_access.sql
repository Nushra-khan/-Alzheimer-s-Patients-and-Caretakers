begin;

create policy profiles_linked_caregiver_select
on public.profiles for select
using (
  exists (
    select 1
    from public.caregivers c
    join public.care_relationships cr on cr.caregiver_id = c.id
    where c.profile_id = profiles.id
      and private.owns_patient(cr.patient_id)
      and cr.status = 'active'
      and (cr.valid_from is null or cr.valid_from <= now())
      and (cr.valid_until is null or cr.valid_until > now())
  )
);

create policy devices_linked_patient_select
on public.devices for select
using (
  exists (
    select 1
    from public.patients p
    where p.profile_id = devices.profile_id
      and private.can_access_patient(p.id)
  )
);

commit;
