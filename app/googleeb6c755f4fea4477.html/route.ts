// Google Search Console ownership file. Served by a route (not a file in public/)
// on purpose: Firebase Hosting's cleanUrls answers a static "*.html" with a 301 to
// the extensionless URL, and Google's verifier needs this exact URL to return 200.
// force-dynamic keeps it a function response instead of a prerendered .html file.
export const dynamic = "force-dynamic";

export function GET() {
  return new Response("google-site-verification: googleeb6c755f4fea4477.html", {
    headers: { "Content-Type": "text/html; charset=UTF-8", "Cache-Control": "public, max-age=0, s-maxage=3600" },
  });
}
