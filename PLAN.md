# Alzheimer’s Care — Production Project Plan

## 1. Project overview

Alzheimer’s Care is a mobile caregiver-support application for people living
with Alzheimer’s disease or related cognitive impairment. It provides reminders,
patient-authorized location sharing, safe-zone monitoring, SOS events, caregiver
alerts, response tracking, and activity summaries.

The application does not diagnose or treat a condition, verify medication
ingestion, guarantee continuous monitoring, or replace medical care, supervision,
or emergency services. Medical predictions, fall detection, and emergency-service
integration require separate validation before release.

Initial production target: India and Android. Add iOS after equivalent background
location and notification testing.

## 2. Goals

- Help patients follow medication and daily routines.
- Let patients or authorized representatives control caregiver access.
- Notify approved caregivers about SOS, overdue doses, safe-zone transitions,
  and unavailable patient devices.
- Show when and how every patient status was last updated.
- Record caregiver acknowledgement, action, and alert resolution.
- Protect identity, medical, activity, and precise-location data.
- Support consented analytics and later validated AI research.

## 3. Users

### Patient

- Receives medicine and routine reminders.
- Marks a scheduled dose as reported taken or requests help.
- Uses an accessible SOS button.
- Sees location-sharing, permission, connectivity, and sync status.
- Reviews approved caregivers and privacy settings.

### Caregiver

- Views only assigned patients and permitted information.
- Manages medication and routine schedules.
- Views current or last-known location with accuracy and timestamp.
- Receives, acknowledges, acts on, and resolves alerts.
- Reviews medication, alert, location, and activity history.

Caregiver access uses an expiring invitation and patient or authorized-
representative approval. Users cannot grant themselves caregiver access by
selecting a role at signup.

## 4. Feature scope

| Feature | Release stage | Requirement |
|---|---|---|
| Authentication and profiles | Launch | Secure sessions and account recovery |
| Patient-caregiver linking | Launch | Invitation, consent, revocation, audit trail |
| Medication schedules and reminders | Launch | Recurrence, timezone, dose history |
| Routine reminders | Launch | Local delivery and backend synchronization |
| SOS and caregiver alerts | Launch | Deduplication, retries, acknowledgement |
| Push notifications | Launch | Delivery records and token rotation |
| Alert and response history | Launch | Authorized, immutable lifecycle records |
| Offline event queue | Launch | Encrypted storage and safe retries |
| Safe-zone monitoring | Pilot | Background-location consent and store approval |
| Live or last-known location | Pilot | Accuracy, timestamp, and unavailable state |
| Activity summaries | Pilot | Defined sensor source; no medical inference |
| Multi-patient dashboard | Later | Permission isolation and load testing |
| Voice assistance | Later | Accessible fallback and privacy review |
| Wearable integration | Later | Supported device API and reliability testing |
| Doctor dashboard | Validated future | Clinical workflow and explicit consent |
| Fall or inactivity detection | Validated future | Safety and false-alert validation |
| Emergency-service integration | Validated future | Supported provider and operational agreement |
| AI risk or wandering prediction | Research only | Suitable data and clinical/regulatory validation |
| Personalized reminders | Research only | User control and measured benefit |

Gated features are not marketed or enabled until their stated requirements pass.

## 5. Technology stack

| Layer | Technology | Purpose |
|---|---|---|
| Mobile | Flutter and Dart | Android and later iOS apps |
| Backend | Supabase | Authentication, database, APIs, Realtime |
| Database | PostgreSQL with PostGIS | Application and safe-zone data |
| Trusted logic | Database functions and Supabase Edge Functions | Authorized operations and alert rules |
| Scheduled jobs | Supabase Cron/pg_cron | Dose, heartbeat, retry, and retention checks |
| Notifications | Firebase Cloud Messaging | Caregiver push notifications |
| Maps | Licensed map SDK | Location and safe-zone display |
| Offline storage | Encrypted local database | Minimum cached state and event queue |
| Analytics | SQL summaries; Python later | Reports and controlled research |
| Testing and delivery | Flutter tests, database tests, CI/CD | Automated verification and releases |

Use separate development, staging, and production Supabase/Firebase projects.

## 6. Architecture

```text
Patient Flutter app                     Caregiver Flutter app
        |                                        |
        +------------ Supabase Auth -------------+
                         |
                 Protected APIs/RPC
                         |
              PostgreSQL + PostGIS + RLS
                |          |          |
          alert rules  audit log    Realtime
                |
       alert + outbox transaction
                |
        retrying delivery worker
                |
                 FCM
                |
          caregiver devices

Scheduled jobs: overdue doses, device heartbeats, retries, retention, summaries
```

The backend is the system of record. Mobile clients report observations and user
actions but cannot assign roles or bypass Row Level Security. Push notification
delivery is not proof that a caregiver saw or acknowledged an alert; apps always
reconcile alert state with the backend.

## 7. Screens and navigation

### Shared screens

- Welcome, login, signup, account recovery, invitation acceptance, consent, and
  contextual permission education.

### Patient app

Use three primary destinations: `Today`, `SOS`, and `Settings`.

- **Today:** next medicine, routine reminders, reported-taken and help actions.
- **SOS:** large button, short cancellation period, server receipt state,
  emergency contacts, and manual call action.
- **Settings:** caregivers, sharing status, permissions, privacy, accessibility,
  profile, and logout.

### Caregiver app

Use `Dashboard`, `Patient`, `Alerts`, `Schedules`, and `Profile`.

- **Dashboard:** patient status, freshness, next dose, recent alerts, location,
  and device health.
- **Patient:** minimum profile information, caregivers, safe zones, and permissions.
- **Location:** map, marker, zone, accuracy, timestamp, and state.
- **Safe-zone setup:** map center, radius, schedule, grace period, and alert toggle.
- **Schedules:** medications, dose history, and medicine/water/walk/sleep reminders.
- **Alerts:** active, acknowledged, and resolved alerts with response history.
- **Activity:** weekly dose, zone, alert, response-time, and device-uptime charts.
- **Profile:** notifications, emergency contacts, privacy, accessibility, and logout.

Location states are `inside`, `outside`, `stale`, `offline`, `permission denied`,
or `unknown`. Sensitive medical or location details never appear on the lock screen.

## 8. Database design

Use UUID keys, timezone-aware timestamps, constraints, indexed foreign keys,
`created_at`, and `updated_at`.

### Identity and access

- `profiles`
- `patients`
- `caregivers`
- `care_relationships`
- `care_invitations`
- `consents`
- `emergency_contacts`
- `audit_events`

### Medication and routines

- `medications`
- `medication_schedules`
- `dose_instances`
- `dose_events`
- `routine_schedules`
- `reminder_preferences`

Status belongs to each scheduled dose, not to the medication. The app records
`reported taken`; it does not claim to verify ingestion.

### Location, activity, and devices

- `safe_zones`
- `location_observations`
- `safe_zone_transitions`
- `activity_observations`
- `daily_activity_summaries`
- `devices`
- `device_heartbeats`

Location observations include accuracy, device timestamp, and server receipt time.
Raw precise location has a short configured retention period.

### Alerts and notifications

- `alert_rules`
- `alerts`
- `alert_events`
- `caregiver_responses`
- `notification_outbox`
- `notification_attempts`

Alert lifecycle:

`created -> queued -> delivered -> acknowledged -> action_taken -> resolved`

Cancellation, expiry, and delivery failure are also recorded. Alert creation and
notification queuing occur in one database transaction.

## 9. Alert rules

### SOS

1. Patient triggers SOS with an idempotency key.
2. A short cancellation period reduces accidental alerts.
3. The server creates the alert and notification work atomically.
4. Failed notification attempts are retried and recorded.
5. The patient sees sent or acknowledged state, not “help is on the way.”

### Overdue medication

1. The server generates dose instances from active schedules.
2. It checks for a reported dose after the configured grace period.
3. It creates only one active alert per overdue dose.
4. Timezone changes, edits, skips, and corrections remain audited.

### Safe-zone transition

1. Reject observations that are too old or inaccurate.
2. Calculate distance with PostGIS.
3. Require multiple readings or a dwell period.
4. Use separate exit and re-entry thresholds to prevent boundary flapping.
5. Apply an alert cooldown and deterministic duplicate key.
6. Treat missing location as unknown, not safe.

### Device unavailable

A server job checks the last heartbeat and reports the device as unavailable. It
does not interpret missing device data as patient inactivity.

Fall, inactivity, abnormal-movement, and AI alerts remain disabled until validated.

## 10. Offline and mobile behavior

- Queue patient actions locally with idempotency keys and encrypted storage.
- Retry safely and reconcile the final server result.
- Clear sensitive cached data on logout or revoked access.
- Keep overdue-dose evaluation on the server.
- Request foreground location first and background location only when enabling
  safe-zone monitoring.
- Continue non-location features when location is denied.
- Handle approximate location, revoked permission, disabled GPS, force-stop,
  reboot, token rotation, app termination, and battery restrictions.
- Always show last successful sync and degraded-service state.

## 11. Security, privacy, and consent

- Enable and test RLS for every exposed table, operation, storage bucket, and
  Realtime channel.
- Allow access only through active patient-caregiver relationships.
- Put privileged changes behind protected server functions.
- Never include service credentials in the Flutter app.
- Require MFA and least privilege for production administrators.
- Rate-limit login, invitations, SOS creation, and notification endpoints.
- Exclude sensitive values, tokens, and coordinates from logs.
- Use synthetic data in development, tests, screenshots, and demonstrations.
- Provide clear consent, caregiver revocation, access, correction, export,
  grievance, and deletion workflows.
- Define and automate data-retention periods.
- Provide a way to report and stop unauthorized tracking.
- Complete privacy, security, and legal/regulatory review before public launch.
- Perform threat modeling and independent penetration testing.

## 12. Accessibility and visual design

- Large touch targets, readable text, screen-reader support, logical focus order,
  strong contrast, reduced motion, and 200% text scaling.
- Do not communicate severity by color alone.
- Use plain language and confirmations for consequential actions.
- Keep the proposed purple, white, and light-lavender theme only where contrast
  requirements pass.
- Test critical flows with representative users under proper consent.

## 13. Flutter project structure

```text
lib/
  app/                 # app, router, theme
  core/                # auth, database, errors, offline, permissions
  features/
    onboarding/
    relationships/
    patient_profile/
    caregiver_dashboard/
    medications/
    reminders/
    sos/
    alerts/
    location/
    safe_zones/
    activity/
    settings/
  shared/              # models and reusable widgets
supabase/
  migrations/
  functions/
  tests/
test/
integration_test/
docs/
```

## 14. Development phases

### Phase 0 — scope and compliance

- Confirm intended use, prohibited claims, India scope, and Android-first release.
- Complete initial privacy and regulatory review.
- Define retention, support ownership, and release criteria.

### Phase 1 — foundation

- Create Flutter app, accessible theme, environments, migrations, and CI.
- Implement authentication, invitations, consent, RLS, and audit events.

### Phase 2 — SOS vertical slice

- Implement SOS, transactional alert/outbox, retries, caregiver acknowledgement,
  action, and resolution.
- Test foreground, background, terminated, duplicate, and offline cases.

### Phase 3 — medication and reminders

- Implement recurring schedules, dose events, routine reminders, overdue jobs,
  corrections, and timezone handling.

### Phase 4 — dashboards and profiles

- Implement patient and caregiver interfaces, profiles, settings, permissions,
  freshness, and device-health states.

### Phase 5 — location pilot

- Implement PostGIS safe zones, mobile location, transition filtering, and retention.
- Complete background-location disclosure and app-store requirements.
- Test representative devices, OS versions, and battery settings.

### Phase 6 — reporting

- Add weekly summaries for doses, transitions, alerts, caregiver response, and
  device availability.

### Phase 7 — production readiness

- Complete monitoring, runbooks, load testing, penetration testing, accessibility
  review, backup restoration, rollback testing, and store/privacy materials.

### Phase 8 — controlled release

- Internal alpha with synthetic data.
- Supervised and explicitly consented pilot.
- Limited production after a documented go/no-go review.
- Wider release only after pilot targets are met.

### Phase 9 — later features

- Add multi-patient care, voice assistance, wearables, doctor workflows, fall
  detection, emergency integration, or AI only after the requirements in Section 4.

## 15. Testing and release gates

- Unit tests for schedules, timezones, alerts, deduplication, and safe zones.
- Authorization tests for every role and database operation.
- End-to-end tests from patient action to caregiver acknowledgement.
- Offline, duplicate, delayed, replayed, and permission-revoked tests.
- Notification tests in foreground, background, terminated, and offline states.
- Accessibility and representative-device tests.
- Load, security, backup-restore, and rollback tests.

Production requires:

- no known cross-patient authorization failure;
- no unresolved critical/high security or safety defect;
- successful alert retry and duplicate-prevention tests;
- verified RLS, backups, restoration, and rollback;
- completed privacy and store approvals;
- named support and incident-response owners; and
- a documented go/no-go decision after the supervised pilot.

Exact latency, availability, and delivery targets must be established from pilot
measurements rather than invented before the system exists.

## 16. Operations and analytics

Monitor API errors and latency, crashes, alert queue delays, notification attempts,
scheduled jobs, device/location freshness, authorization failures, and retention
jobs. Create runbooks for authentication, notifications, delayed jobs, suspected
breaches, unauthorized tracking, bad releases, and restoration.

Launch analytics include scheduled versus reported doses, safe-zone transitions,
alert lifecycle, caregiver response time, and device/data availability. Use
aggregates instead of retaining unnecessary raw location.

AI work begins only after defining its target, data, ground truth, error costs,
bias checks, validation, human review, monitoring, and rollback. Experimental AI
must never suppress SOS, overdue-dose, or safe-zone alerts.

## 17. Required outputs and definition of done

- Signed Android application.
- Staging and production backend with versioned migrations.
- Tested RLS, server functions, notifications, and audit records.
- Automated test suite and release evidence.
- Privacy notice, consent text, retention rules, and incident procedures.
- Architecture, module, workflow, ER, and threat-model diagrams.
- Monitoring, support runbooks, restore evidence, and rollback procedure.
- Store listing and background-location declaration.
- Project report and presentation based on demonstrated results.

The product is done only when Phases 0–7 and all production release gates pass.
