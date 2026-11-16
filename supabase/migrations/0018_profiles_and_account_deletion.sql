begin;

-- ---------------------------------------------------------------------------
-- Profile details
-- ---------------------------------------------------------------------------

-- Photo of any user, stored in the private "profile-photos" bucket as
-- <profile id>/<file name>.
alter table public.profiles
  add column if not exists photo_path text
    check (photo_path is null or char_length(photo_path) <= 300);

alter table public.caregivers
  add column if not exists relationship text
    check (relationship is null or char_length(relationship) <= 80);

-- Details that help caregivers, doctors and strangers care for the patient.
alter table public.patients
  add column if not exists preferred_name text
    check (preferred_name is null or char_length(preferred_name) <= 80),
  add column if not exists gender text
    check (gender is null or gender in ('female', 'male', 'other', 'prefer_not_to_say')),
  add column if not exists languages text
    check (languages is null or char_length(languages) <= 200),
  add column if not exists home_address text
    check (home_address is null or char_length(home_address) <= 300),
  add column if not exists blood_group text
    check (blood_group is null or blood_group in (
      'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'unknown'
    )),
  add column if not exists food_allergies text
    check (food_allergies is null or char_length(food_allergies) <= 300),
  add column if not exists medicine_allergies text
    check (medicine_allergies is null or char_length(medicine_allergies) <= 300),
  add column if not exists other_allergies text
    check (other_allergies is null or char_length(other_allergies) <= 300),
  add column if not exists medical_conditions text
    check (medical_conditions is null or char_length(medical_conditions) <= 500),
  add column if not exists dementia_stage text
    check (dementia_stage is null or dementia_stage in ('early', 'middle', 'late', 'unknown')),
  add column if not exists doctor_name text
    check (doctor_name is null or char_length(doctor_name) <= 120),
  add column if not exists doctor_phone text
    check (doctor_phone is null or char_length(doctor_phone) <= 30),
  add column if not exists preferred_hospital text
    check (preferred_hospital is null or char_length(preferred_hospital) <= 200),
  add column if not exists medical_notes text
    check (medical_notes is null or char_length(medical_notes) <= 1000),
  add column if not exists mobility_aids text
    check (mobility_aids is null or char_length(mobility_aids) <= 200),
  add column if not exists sensory_aids text
    check (sensory_aids is null or char_length(sensory_aids) <= 200),
  add column if not exists diet_needs text
    check (diet_needs is null or char_length(diet_needs) <= 300),
  add column if not exists wandering_risk text
    check (wandering_risk is null or wandering_risk in ('low', 'medium', 'high', 'unknown')),
  add column if not exists calming_things text
    check (calming_things is null or char_length(calming_things) <= 500),
  add column if not exists upsetting_things text
    check (upsetting_things is null or char_length(upsetting_things) <= 500),
  add column if not exists id_bracelet_number text
    check (id_bracelet_number is null or char_length(id_bracelet_number) <= 60);

-- Trims a text field and turns blanks into null.
create function private.clean_text(value text, max_length integer)
returns text
language sql
immutable
as $$
  select nullif(left(trim(coalesce(value, '')), max_length), '');
$$;

create function private.is_valid_phone(value text)
returns boolean
language sql
immutable
as $$
  select value is null or value ~ '^\+?[0-9 ()-]{6,20}$';
$$;

-- Saves the patient's profile. The patient and active caregivers may edit.
-- Every key in [details] is optional except full_name.
create function public.update_patient_profile(
  target_patient_id uuid,
  details jsonb
)
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  target_profile_id uuid;
  full_name text := private.clean_text(details ->> 'full_name', 120);
  birth_date date;
  doctor_phone_value text := private.clean_text(details ->> 'doctor_phone', 30);
begin
  if auth.uid() is null or not private.can_access_patient(target_patient_id) then
    raise exception 'patient access required' using errcode = '42501';
  end if;

  if full_name is null then
    raise exception 'full name is required' using errcode = '22023';
  end if;

  if nullif(details ->> 'date_of_birth', '') is not null then
    begin
      birth_date := (details ->> 'date_of_birth')::date;
    exception when others then
      raise exception 'date of birth is not a valid date' using errcode = '22023';
    end;
    if birth_date < date '1900-01-01' or birth_date > current_date then
      raise exception 'date of birth must be between 1900 and today' using errcode = '22023';
    end if;
  end if;

  if not private.is_valid_phone(doctor_phone_value) then
    raise exception 'doctor phone number is not valid' using errcode = '22023';
  end if;

  select profile_id into target_profile_id
  from public.patients
  where id = target_patient_id
  for update;

  update public.profiles
  set display_name = full_name
  where id = target_profile_id;

  -- Enum columns are checked by the table constraints; a bad value raises.
  update public.patients
  set date_of_birth = birth_date,
      preferred_name = private.clean_text(details ->> 'preferred_name', 80),
      gender = private.clean_text(details ->> 'gender', 30),
      languages = private.clean_text(details ->> 'languages', 200),
      home_address = private.clean_text(details ->> 'home_address', 300),
      blood_group = private.clean_text(details ->> 'blood_group', 10),
      food_allergies = private.clean_text(details ->> 'food_allergies', 300),
      medicine_allergies = private.clean_text(details ->> 'medicine_allergies', 300),
      other_allergies = private.clean_text(details ->> 'other_allergies', 300),
      medical_conditions = private.clean_text(details ->> 'medical_conditions', 500),
      dementia_stage = private.clean_text(details ->> 'dementia_stage', 20),
      doctor_name = private.clean_text(details ->> 'doctor_name', 120),
      doctor_phone = doctor_phone_value,
      preferred_hospital = private.clean_text(details ->> 'preferred_hospital', 200),
      medical_notes = private.clean_text(details ->> 'medical_notes', 1000),
      mobility_aids = private.clean_text(details ->> 'mobility_aids', 200),
      sensory_aids = private.clean_text(details ->> 'sensory_aids', 200),
      diet_needs = private.clean_text(details ->> 'diet_needs', 300),
      wandering_risk = private.clean_text(details ->> 'wandering_risk', 20),
      calming_things = private.clean_text(details ->> 'calming_things', 500),
      upsetting_things = private.clean_text(details ->> 'upsetting_things', 500),
      id_bracelet_number = private.clean_text(details ->> 'id_bracelet_number', 60)
  where id = target_patient_id;

  insert into public.audit_events (
    actor_profile_id, action, resource_type, resource_id, metadata
  ) values (
    auth.uid(), 'patient_profile_updated', 'patient', target_patient_id,
    jsonb_build_object('fields', (select jsonb_agg(k) from jsonb_object_keys(details) k))
  );
end;
$$;

-- Lets a caregiver update their own name, phone and relationship.
create function public.update_caregiver_profile(
  full_name text,
  phone_number text,
  relationship_to_patient text
)
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  clean_name text := private.clean_text(full_name, 120);
  clean_phone text := private.clean_text(phone_number, 30);
begin
  if auth.uid() is null or not exists (
    select 1 from public.caregivers where profile_id = auth.uid()
  ) then
    raise exception 'caregiver access required' using errcode = '42501';
  end if;

  if clean_name is null then
    raise exception 'full name is required' using errcode = '22023';
  end if;

  if not private.is_valid_phone(clean_phone) then
    raise exception 'phone number is not valid' using errcode = '22023';
  end if;

  update public.profiles
  set display_name = clean_name, phone = clean_phone
  where id = auth.uid();

  update public.caregivers
  set relationship = private.clean_text(relationship_to_patient, 80)
  where profile_id = auth.uid();

  insert into public.audit_events (
    actor_profile_id, action, resource_type, resource_id, metadata
  ) values (
    auth.uid(), 'caregiver_profile_updated', 'profile', auth.uid(), '{}'::jsonb
  );
end;
$$;

-- True when the current user may manage photos in a profile's folder: their
-- own folder, or the folder of a patient they care for.
create function private.can_manage_profile_files(folder text)
returns boolean
language sql
stable
security definer
set search_path = public, private, pg_temp
as $$
  select auth.uid() is not null and (
    folder = auth.uid()::text
    or exists (
      select 1 from public.patients p
      where p.profile_id::text = folder
        and private.is_active_caregiver(p.id)
    )
  );
$$;

-- True when the current user may see photos in a profile's folder: their own,
-- their patient's, or a caregiver linked to their patient.
create function private.can_view_profile_files(folder text)
returns boolean
language sql
stable
security definer
set search_path = public, private, pg_temp
as $$
  select auth.uid() is not null and (
    private.can_manage_profile_files(folder)
    or exists (
      select 1 from public.patients p
      where p.profile_id::text = folder and private.can_access_patient(p.id)
    )
    or exists (
      select 1
      from public.caregivers c
      join public.care_relationships cr on cr.caregiver_id = c.id
      where c.profile_id::text = folder
        and cr.status = 'active'
        and private.can_access_patient(cr.patient_id)
    )
  );
$$;

revoke all on function private.can_manage_profile_files(text) from public;
revoke all on function private.can_view_profile_files(text) from public;
grant execute on function private.can_manage_profile_files(text) to authenticated;
grant execute on function private.can_view_profile_files(text) to authenticated;

-- Records which uploaded file is a profile's photo.
create function public.set_profile_photo(
  target_profile_id uuid,
  new_photo_path text
)
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
begin
  if not private.can_manage_profile_files(target_profile_id::text) then
    raise exception 'profile access required' using errcode = '42501';
  end if;

  if new_photo_path is not null
      and split_part(new_photo_path, '/', 1) <> target_profile_id::text then
    raise exception 'photo must be in the profile''s folder' using errcode = '22023';
  end if;

  update public.profiles
  set photo_path = private.clean_text(new_photo_path, 300)
  where id = target_profile_id;

  insert into public.audit_events (
    actor_profile_id, action, resource_type, resource_id, metadata
  ) values (
    auth.uid(), 'profile_photo_updated', 'profile', target_profile_id, '{}'::jsonb
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Photo storage: private bucket, 5 MB images only
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'profile-photos', 'profile-photos', false, 5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

create policy profile_photos_select on storage.objects for select
  to authenticated
  using (
    bucket_id = 'profile-photos'
    and private.can_view_profile_files((storage.foldername(name))[1])
  );

create policy profile_photos_insert on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'profile-photos'
    and private.can_manage_profile_files((storage.foldername(name))[1])
  );

create policy profile_photos_update on storage.objects for update
  to authenticated
  using (
    bucket_id = 'profile-photos'
    and private.can_manage_profile_files((storage.foldername(name))[1])
  );

create policy profile_photos_delete on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'profile-photos'
    and private.can_manage_profile_files((storage.foldername(name))[1])
  );

-- ---------------------------------------------------------------------------
-- Account deletion (Google Play requirement)
-- ---------------------------------------------------------------------------

-- Deletes the signed-in user's account. The app removes their photos from
-- storage first (Supabase does not allow deleting storage files from SQL).
--   Patient:   deletes the account and all care data; caregivers are unlinked.
--   Caregiver: deletes the account and their links; patient data stays.
create function public.delete_my_account()
returns text
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  me uuid := auth.uid();
  my_patient_id uuid;
  my_caregiver_id uuid;
  deleted_role text;
begin
  if me is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  select id into my_patient_id from public.patients where profile_id = me;
  select id into my_caregiver_id from public.caregivers where profile_id = me;
  deleted_role := case
    when my_patient_id is not null then 'patient'
    when my_caregiver_id is not null then 'caregiver'
    else 'unassigned'
  end;

  -- Rows that point at this profile without cascading.
  update public.audit_events set actor_profile_id = null where actor_profile_id = me;
  update public.alert_events set actor_profile_id = null where actor_profile_id = me;
  delete from public.notification_outbox where recipient_profile_id = me;
  delete from public.consents where granted_by = me;
  if my_caregiver_id is not null then
    delete from public.caregiver_responses where caregiver_id = my_caregiver_id;
  end if;
  if my_patient_id is not null then
    -- Dose history goes with the patient's doses.
    delete from public.dose_events de
    using public.dose_instances di
    where de.dose_instance_id = di.id and di.patient_id = my_patient_id;
  end if;
  delete from public.dose_events where actor_profile_id = me;

  -- Keep a record that an account was deleted, without personal data.
  insert into public.audit_events (
    actor_profile_id, action, resource_type, resource_id, metadata
  ) values (
    null, 'account_deleted', 'profile', me,
    jsonb_build_object('role', deleted_role)
  );

  -- Cascades to profile, patient/caregiver rows, relationships, medications,
  -- doses, routines, locations, safe zones, alerts and devices.
  delete from auth.users where id = me;

  return deleted_role;
end;
$$;

revoke all on function public.update_patient_profile(uuid, jsonb) from public;
revoke all on function public.update_caregiver_profile(text, text, text) from public;
revoke all on function public.set_profile_photo(uuid, text) from public;
revoke all on function public.delete_my_account() from public;
grant execute on function public.update_patient_profile(uuid, jsonb) to authenticated;
grant execute on function public.update_caregiver_profile(text, text, text) to authenticated;
grant execute on function public.set_profile_photo(uuid, text) to authenticated;
grant execute on function public.delete_my_account() to authenticated;

commit;
