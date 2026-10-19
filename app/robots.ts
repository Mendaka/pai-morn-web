import type { MetadataRoute } from "next";
import { SITE_URL } from "@/lib/site";

// Everything public is crawlable (as on the Flutter site). Account and admin
// pages also carry a noindex meta tag; disallowing them here just saves the
// crawler a trip.
export default function robots(): MetadataRoute.Robots {
  return {
    rules: [{ userAgent: "*", allow: "/", disallow: ["/admin", "/login", "/profile", "/my-songs", "/favorites", "/setlists", "/submit-song"] }],
    sitemap: `${SITE_URL}/sitemap.xml`,
  };
}
