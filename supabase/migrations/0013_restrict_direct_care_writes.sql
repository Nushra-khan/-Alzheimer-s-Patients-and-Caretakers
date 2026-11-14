begin;

-- Care changes must pass through the reviewed security-definer functions added
-- in migrations 0006-0011. The original broad policies allowed authenticated
-- clients to write these tables directly, bypassing validation and audit logs.
-- Each select policy is dropped before it is recreated because 0011 already
-- created emergency_contacts_authorized_select; recreating it without the
-- drop aborted this whole migration.
drop policy if exists emergency_contacts_authorized_all
  on public.emergency_contacts;
drop policy if exists emergency_contacts_authorized_select
  on public.emergency_contacts;
create policy emergency_contacts_authorized_select
  on public.emergency_contacts for select
  using (private.can_access_patient(patient_id));

drop policy if exists medications_authorized_all
  on public.medications;
drop policy if exists medications_authorized_select
  on public.medications;
create policy medications_authorized_select
  on public.medications for select
  using (private.can_access_patient(patient_id));

drop policy if exists medication_schedules_authorized_all
  on public.medication_schedules;
drop policy if exists medication_schedules_authorized_select
  on public.medication_schedules;
create policy medication_schedules_authorized_select
  on public.medication_schedules for select
  using (
    exists (
      select 1
      from public.medications medication
      where medication.id = medication_id
        and private.can_access_patient(medication.patient_id)
    )
  );

drop policy if exists routines_authorized_all
  on public.routine_schedules;
drop policy if exists routines_authorized_select
  on public.routine_schedules;
create policy routines_authorized_select
  on public.routine_schedules for select
  using (private.can_access_patient(patient_id));

drop policy if exists safe_zones_authorized_all
  on public.safe_zones;
drop policy if exists safe_zones_authorized_select
  on public.safe_zones;
create policy safe_zones_authorized_select
  on public.safe_zones for select
  using (private.can_access_patient(patient_id));

commit;
