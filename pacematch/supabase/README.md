# PaceMatch setup notes

This folder is prepared for a future Supabase backend.

## Next steps (not required for the current Flutter Web demo)

1. Create a free project at https://supabase.com
2. Install the CLI: https://supabase.com/docs/guides/cli
3. Copy `.env.example` values into a local `.env` / `--dart-define`
4. Run the SQL in `migrations/20260729000000_init.sql` in the Supabase SQL editor
5. Wire `supabase_flutter` in the Flutter app (Auth, profiles, rides, RSVPs)

Current app uses **mock auth + in-memory RSVP state** so you can click through every screen without a backend.
