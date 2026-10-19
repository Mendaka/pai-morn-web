import type { Metadata } from "next";
import Link from "next/link";
import { ArrowRight, BookOpen, Eye, HeartHandshake, Info, Mail, Music2, PenLine, Printer, ShieldCheck, SlidersHorizontal, Smartphone, Users, FileText } from "lucide-react";
import ArtistCard from "@/components/ArtistCard";
import InstallBanner from "@/components/InstallBanner";
import { T } from "@/components/LanguageProvider";
import LiveVisitors from "@/components/LiveVisitors";
import LyricLine from "@/components/LyricLine";
import Reveal from "@/components/Reveal";
import ShopProductCard from "@/components/ShopProductCard";
import SongShelf from "@/components/SongShelf";
import TeamSection from "@/components/TeamSection";
import TodaysNewSongs, { type NewSong } from "@/components/TodaysNewSongs";
import { displayArtistName, getCatalog } from "@/lib/catalog";
import { composersFrom } from "@/lib/composers";
import { getLiveVisitors } from "@/lib/ga-realtime";
import { getShopProducts } from "@/lib/shop";
import { SITE_URL } from "@/lib/site";
import { getSiteViews } from "@/lib/stats";
import { getTeam } from "@/lib/team";

// Rendered per request (the catalog read is memoised for 60s in lib/catalog.ts and the
// CDN caches the response briefly, see next.config.ts). ISR on Cloud Functions kept
// serving builds-old pages: new approvals never showed until the next deploy.
export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: { absolute: "Paimorn (ပၢႆးမွၼ်း) — guitar chords & lyrics songbook" },
  description: "Paimorn (ပၢႆးမွၼ်း) is a community songbook of guitar chords and lyrics. Browse by artist, transpose to your key, print or play along.",
  alternates: { canonical: "/" },
};

const FEATURES = [
  { icon: Music2, key: "feature1" },
  { icon: SlidersHorizontal, key: "feature2" },
  { icon: Printer, key: "feature3" },
  { icon: Smartphone, key: "feature4" },
];

// Same destinations as the desktop Footer — the footer itself is hidden on
// phones (the bottom tab bar takes its place there), so without this a
// phone had no way at all to reach these pages. A Home section instead of a
// hamburger menu, since that's what this page already does for every other
// destination (SongBook, artists, ...).
const MORE_LINKS = [
  { icon: Info, href: "/about", key: "about" },
  { icon: BookOpen, href: "/guide", key: "guideLabel" },
  { icon: HeartHandshake, href: "/support", key: "supportLabel" },
  { icon: Mail, href: "/contact", key: "contact" },
  { icon: ShieldCheck, href: "/privacy", key: "privacyLabel" },
  { icon: FileText, href: "/terms", key: "termsLabel" },
];

// `<` is escaped so nothing in the JSON can close the script tag early.
const SITE_JSON_LD = JSON.stringify({
  "@context": "https://schema.org",
  "@type": "WebSite",
  name: "Paimorn",
  alternateName: ["ပၢႆးမွၼ်း"],
  url: SITE_URL,
  inLanguage: ["en", "th", "shn", "my"],
}).replace(/</g, "\\u003c");

export default async function Home() {
  const [{ songs, artists }, visits, live, team, shopProducts] = await Promise.all([getCatalog(), getSiteViews(), getLiveVisitors(), getTeam(), getShopProducts()]);

  const newest = [...songs].sort((a, b) => b.approvedAt - a.approvedAt).slice(0, 10);
  // The card works out which of the newest songs are "today" in the browser.
  const recent: NewSong[] = [...songs]
    .sort((a, b) => b.approvedAt - a.approvedAt)
    .slice(0, 30)
    .map((s) => ({ id: s.id, name: s.songName, artist: displayArtistName(s), approvedAt: s.approvedAt }));
  const popular =[...songs].sort((a, b) => b.viewCount - a.viewCount).slice(0, 10);
  const totalViews = songs.reduce((sum, s) => sum + s.viewCount, 0);

  const stats = [
    { icon: Music2, value: songs.length, label: "statSongs" },
    { icon: Users, value: artists.length, label: "statArtists" },
    { icon: PenLine, value: composersFrom(songs).length, label: "statComposers" },
    { icon: Eye, value: visits ?? totalViews, label: visits ? "statVisits" : "statSongViews" },
  ];

  return (
    <div className="mx-auto w-full max-w-7xl px-4 pb-20 pt-4 sm:px-6">
      {/* Tells search engines the site's name in both languages ("Paimorn" / ပၢႆးမွၼ်း). */}
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: SITE_JSON_LD }} />
      <InstallBanner />
      <section className="relative overflow-hidden rounded-[2rem] bg-neutral-950 px-6 py-14 text-white sm:px-14 sm:py-24">
        <div className="hero-blob-a pointer-events-none absolute -left-24 -top-32 h-96 w-96 rounded-full bg-indigo-500/40 blur-3xl" />
        <div className="hero-blob-b pointer-events-none absolute -bottom-40 right-0 h-[26rem] w-[26rem] rounded-full bg-sky-500/35 blur-3xl" />
        <div className="hero-blob-c pointer-events-none absolute right-1/4 top-10 h-64 w-64 rounded-full bg-fuchsia-500/25 blur-3xl" />

        <div
          aria-hidden
          className="absolute right-10 top-1/2 hidden w-[26rem] -translate-y-1/2 rotate-[3deg] rounded-3xl border border-white/15 bg-white/10 p-7 shadow-2xl backdrop-blur-xl lg:block xl:right-20"
          style={{ ["--chord" as string]: "#7dd3fc", ["--lyric-size" as string]: "1.2rem" }}
        >
          <div className="mb-3 flex items-center gap-2 text-xs font-semibold uppercase tracking-widest text-white/50">
            <span className="rounded-full bg-white/15 px-2.5 py-1 text-white/80">Key C</span>
            Verse 1
          </div>
          <div className="text-white">
            <LyricLine
              transpose={0}
              content={[
                { type: "chord", text: "C" },
                { type: "lyric", text: "Under the open " },
                { type: "chord", text: "G" },
                { type: "lyric", text: "sky" },
              ]}
            />
            <LyricLine
              transpose={0}
              content={[
                { type: "chord", text: "Am" },
                { type: "lyric", text: "we sing along, " },
                { type: "chord", text: "F" },
                { type: "lyric", text: "hearts in " },
                { type: "chord", text: "C" },
                { type: "lyric", text: "key" },
              ]}
            />
            <LyricLine
              transpose={0}
              content={[
                { type: "chord", text: "F" },
                { type: "lyric", text: "every note a " },
                { type: "chord", text: "G" },
                { type: "lyric", text: "little " },
                { type: "chord", text: "C" },
                { type: "lyric", text: "closer" },
              ]}
            />
          </div>
        </div>

        <div className="relative max-w-3xl">
          <p className="mb-5 inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/10 px-4 py-1.5 text-xs font-semibold uppercase tracking-[0.18em] text-white/80 backdrop-blur">
            <Music2 size={14} /> <T k="homeEyebrow" />
          </p>
          <h1 className="text-4xl font-extrabold leading-[1.08] tracking-tight sm:text-6xl">
            <T k="homeHeroLine1" />
            <br />
            <span className="bg-gradient-to-r from-sky-300 via-indigo-300 to-fuchsia-300 bg-clip-text text-transparent">
              <T k="homeHeroLine2" />
            </span>
          </h1>
          <p className="mt-6 max-w-xl text-lg leading-relaxed text-white/75">
            <T k="homeHeroSubtitle" />
          </p>
          <div className="mt-9 flex flex-wrap gap-3">
            <Link
              href="/songbook"
              className="keep-light lift-spring inline-flex items-center gap-2 rounded-full bg-white px-7 py-3.5 text-[15px] font-bold text-neutral-900 shadow-xl transition hover:scale-[1.04] active:scale-[0.97]"
            >
              <T k="browseSongbook" /> <ArrowRight size={18} />
            </Link>
          </div>

          <dl className="mt-12 flex flex-wrap gap-x-10 gap-y-5">
            {stats.map(({ icon: Icon, value, label }) => (
              <div key={label} className="flex items-center gap-3">
                <span className="flex h-11 w-11 items-center justify-center rounded-2xl bg-white/10 backdrop-blur">
                  <Icon size={20} />
                </span>
                <div>
                  <dd className="text-2xl font-bold leading-none tabular-nums">{value.toLocaleString()}</dd>
                  <dt className="mt-1 text-xs uppercase tracking-wider text-white/60"><T k={label} /></dt>
                </div>
              </div>
            ))}
          </dl>
        </div>
      </section>

      <Reveal><LiveVisitors data={live} /></Reveal>

      <Reveal><TodaysNewSongs songs={recent} /></Reveal>

      <Reveal><SongShelf title={<T k="newestSongsLabel" />} songs={newest} href="/songbook" /></Reveal>
      <Reveal><SongShelf title={<T k="popularSongsLabel" />} songs={popular} href="/songbook" /></Reveal>

      <Reveal className="mt-14">
        <section>
          <div className="mb-5 flex items-end justify-between gap-4">
            <h2 className="text-xl font-bold tracking-tight sm:text-2xl">
              <T k="exploreArtists" />
            </h2>
            <Link href="/songbook" className="flex items-center gap-1 text-sm font-semibold text-blue-600 hover:gap-2">
              <T k="seeAll" /> <ArrowRight size={15} />
            </Link>
          </div>
          <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5">
            {artists.slice(0, 10).map((a) => (
              <ArtistCard key={a.id} artist={a} />
            ))}
          </div>
        </section>
      </Reveal>

      <section className="mt-16">
        <h2 className="mb-6 text-xl font-bold tracking-tight sm:text-2xl">
          <T k="everythingYouNeed" />
        </h2>
        <Reveal stagger className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {FEATURES.map(({ icon: Icon, key }, i) => (
            <div
              key={key}
              style={{ ["--i" as string]: i }}
              className="rounded-3xl border border-black/5 bg-gradient-to-b from-white to-neutral-50 p-6 shadow-[0_2px_16px_-8px_rgba(0,0,0,0.15)] transition duration-300 hover:-translate-y-1 hover:shadow-[0_16px_32px_-14px_rgba(0,0,0,0.2)]"
            >
              <span className="flex h-12 w-12 items-center justify-center rounded-2xl bg-gradient-to-br from-indigo-500 to-sky-500 text-white shadow-lg shadow-indigo-500/30">
                <Icon size={22} />
              </span>
              <h3 className="mt-4 font-semibold text-neutral-900">
                <T k={`${key}Title`} />
              </h3>
              <p className="mt-1.5 text-sm leading-relaxed text-neutral-500">
                <T k={`${key}Text`} />
              </p>
            </div>
          ))}
        </Reveal>
      </section>

      <Reveal><TeamSection team={team} /></Reveal>

      {shopProducts.length > 0 && (
        <Reveal className="mt-14">
          <section>
            <div className="mb-5 flex items-end justify-between gap-4">
              <h2 className="text-xl font-bold tracking-tight sm:text-2xl">
                <T k="shopLabel" />
              </h2>
              <Link href="/shop" className="flex items-center gap-1 text-sm font-semibold text-blue-600 hover:gap-2">
                <T k="seeAll" /> <ArrowRight size={15} />
              </Link>
            </div>
            <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5">
              {shopProducts.slice(0, 5).map((p) => (
                <ShopProductCard key={p.id} product={p} />
              ))}
            </div>
          </section>
        </Reveal>
      )}

      <section className="mt-16">
        <h2 className="mb-6 text-xl font-bold tracking-tight sm:text-2xl">
          <T k="moreAboutPaimornLabel" />
        </h2>
        <Reveal stagger className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-5">
          {MORE_LINKS.map(({ icon: Icon, href, key }, i) => (
            <Link
              key={href}
              href={href}
              style={{ ["--i" as string]: i }}
              className="lift-spring flex flex-col items-center gap-3 rounded-3xl border border-black/5 bg-white py-7 text-center shadow-[0_2px_16px_-8px_rgba(0,0,0,0.15)] transition hover:-translate-y-0.5 hover:shadow-[0_12px_32px_-14px_rgba(0,0,0,0.3)] active:scale-[0.98] active:shadow-[0_2px_10px_-6px_rgba(0,0,0,0.2)]"
            >
              <span className="flex h-12 w-12 items-center justify-center rounded-2xl bg-neutral-100 text-neutral-700">
                <Icon size={22} />
              </span>
              <span className="font-semibold text-neutral-900">
                <T k={key} />
              </span>
            </Link>
          ))}
        </Reveal>
      </section>
    </div>
  );
}
