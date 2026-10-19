import type { Metadata, Viewport } from "next";
import { IBM_Plex_Sans_Thai, Noto_Sans_Myanmar, Plus_Jakarta_Sans, Roboto } from "next/font/google";
import localFont from "next/font/local";
import "./globals.css";
import { AuthProvider } from "@/components/AuthProvider";
import { LanguageProvider } from "@/components/LanguageProvider";
import SiteViewRecorder from "@/components/SiteViewRecorder";
import AnalyticsTracker from "@/components/AnalyticsTracker";
import "@/lib/pwa-install";
import Footer from "@/components/Footer";
import MobileBottomNav from "@/components/MobileBottomNav";
import Navbar from "@/components/Navbar";
import { SITE_URL } from "@/lib/site";

// Roboto is the Flutter app's own default font on every platform — using it
// here keeps text metrics (and the chord/lyric alignment that depends on
// them) consistent with what users already see in the app. Scoped (in
// globals.css) to JUST the lyric/chord rendering now that --font-sans below
// uses Plus Jakarta Sans for everything else — a plain Roboto body read as
// generic ("ยังไม่ค่อยสวยเท่าไหร่" the owner said, after I pointed out it's
// literally Android's own system default), but swapping it wholesale risked
// the chord-position math LyricLine.tsx does against Roboto's own character
// widths. Keeping Roboto only where that math actually runs sidesteps that.
const roboto = Roboto({
  variable: "--font-roboto",
  subsets: ["latin"],
});

// English (and the Latin portion of every other language's UI) body/heading
// font, 2026-10-01 — picked for a cleaner, more "designed" feel than Roboto's
// ubiquitous system-default look without being as unusual as a full display
// typeface; pairs reasonably with IBM Plex Sans Thai's own humanist-geometric
// shapes below. Never used for lyric/chord text — see globals.css's
// `.lyric-line`/`.lyric-inline` rules, which pin those back to Roboto.
const jakarta = Plus_Jakarta_Sans({
  variable: "--font-jakarta",
  subsets: ["latin"],
});

// Shan and Burmese share the Myanmar Unicode block. Flutter Web pulled
// this in on demand via CanvasKit's Noto fallback; plain HTML would fall
// back to whatever the visitor's OS happens to have (many Windows/older
// Android installs render Shan glyphs badly or as boxes), so ship it.
const myanmar = Noto_Sans_Myanmar({
  variable: "--font-myanmar",
  subsets: ["myanmar"],
});

// Shan (Unicode) fonts from assets/fonts, used only while the interface language is Shan
// (see :lang(shn) and .brand-shn in globals.css). preload:false so nobody else downloads them;
// the text font is limited to the Myanmar blocks so Latin (chords, digits) stays Roboto.
const shanBrand = localFont({
  src: "../assets/fonts/A J Kunheing 19.ttf",
  variable: "--font-shan-brand",
  display: "swap",
  preload: false,
});
const shanText = localFont({
  src: "../assets/fonts/A J Kunheing E-T-M 05.ttf",
  variable: "--font-shan-text",
  display: "swap",
  preload: false,
  declarations: [{ prop: "unicode-range", value: "U+1000-109F, U+A9E0-A9FF, U+AA60-AA7F, U+200C-200D, U+25CC" }],
});

// Thai interface only (see :lang(th) in globals.css). Roboto has NO Thai glyphs at all
// (confirmed with opentype.js), so plain Thai text was silently falling back to whatever
// Thai font each visitor's OS happens to ship — Tahoma, Leelawadee UI, Noto Sans Thai UI,
// Apple's Thonburi, all different — which is why it read as inconsistent/"ไม่สวย" rather
// than one deliberate choice. Requesting only the "thai" subset keeps this font out of the
// way of Latin text (chords, digits): Google's Thai subset carries no Latin codepoints, so
// those still render in Roboto automatically, same principle as the Shan/Myanmar fonts above.
const thai = IBM_Plex_Sans_Thai({
  variable: "--font-thai",
  subsets: ["thai"],
  weight: ["400", "600", "700"],
});

// Burmese interface only (see :lang(my) in globals.css) — the owner's own choice of font
// for Burmese, replacing the Noto Sans Myanmar fallback every other language still uses for
// stray Myanmar-script text. Restricted to the Myanmar block via unicode-range: Padauk also
// contains ordinary Latin letters and digits, which would otherwise draw chords with its own
// (different) metrics — the exact clipping bug the Shan font hit earlier (see the note above).
const padauk = localFont({
  src: [
    { path: "../assets/fonts/Padauk/Padauk-Regular.ttf", weight: "400" },
    { path: "../assets/fonts/Padauk/Padauk-Bold.ttf", weight: "700" },
  ],
  variable: "--font-padauk",
  display: "swap",
  preload: false,
  declarations: [{ prop: "unicode-range", value: "U+1000-109F, U+200C-200D, U+25CC" }],
});

const lobster = localFont({
  src: "./fonts/LobsterTwo-Bold.ttf",
  variable: "--font-lobster",
  weight: "700",
});

export const viewport: Viewport = { themeColor: "#000000" };

export const metadata: Metadata = {
  // Chrome's "Translate this page?" bar kept popping up (the HTML says lang=en while
  // the content is Shan/Thai/Burmese) and machine-translating chords and lyrics, which
  // also mutates the DOM under React. The site has its own 4-language interface, so
  // ask browsers not to offer translation (this meta + translate="no" on <html>).
  other: { google: "notranslate" },
  // Absolute base so relative canonical/OG URLs resolve to the real site.
  metadataBase: new URL(SITE_URL),
  // The Shan name is in the default title and keywords on purpose: search engines read
  // the server-rendered HTML (which is English), so this is what lets a search for
  // ပၢႆးမွၼ်း find the site as well as "Paimorn". See also the WebSite JSON-LD on Home.
  title: { default: "Paimorn (ပၢႆးမွၼ်း)", template: "%s · Paimorn" },
  keywords: ["Paimorn", "ပၢႆးမွၼ်း", "Shan songbook", "guitar chords", "lyrics"],
  description: "Community songbook for guitar chords and lyrics.",
  applicationName: "Paimorn",
  appleWebApp: { capable: true, title: "Paimorn", statusBarStyle: "black" },
  // Link-preview card for any page that doesn't set its own (generated by the
  // existing siteCard Cloud Function, same image the Flutter site used).
  openGraph: { siteName: "Paimorn", type: "website", images: [{ url: "/site-card.png", width: 1200, height: 630, alt: "Paimorn" }] },
  twitter: { card: "summary_large_image", images: ["/site-card.png"] },
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="en"
      translate="no"
      suppressHydrationWarning
      className={`${roboto.variable} ${jakarta.variable} ${myanmar.variable} ${lobster.variable} ${shanBrand.variable} ${shanText.variable} ${thai.variable} ${padauk.variable} h-full antialiased`}
    >
      <head>
        {/* Service workers never control the page that registers them, only
            later navigations — so a brand-new PWA/TWA install's very first
            page load has no fallback at all if a stylesheet request drops
            mid-flight (the raw, unstyled-HTML bug public/sw.js's retry logic
            already fixes for every OTHER load). This is a second, SW-
            independent safety net for exactly that first load.
            Two independent signals, reload if EITHER says the CSS didn't
            really apply: (a) every <link rel="stylesheet">'s own `.sheet`
            is non-null, and (b) body's actual computed font-family is one
            of ours, not the browser's generic fallback stack. Neither
            alone proved fully reliable under every failure mode tested
            (Next's build can split one page's CSS across more than one
            chunk/request, and `.sheet` itself was observed non-null in at
            least one genuine-failure test run) — belt and suspenders.
            Runs on `load` AND on a 6s fallback timer, not `load` alone —
            also observed that a severed connection on one resource can
            keep `load` from firing at all. Reloads once (session-guarded
            so a genuinely offline first visit doesn't loop) to let the
            browser's normal retry succeed.
            Skips known crawler/preview-bot user agents entirely (added
            2026-10-14) — this exists purely for a human's UX, and a
            JS-triggered reload mid-crawl risks a search/social bot
            capturing a half-loaded page instead of the real one, which is
            a strictly worse outcome than the rare unstyled-paint bug this
            whole script exists to avoid. */}
        <script
          dangerouslySetInnerHTML={{
            __html:
              'try{if(!/bot|crawl|spider|slurp|facebookexternalhit|whatsapp|telegrambot|mediapartners|lighthouse|pagespeed|ia_archiver/i.test(navigator.userAgent)&&sessionStorage.getItem("pm.cssReloaded")!=="1"){var c=false;var k=function(){if(c)return;c=true;try{var l=document.querySelectorAll(\'link[rel="stylesheet"]\');var ok=l.length>0;for(var i=0;i<l.length;i++){if(!l[i].sheet){ok=false;break}}var f=getComputedStyle(document.body).fontFamily||"";if(f.indexOf("Jakarta")===-1)ok=false;if(!ok){sessionStorage.setItem("pm.cssReloaded","1");location.reload()}}catch(e){}};window.addEventListener("load",k);setTimeout(k,6000)}}catch(e){}',
          }}
        />
        {/* Apply the saved theme before first paint (see components/ThemeToggle.tsx). */}
        <script dangerouslySetInnerHTML={{ __html: 'try{if(localStorage.getItem("pm.theme")==="dark")document.documentElement.classList.add("dark")}catch(e){}' }} />
        {/* components/Reveal.tsx needs JS (IntersectionObserver) to ever add .reveal-in —
            without it, real content would be stuck at the CSS default of opacity: 0. */}
        <noscript>
          <style>{".reveal, .reveal-stagger > * { opacity: 1 !important; }"}</style>
        </noscript>
      </head>
      <body className="flex min-h-full flex-col">
        <LanguageProvider>
        <SiteViewRecorder />
        <AnalyticsTracker />
        <AuthProvider>
          <Navbar />
          <main className="flex-1 pb-20 md:pb-0">{children}</main>
          <Footer />
          <MobileBottomNav />
        </AuthProvider>
        </LanguageProvider>
      </body>
    </html>
  );
}
