<p align="center">
  <img src="assets/branding/memora_app_icon.png" alt="Memora duck logo" width="190" />
</p>

<h1 align="center">💜 Memora</h1>

<p align="center">
  <strong>Remember. Connect. Care.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-Mobile_App-7B4BC4?style=for-the-badge&amp;logo=flutter&amp;logoColor=white" alt="Flutter mobile app" />
  <img src="https://img.shields.io/badge/Supabase-Backend-9A72D8?style=for-the-badge&amp;logo=supabase&amp;logoColor=white" alt="Supabase backend" />
  <img src="https://img.shields.io/badge/Status-Active_Development-B69AF3?style=for-the-badge" alt="Active development" />
</p>

<p align="center">
  <strong>A calmer way to remember routines, stay connected, and coordinate care.</strong>
</p>

---

Memora is a Flutter mobile application that helps people living with memory
loss stay connected with a trusted caregiver. It combines daily medication and
routine support with consent-based location sharing, SOS alerts, and caregiver
follow-up.

> [!IMPORTANT]
> Memora is a support tool. It is not an emergency service, medical device,
> diagnostic product, or replacement for professional care. Do not rely on it
> as the only way to contact emergency services.

## 💜 What is implemented

### Patient experience

- Email/password sign-up and login
- Google sign-in through Supabase Auth
- Daily medication schedule with dose reporting
- Daily routines with completion tracking
- SOS alert creation
- Optional location sharing
- Caregiver invitation creation
- Account settings and sign-out

### Caregiver experience

- Secure connection to a patient using an invitation code
- Patient status dashboard
- Medication and routine overview
- Medication schedule creation
- Alert acknowledgement and resolution
- Shared-location and safe-zone view
- Safe-zone radius updates
- Caregiver profile and emergency-contact view

### Platform and data

- Supabase Authentication and PostgreSQL persistence
- Row Level Security policies for patient/caregiver access
- Realtime refreshes for patient, medication, routine, location, and alert data
- Database-backed invitation, SOS, dose, routine, and safe-zone actions
- Separate debug fallback data when Supabase configuration is omitted
- Android and iOS app icons and OAuth callback handling

## ✨ Technology

| Area | Technology |
| --- | --- |
| Client | Flutter and Dart |
| State management | Riverpod |
| Navigation | GoRouter |
| Backend | Supabase Auth, PostgreSQL, PostGIS, and Realtime |
| Security | Supabase Row Level Security and database functions |
| Tests | Flutter test |

## 🗂️ Project structure

```text
lib/
  app/                    Theme and routing
  core/
    config/               Build-time configuration
    models/               Domain models
    providers/            Session and care state
    repositories/         Repository contract and Supabase implementation
  features/
    auth/                 Login and sign-up
    patient/              Today, SOS, and settings
    caregiver/            Dashboard, location, alerts, schedules, and profile
supabase/
  migrations/             Schema, RLS policies, functions, and persisted actions
assets/branding/          Memora icon assets
test/                     Provider and widget tests
```

## 🛠️ Prerequisites

- Flutter SDK compatible with Dart `^3.12.2`
- Android Studio or Xcode for mobile builds
- A Supabase project
- Node.js/npm for running the Supabase CLI with `npx`
- Windows Developer Mode when building Flutter plugins on Windows

Verify the local toolchain:

```console
flutter doctor
flutter pub get
```

## 🟣 Supabase setup

Use a separate Supabase project for each environment. Never place the service
role key in the Flutter app or commit it to source control.

1. Sign in and link this repository to the intended Supabase project:

   ```console
   npx supabase@latest login
   npx supabase@latest link --project-ref YOUR_PROJECT_REF
   ```

2. Check the pending migrations, then apply them:

   ```console
   npx supabase@latest db push --dry-run
   npx supabase@latest db push
   npx supabase@latest migration list
   ```

   The remote column in `migration list` should contain every local migration
   from `0001` through `0006`.

3. Check the resulting database schema:

   ```console
   npx supabase@latest db lint --linked
   ```

4. In the Supabase dashboard, copy the project URL and the public publishable
   key from the project's API settings. Do not use the secret or service-role
   key.

## ⚙️ App configuration

Create `config/staging.json`. The `config/*.json` pattern is ignored by Git so
environment values are not accidentally committed.

```json
{
  "SUPABASE_URL": "https://YOUR_PROJECT_REF.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "YOUR_PUBLIC_PUBLISHABLE_KEY",
  "CARE_TIMEZONE": "Asia/Kolkata"
}
```

Run Memora on a connected device:

```console
flutter devices
flutter run -d DEVICE_ID --dart-define-from-file=config/staging.json
```

If the configuration is omitted, debug builds use local demonstration data.
Release builds intentionally fail at startup when the Supabase URL or
publishable key is missing.

## 🔐 Google sign-in

The app uses this deep-link callback:

```text
io.supabase.memora://login-callback
```

To enable Google authentication:

1. Create OAuth credentials in Google Cloud for the Supabase callback URL shown
   in the Supabase Google provider settings.
2. Enable Google under **Supabase Dashboard > Authentication > Providers** and
   enter the Google client ID and secret.
3. Add `io.supabase.memora://login-callback` to the allowed redirect URLs under
   **Authentication > URL Configuration**.
4. Restart the app and test login on a physical device.

The Android intent filter and iOS URL scheme are already configured in the
repository.

## ✅ Quality checks

Run these checks before opening a pull request or creating a release:

```console
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Build an Android APK with staging configuration:

```console
flutter build apk --release --dart-define-from-file=config/staging.json
```

For Google Play, create an app bundle instead:

```console
flutter build appbundle --release --dart-define-from-file=config/production.json
```

## 🗄️ Database migrations

| Migration | Purpose |
| --- | --- |
| `0001_core_schema.sql` | Core care, medication, location, alert, notification, audit, and RLS schema |
| `0002_trusted_actions.sql` | Trusted database actions for dose, SOS, and caregiver alert workflows |
| `0003_auth_profiles.sql` | Creates patient or caregiver records after Supabase sign-up |
| `0004_linked_profile_access.sql` | Allows linked users to read the profiles and device data they need |
| `0005_care_invitations.sql` | Secure patient invitation creation and caregiver acceptance |
| `0006_persist_care_actions.sql` | Persists medication creation, routine completion, location sharing, and safe-zone updates |

Never edit a migration that has already been applied to a shared environment.
Create a new numbered migration for every schema or policy change.

## 🚀 Production checklist

Before distributing Memora to real users:

- Apply and verify all migrations in a dedicated production Supabase project.
- Confirm RLS policies using separate patient and caregiver test accounts.
- Configure production Google OAuth credentials and redirect URLs.
- Add production Android signing and iOS distribution configuration.
- Replace the placeholder package/bundle identifiers where required.
- Add crash reporting, operational monitoring, and a support contact.
- Implement and verify push-notification delivery for background alerts.
- Complete privacy, consent, data-retention, account-deletion, and incident-response policies.
- Test accessibility, offline/error states, and the full SOS workflow on real devices.
- Perform a security review before handling real health or precise-location data.

For the broader scope, architecture decisions, and release gates, see
[PLAN.md](PLAN.md).

## 📄 License

No open-source license has been declared. Unless a license is added, the source
code remains under its existing copyright terms.
