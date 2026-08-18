# PaceMatch setup notes

Supabase powers **real sign-up / sign-in** for the web app. Ride and group data is still local demo content until the full backend is wired.

## 1. Create a Supabase project

1. [supabase.com](https://supabase.com) → New project (free tier is fine)
2. **SQL Editor** → run in order:
   - `migrations/20260729000000_init.sql`
   - `migrations/20260729000001_auth_profile_trigger.sql`
3. **Authentication → Providers → Email** → for quick testing, turn **off** “Confirm email” (re-enable for production)
   - This only affects **new** sign-ups. Users who registered earlier stay unconfirmed until you confirm or delete them under **Authentication → Users**.
4. **Authentication → URL configuration** → add your site URL(s), e.g.:
   - `http://localhost:7357` (local web)
   - `https://your-app.web.app` (after Firebase deploy)
5. **Project Settings → API** → copy **Project URL** and **anon public** key

## 2. Local `.env`

Copy `pacematch/.env.example` → `pacematch/.env` and fill in:

```
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_ANON_KEY=eyJ...
GH_API_KEY=...   # optional, for route planner
ORS_API_KEY=...  # optional fallback
```

## 3. Run locally in Chrome

```powershell
cd pacematch
flutter pub get
flutter run -d chrome --web-port 7357
```

Friends can register with email + password. Each account gets its own Supabase user; demo rides/groups are shared for now.

## 4. Build & share online

```powershell
cd pacematch
.\scripts\build-web.ps1
```

Then deploy `build/web`:

| Host | Steps |
|------|--------|
| **Firebase Hosting** | `npm i -g firebase-tools` → `firebase login` → `firebase deploy --only hosting` |
| **Netlify** | Drag `build/web` onto [app.netlify.com/drop](https://app.netlify.com/drop) |
| **Vercel** | Import repo, set build command to `.\scripts\build-web.ps1`, output `build/web` |

After deploy, add the public URL to Supabase **Authentication → URL configuration**.

## Fallback without Supabase

If `SUPABASE_URL` / `SUPABASE_ANON_KEY` are empty, the app falls back to mock login (any email works).
