begin;

create function public.create_care_invitation()
returns table (invitation_token text, expires_at timestamptz)
language plpgsql
security definer
set search_path = public, private, extensions, pg_temp
as $$
declare
  target_patient_id uuid;
begin
  select id into target_patient_id
  from public.patients
  where profile_id = auth.uid();

  if target_patient_id is null then
    raise exception 'patient access required' using errcode = '42501';
  end if;

  update public.care_invitations
  set revoked_at = now()
  where patient_id = target_patient_id
    and accepted_at is null
    and revoked_at is null;

  invitation_token := upper(encode(gen_random_bytes(8), 'hex'));
  expires_at := now() + interval '15 minutes';

  insert into public.care_invitations (
    patient_id,
    token_hash,
    expires_at
  ) values (
    target_patient_id,
    encode(digest(invitation_token, 'sha256'), 'hex'),
    expires_at
  );

  return next;
end;
$$;

create function public.accept_care_invitation(invitation_token text)
returns uuid
language plpgsql
security definer
set search_path = public, private, extensions, pg_temp
as $$
declare
  target_invitation public.care_invitations;
  actor_caregiver_id uuid;
begin
  if auth.uid() is null or nullif(trim(invitation_token), '') is null then
    raise exception 'valid invitation required' using errcode = '22023';
  end if;

  select id into actor_caregiver_id
  from public.caregivers
  where profile_id = auth.uid();

  if actor_caregiver_id is null then
    raise exception 'caregiver access required' using errcode = '42501';
  end if;

  select * into target_invitation
  from public.care_invitations
  where token_hash = encode(digest(upper(trim(invitation_token)), 'sha256'), 'hex')
    and accepted_at is null
    and revoked_at is null
    and expires_at > now()
  for update;

  if target_invitation.id is null then
    raise exception 'invitation is invalid or expired' using errcode = 'P0002';
  end if;

  insert into public.care_relationships (
    patient_id,
    caregiver_id,
    status,
    valid_from
  ) values (
    target_invitation.patient_id,
    actor_caregiver_id,
    'active',
    now()
  )
  on conflict (patient_id, caregiver_id) do update
  set status = 'active',
      valid_from = now(),
      valid_until = null,
      updated_at = now();

  update public.care_invitations
  set accepted_at = now()
  where id = target_invitation.id;

  return target_invitation.patient_id;
end;
$$;

revoke all on function public.create_care_invitation() from public;
revoke all on function public.accept_care_invitation(text) from public;
grant execute on function public.create_care_invitation() to authenticated;
grant execute on function public.accept_care_invitation(text) to authenticated;

commit;
