# Deploying the Next.js site

`firebase.json` targets the live Hosting site (`song-and-chord`) — since the
2026-09-23 cutover, `song-and-chord.web.app` serves this app (it used to be the
old Flutter build; the `paimorn-next` test site that came before the cutover
has been deleted, along with its `ssrpaimornnext` function).

Deploy (PowerShell, from this folder) — `deploy.ps1` does the build-time env for you:

    ./deploy/deploy.ps1

Or by hand, from the repo root:

    firebase deploy --only hosting --project song-and-chord

What the rewrites in firebase.json keep alive (Cloud Functions that stay, deployed
from the Flutter repo `functions/index.js`):
songCard / siteCard / dailyUpdateCard / dailyUpdatePreview (link-preview images),
recordSongView / recordSiteView (view counters), uploadArtistPhoto (admin),
youtubeEmbed (the Android app's video player loads it from this same host).

Retired (Next renders these natively, so the Cloud Function versions are no
longer called from here): songPreview, songPrintPage, sitemap. They can be
removed from functions/index.js once confirmed nothing else still calls them.
