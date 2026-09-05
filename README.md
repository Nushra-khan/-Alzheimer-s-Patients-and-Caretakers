# Memora

_Remember. Connect. Care._

Caregiver-support mobile application for reminders, patient-authorized location
sharing, SOS events, and caregiver alert acknowledgement.

This application is not an emergency service, diagnostic tool, or replacement
for professional medical care. See [PLAN.md](./PLAN.md) for the feature scope,
architecture, delivery phases, and production release gates.

## Current status

The Flutter interface and backend contract are under active development. Mock data
is available only through debug previews. Release builds do not allow users to
select their own patient or caregiver role.

Supabase migrations are in `supabase/migrations`. Create separate development,
staging, and production projects before connecting the application. Provide only
the public client configuration at build time:

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Never pass a Supabase service-role key to a Flutter build.
