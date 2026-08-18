# PaceMatch web build (release)
# Reads SUPABASE_* and routing keys from pacematch/.env

param(
  [string]$OutputDir = "build/web"
)

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

if (-not (Test-Path ".env")) {
  Write-Host "Warning: .env missing - build uses --dart-define only." -ForegroundColor Yellow
}

$defines = @()
if (Test-Path ".env") {
  Get-Content ".env" | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq "" -or $line.StartsWith("#")) { return }
    $parts = $line -split "=", 2
    if ($parts.Count -lt 2) { return }
    $key = $parts[0].Trim()
    $value = $parts[1].Trim()
    if ($value -eq "") { return }
    if ($key -match "^(SUPABASE_URL|SUPABASE_ANON_KEY|GH_API_KEY|ORS_API_KEY)$") {
      $defines += "--dart-define=${key}=$value"
    }
  }
}

Write-Host "Building Flutter web release..." -ForegroundColor Cyan
flutter build web --release @defines

Write-Host ""
Write-Host "Done: $OutputDir" -ForegroundColor Green
Write-Host "Deploy with: firebase deploy --only hosting" -ForegroundColor Cyan
Write-Host "Or upload the build/web folder to Netlify, Vercel, or Cloudflare Pages." -ForegroundColor Cyan
