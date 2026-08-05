# PaceMatch

Find group cycling rides that match your pace.

This repo contains a **Flutter Web** demo with mock auth, sample South Tyrol rides, and local Join / Maybe / Decline state. Supabase schema is prepared under `pacematch/supabase/` for a later backend.

## Requirements

- Flutter SDK (this machine uses `D:\dev\flutter`)
- Google Chrome
- Enough free disk space (prefer installing Flutter / pub-cache on `D:`)

## Setup PATH (PowerShell)

```powershell
$env:Path = "D:\dev\flutter\bin;" + $env:Path
$env:PUB_CACHE = "D:\dev\pub-cache"
$env:CHROME_EXECUTABLE = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
```

Optional: add `D:\dev\flutter\bin` permanently to your user PATH.

## Install & run (Chrome)

```powershell
cd C:\Users\maxpi\Bike_App\pacematch
flutter pub get
flutter run -d chrome
```

## What you can try

1. **Login** — any email/password, or “Continue as demo rider”
2. **Onboarding** — bikes, fitness, distance & days
3. **Home** — Ride Finder cards (Road / MTB / Gravel…)
4. **Join / Maybe / Decline** — stored in local app state (snackbar feedback)
5. **Ride detail** — stats, map placeholder, elevation chart
6. **Calendar** — week strip + bike/difficulty filters
7. **Groups** — list + detail (join/leave, upcoming rides, chat placeholder)
8. **Profile** — stats, badges, theme toggle, sign out

## Project layout

```
pacematch/
  lib/
    core/           # theme, router
    data/           # models, fake data, AppState
    features/       # auth, onboarding, home, rides, calendar, groups, profile
    shared/widgets/
  supabase/         # SQL schema for later
  web/
```

## Notes

- UI language: English
- Light & dark mode (sun icon on Home / Profile)
- No live tracking, Strava, or real push notifications in this phase
