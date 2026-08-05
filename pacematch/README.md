# PaceMatch

Flutter app to discover and join group cycling rides that match your pace.

## Routing (same as the Vite playground)

Uses **GraphHopper** first (bike profile; custom rules on paid plans), then **ORS**.

### 1. Keys (one shared file)

Copy and fill `pacematch/.env` (see `.env.example`):

```
GH_API_KEY=...
ORS_API_KEY=...
VITE_GH_API_KEY=...   # same values — used by the Node playground
VITE_ORS_API_KEY=...
```

### 2. Start Flutter app

```powershell
cd C:\Users\maxpi\Bike_App\pacematch
flutter run -d chrome
```

No `--dart-define` needed when `.env` is present. Plan a route → **Confirm route & back to offer**.

### 3. Optional: fast Node playground

```powershell
cd C:\Users\maxpi\Bike_App\pacematch\route-playground
npm install
npm run dev
```

Uses the **same** `pacematch/.env` (Vite `envDir` = parent folder).

### Note on GraphHopper free tier

Custom cycleway models need a **paid** GraphHopper plan. On free, the app uses the standard `bike` profile (often already better than ORS for cycleways).
