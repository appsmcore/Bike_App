# PaceMatch

Flutter app to discover and join group cycling rides that match your pace.

**Web-first testing:** run in Chrome or deploy the web build so friends can sign up with real accounts (Supabase Auth).

## Quick start (web)

```powershell
cd C:\Users\maxpi\Bike_App\pacematch
copy .env.example .env
# Fill SUPABASE_URL + SUPABASE_ANON_KEY (see supabase/README.md)
flutter pub get
flutter run -d chrome --web-port 7357
```

## Real login (Supabase)

1. Create a free project at [supabase.com](https://supabase.com)
2. Run the SQL migrations in `supabase/migrations/`
3. Add keys to `.env` (see `.env.example`)
4. Optional: disable email confirmation while testing

Full setup: **[supabase/README.md](supabase/README.md)**

## Deploy for friends

```powershell
.\scripts\build-web.ps1
firebase deploy --only hosting   # or Netlify drop / Vercel
```

Add your live URL in Supabase → Authentication → URL configuration.

## Routing (same as the Vite playground)

Uses **GraphHopper** first (bike profile; custom rules on paid plans), then **ORS**.

### Keys (one shared file)

Copy and fill `pacematch/.env` (see `.env.example`):

```
GH_API_KEY=...
ORS_API_KEY=...
VITE_GH_API_KEY=...   # same values — used by the Node playground
VITE_ORS_API_KEY=...
SUPABASE_URL=...
SUPABASE_ANON_KEY=...
```

### Optional: fast Node playground

```powershell
cd C:\Users\maxpi\Bike_App\pacematch\route-playground
npm install
npm run dev
```

Uses the **same** `pacematch/.env` (Vite `envDir` = parent folder).

### Note on GraphHopper free tier

Custom cycleway models need a **paid** GraphHopper plan. On free, the app uses the standard `bike` profile (often already better than ORS for cycleways).
