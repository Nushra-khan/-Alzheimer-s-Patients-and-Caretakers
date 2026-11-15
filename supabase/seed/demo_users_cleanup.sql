-- Removes the Memora demo accounts created by demo_users.sql and all of
-- their data. Run in Supabase Dashboard > SQL Editor.

do $$
declare
  demo_ids uuid[];
begin
  select array_agg(id) into demo_ids
  from auth.users
  where email in ('demo.patient@memora.test', 'demo.caregiver@memora.test');

  if demo_ids is null then
    raise notice 'No demo users found.';
    return;
  end if;

  -- Rows that point at the demo profiles without cascading.
  delete from public.audit_events where actor_profile_id = any(demo_ids);
  delete from public.notification_outbox where recipient_profile_id = any(demo_ids);
  delete from public.alert_events where actor_profile_id = any(demo_ids);
  delete from public.caregiver_responses
  where caregiver_id in (
    select id from public.caregivers where profile_id = any(demo_ids)
  );
  delete from public.consents where granted_by = any(demo_ids);

  -- Deleting the auth users cascades to profiles, patients, caregivers,
  -- medicines, doses, routines, contacts, safe zones and alerts.
  delete from auth.users where id = any(demo_ids);

  raise notice 'Removed % demo users.', array_length(demo_ids, 1);
end;
$$;
