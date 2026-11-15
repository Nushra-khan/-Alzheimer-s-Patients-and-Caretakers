-- Memora demo accounts for testing. NOT a migration: run it by hand in
-- Supabase Dashboard > SQL Editor, once, after all migrations are applied.
--
--   Patient:   demo.patient@memora.test    / MemoraDemo@2026
--   Caregiver: demo.caregiver@memora.test  / MemoraDemo@2026
--
-- Both accounts are confirmed and already linked. Remove them with
-- demo_users_cleanup.sql before real people use the app.

do $$
declare
  patient_user uuid := gen_random_uuid();
  caregiver_user uuid := gen_random_uuid();
  demo_password text := 'MemoraDemo@2026';
  today date := (now() at time zone 'Asia/Kolkata')::date;
  demo_patient_id uuid;
  demo_caregiver_id uuid;
  new_medication_id uuid;
  medicine record;
begin
  if exists (
    select 1 from auth.users
    where email in ('demo.patient@memora.test', 'demo.caregiver@memora.test')
  ) then
    raise exception 'Demo users already exist. Run demo_users_cleanup.sql first.';
  end if;

  -- Auth accounts. The on_auth_user_created trigger creates the profile and
  -- the patient/caregiver row from the "role" in the metadata.
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at, confirmation_token, recovery_token,
    email_change_token_new, email_change, email_change_token_current,
    phone_change, phone_change_token, reauthentication_token
  ) values
  (
    '00000000-0000-0000-0000-000000000000', patient_user,
    'authenticated', 'authenticated', 'demo.patient@memora.test',
    extensions.crypt(demo_password, extensions.gen_salt('bf')), now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb,
    '{"display_name": "Ramesh Sharma (Demo)", "role": "patient"}'::jsonb,
    now(), now(), '', '', '', '', '', '', '', ''
  ),
  (
    '00000000-0000-0000-0000-000000000000', caregiver_user,
    'authenticated', 'authenticated', 'demo.caregiver@memora.test',
    extensions.crypt(demo_password, extensions.gen_salt('bf')), now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb,
    '{"display_name": "Sunita Sharma (Demo)", "role": "caregiver"}'::jsonb,
    now(), now(), '', '', '', '', '', '', '', ''
  );

  insert into auth.identities (
    id, provider_id, user_id, identity_data, provider,
    last_sign_in_at, created_at, updated_at
  ) values
  (
    gen_random_uuid(), patient_user::text, patient_user,
    jsonb_build_object(
      'sub', patient_user::text,
      'email', 'demo.patient@memora.test',
      'email_verified', true
    ),
    'email', now(), now(), now()
  ),
  (
    gen_random_uuid(), caregiver_user::text, caregiver_user,
    jsonb_build_object(
      'sub', caregiver_user::text,
      'email', 'demo.caregiver@memora.test',
      'email_verified', true
    ),
    'email', now(), now(), now()
  );

  select id into demo_patient_id
  from public.patients where profile_id = patient_user;
  select id into demo_caregiver_id
  from public.caregivers where profile_id = caregiver_user;

  if demo_patient_id is null or demo_caregiver_id is null then
    raise exception 'Patient/caregiver rows were not created. Apply all migrations first.';
  end if;

  update public.profiles set phone = '+91 98765 00001' where id = patient_user;
  update public.profiles set phone = '+91 98765 00002' where id = caregiver_user;

  update public.patients
  set date_of_birth = date '1954-01-15',
      location_sharing_enabled = true
  where id = demo_patient_id;

  -- Link caregiver and patient, as if an invitation code had been accepted.
  insert into public.care_relationships (
    patient_id, caregiver_id, status, valid_from
  ) values (
    demo_patient_id, demo_caregiver_id, 'active', now()
  );

  -- Daily medicines. Today's doses are created when the app loads them.
  for medicine in
    select * from (values
      ('Memantine HCl', '5 mg • 1 tablet', 'Take with breakfast', time '09:00'),
      ('Vitamin B12 & D3', '1 capsule', 'After lunch with water', time '14:00'),
      ('Donepezil', '10 mg • 1 tablet', 'Take with dinner', time '20:00')
    ) as m(name, dosage, instructions, local_time)
  loop
    insert into public.medications (patient_id, name, dosage, instructions)
    values (demo_patient_id, medicine.name, medicine.dosage, medicine.instructions)
    returning id into new_medication_id;

    insert into public.medication_schedules (
      medication_id, local_time, timezone, recurrence, starts_on
    ) values (
      new_medication_id, medicine.local_time, 'Asia/Kolkata',
      jsonb_build_object('frequency', 'daily'), today
    );
  end loop;

  insert into public.routine_schedules (
    patient_id, title, description, local_time, timezone, recurrence
  ) values
    (demo_patient_id, 'Morning garden walk', '15-minute gentle walk',
     time '07:30', 'Asia/Kolkata', jsonb_build_object('frequency', 'daily')),
    (demo_patient_id, 'Drink water', 'Two glasses of water',
     time '11:00', 'Asia/Kolkata', jsonb_build_object('frequency', 'daily')),
    (demo_patient_id, 'Music time', 'Listen to favourite old songs',
     time '16:00', 'Asia/Kolkata', jsonb_build_object('frequency', 'daily')),
    (demo_patient_id, 'Evening rest', 'Quiet breathing in the living room',
     time '18:30', 'Asia/Kolkata', jsonb_build_object('frequency', 'daily'));

  insert into public.emergency_contacts (
    patient_id, name, relationship, phone, priority
  ) values
    (demo_patient_id, 'Sunita Sharma', 'Spouse', '+91 98765 00002', 1),
    (demo_patient_id, 'Anil Sharma', 'Son', '+91 98765 00003', 2),
    (demo_patient_id, 'Dr. V. K. Gupta', 'Neurologist', '+91 11 2614 0000', 3);

  insert into public.safe_zones (patient_id, name, center, radius_meters)
  values (
    demo_patient_id,
    'Home (Vasant Vihar)',
    extensions.st_geogfromtext('SRID=4326;POINT(77.1610 28.5562)'),
    300
  );

  -- Patient phone seen recently, so the dashboard shows it online.
  insert into public.devices (profile_id, platform, last_seen_at)
  values (patient_user, 'android', now());

  -- One past, resolved SOS so the Alerts tab has history.
  insert into public.alerts (
    patient_id, type, severity, status, title, message,
    rule_version, dedupe_key, occurred_at
  ) values (
    demo_patient_id, 'sos', 'critical', 'resolved',
    'SOS requires attention', 'The patient activated the SOS control.',
    'demo', 'demo:sos:' || demo_patient_id::text, now() - interval '1 day'
  );

  raise notice 'Demo users created: demo.patient@memora.test and demo.caregiver@memora.test';
end;
$$;
