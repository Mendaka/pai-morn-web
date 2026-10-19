# Builds and deploys the Next.js site to Firebase Hosting (site: song-and-chord,
# the live domain since the 2026-09-23 cutover from the old Flutter build).
# View counting is switched ON only here, so local runs never inflate real counts.
# (No $ErrorActionPreference = "Stop": PowerShell 5.1 would treat the Firebase CLI's
#  harmless stderr info lines as fatal errors. The exit code is checked instead.)
Set-Location (Split-Path $PSScriptRoot -Parent)
$env:NEXT_PUBLIC_RECORD_VIEWS = "1"
$env:NEXT_PUBLIC_API_BASE = ""           # same origin: /api/* is rewritten to the functions
$env:NEXT_PUBLIC_USE_EMULATORS = ""
firebase deploy --only hosting --project song-and-chord
if ($LASTEXITCODE -ne 0) { Write-Error "Deploy failed (exit $LASTEXITCODE)"; exit $LASTEXITCODE }
