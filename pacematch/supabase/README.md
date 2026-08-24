# PaceMatch setup notes

Supabase powers **real sign-up / sign-in** and **shared groups & rides** so friends see the same data.

## 1. Create a Supabase project

1. [supabase.com](https://supabase.com) → New project (free tier is fine)
2. **SQL Editor** → run **in order**:
   - `migrations/20260729000000_init.sql`
   - `migrations/20260729000001_auth_profile_trigger.sql`
   - `migrations/20260824000000_shared_groups_rides.sql` ← required for shared groups/rides
   - `migrations/20260824000001_fix_groups_rls.sql` ← fix create-group RLS (if create fails)
3. **Authentication → Providers → Email** → for quick testing, turn **off** “Confirm email”
4. **Authentication → URL configuration** → add your site URL(s), e.g.:
   - `http://localhost:7357` (local web)
   - your deployed URL
5. **Project Settings → API** → copy **Project URL** and **anon public** key

## 2. Local `.env`

Copy `pacematch/.env.example` → `pacematch/.env` and fill in:

```
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_ANON_KEY=eyJ...
GH_API_KEY=...
ORS_API_KEY=...
```

## 3. Run locally in Chrome

```powershell
cd pacematch
flutter pub get
flutter run -d chrome --web-port 7357
```

Friends register with email + password (same Supabase project).  
After login, groups/rides load from the database. Use **Refresh** on the Groups tab (or pull-to-refresh) to pick up new items.

**Tips for testing with friends**
- Create groups as **Public** (private ones are only visible to members)
- Everyone must be signed in with a real Supabase account (not “Continue as demo rider”)
- If create/load fails, run `20260824000001_fix_groups_rls.sql` (or re-run `20260824000000_shared_groups_rides.sql`) in the SQL Editor
- You must be signed in with a real account (not “Continue as demo rider”)

## 4. Build & share online

```powershell
cd pacematch
.\scripts\build-web.ps1
```

Then deploy `build/web` (Firebase Hosting / Netlify / Vercel) and add the public URL to Supabase Auth URL config.

## Fallback without Supabase

If `SUPABASE_URL` / `SUPABASE_ANON_KEY` are empty, the app falls back to mock login and **local-only** demo data (not shared between devices).
