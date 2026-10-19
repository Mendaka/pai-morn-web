// Digital Asset Links: proves this domain and the Play Store Android app
// (com.paimorn.songbook) are owned by the same party, so the TWA wrapper opens
// with no browser chrome instead of falling back to a Custom Tab. Served as a
// route handler (not a public/.well-known static file) because firebase.json's
// hosting `ignore` list drops every dotfile/dot-directory ("**/.*"), which
// would silently exclude a static file at this exact path from every deploy.
//
// Two fingerprints are listed: the upload key (what the app was signed with
// locally, before upload) and the app signing key (what Google Play Console's
// "Play App Signing" actually re-signs with for real installs — found at
// Protected with Play > Play Store protection > App signing). An app
// installed from Play Store carries the app signing key's certificate, not
// the upload key's, so without this second entry the TWA falls back to a
// browser-chrome Custom Tab instead of opening full-screen.
export const dynamic = "force-static";

export async function GET() {
  return Response.json([
    {
      relation: ["delegate_permission/common.handle_all_urls"],
      target: {
        namespace: "android_app",
        package_name: "com.paimorn.songbook",
        sha256_cert_fingerprints: [
          "BF:73:80:45:CD:0F:C4:43:D8:89:9D:41:53:76:75:53:70:54:0B:C8:4C:91:E6:B3:31:BF:64:65:04:36:82:DF",
          "20:32:B6:36:C2:5B:B2:87:96:DB:FB:35:06:DB:DB:4D:EB:4C:BC:5C:C7:37:67:66:43:DF:B8:D7:E2:2B:58:F4",
        ],
      },
    },
  ]);
}
