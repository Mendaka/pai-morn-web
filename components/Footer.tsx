import Link from "next/link";
import Image from "next/image";
import { Mail } from "lucide-react";
import BrandName from "@/components/BrandName";
import { T } from "@/components/LanguageProvider";
import { FOOTER_LINKS, NAV_ITEMS } from "@/lib/nav";

// Desktop/tablet only — phones get the same links as a "More about Paimorn"
// section on the Home page instead (app/page.tsx), since the bottom tab bar
// replaces this footer there and there'd otherwise be no room for it.
//
// A permanently dark band (independent of the site's light/dark toggle),
// the same look the Home hero section already uses — a footer reads more
// like a stable "bottom of the site" fixture than another content card, and
// it means one deliberately dark section instead of chasing every neutral
// utility through the light/dark remap in globals.css.
export default function Footer() {
  return (
    <footer className="relative mt-20 hidden overflow-hidden bg-neutral-950 text-white md:block">
      <div className="pointer-events-none absolute -left-24 bottom-0 h-72 w-72 rounded-full bg-indigo-500/20 blur-3xl" />
      <div className="pointer-events-none absolute -right-16 top-0 h-64 w-64 rounded-full bg-sky-500/15 blur-3xl" />

      <div className="relative mx-auto grid max-w-[1600px] grid-cols-[1.4fr_1fr_1fr_1fr] gap-10 px-10 py-16">
        <div className="max-w-xs">
          <p className="text-3xl leading-none text-white">
            <BrandName />
          </p>
          <p className="mt-4 text-sm leading-relaxed text-white/60">
            <T k="homeHeroSubtitle" />
          </p>
          <a
            href="https://play.google.com/store/apps/details?id=com.paimorn.songbook"
            target="_blank"
            rel="noopener noreferrer"
            aria-label="Get it on Google Play"
            className="mt-5 inline-block"
          >
            <Image src="/images/google-play-badge.png" alt="Get it on Google Play" width={450} height={253} className="h-[72px] w-auto" />
          </a>
        </div>

        <FooterColumn title={<T k="footerExploreLabel" />}>
          {NAV_ITEMS.map((l) => (
            <Link key={l.href} href={l.href} className="text-white/60 transition hover:text-white">
              <T k={l.key} />
            </Link>
          ))}
        </FooterColumn>

        <FooterColumn title={<T k="footerCompanyLabel" />}>
          {FOOTER_LINKS.map((l) => (
            <Link key={l.href} href={l.href} className="text-white/60 transition hover:text-white">
              <T k={l.key} />
            </Link>
          ))}
        </FooterColumn>

        <FooterColumn title={<T k="footerContactLabel" />}>
          <a href="mailto:hseng2018@gmail.com" className="flex items-center gap-2.5 text-white/60 transition hover:text-white">
            <Mail size={16} className="shrink-0" /> hseng2018@gmail.com
          </a>
          <a
            href="https://facebook.com/taidevIT"
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-2.5 text-white/60 transition hover:text-white"
          >
            <span className="flex h-4 w-4 shrink-0 items-center justify-center rounded-full bg-white/15 text-[10px] font-bold leading-none">f</span>
            facebook.com/taidevIT
          </a>
        </FooterColumn>
      </div>

      <div className="relative border-t border-white/10">
        <div className="mx-auto max-w-[1600px] px-10 py-5 text-sm text-white/40">© {new Date().getFullYear()} Paimorn <span className="mx-1">·</span>
          <span lang="shn" className="brand-shn text-lg leading-none text-white/70">ပၢႆးမွၼ်း</span>
        </div>
      </div>
    </footer>
  );
}

function FooterColumn({ title, children }: { title: React.ReactNode; children: React.ReactNode }) {
  return (
    <div>
      <p className="text-xs font-bold uppercase tracking-[0.14em] text-white/40">{title}</p>
      <div className="mt-4 flex flex-col gap-3 text-sm">{children}</div>
    </div>
  );
}
