// Same five top-level destinations the Flutter app's navbar/bottom-nav use
// (lib/menu_item.dart's MenuItem, guest ordering). `key` is the i18n key for
// the label (see lib/i18n).
export const NAV_ITEMS = [
  { href: "/", key: "home", match: (p: string) => p === "/" },
  { href: "/songbook", key: "songbook", match: (p: string) => p.startsWith("/songbook") },
  { href: "/tuner", key: "tunerLabel", match: (p: string) => p.startsWith("/tuner") },
  { href: "/chords", key: "chordsLabel", match: (p: string) => p.startsWith("/chords") },
  { href: "/community", key: "communityLabel", match: (p: string) => p.startsWith("/community") },
] as const;

// Signed-in account menu. Entries are added as their pages are built, so the
// menu never links to a page that doesn't exist yet.
export const ACCOUNT_LINKS = [
  { href: "/profile", key: "profileLabel" },
  { href: "/my-songs", key: "mySongsTitle" },
  { href: "/setlists", key: "setlistsTitle" },
  { href: "/favorites", key: "favoritesTitle" },
  { href: "/request-song", key: "requestSongLabel" },
  { href: "/support", key: "supportLabel" },
] as const;

export const FOOTER_LINKS = [
  { href: "/about", key: "about" },
  { href: "/guide", key: "guideLabel" },
  { href: "/shop", key: "shopLabel" },
  { href: "/support", key: "supportLabel" },
  { href: "/contact", key: "contact" },
  { href: "/privacy", key: "privacyLabel" },
  { href: "/terms", key: "termsLabel" },
] as const;
