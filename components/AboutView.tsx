"use client";

import Link from "next/link";
import PageShell, { cardClass } from "@/components/PageShell";
import { useT } from "@/components/LanguageProvider";

// The Team section that used to live here moved to the Home page
// (components/TeamSection.tsx) — the owner wanted contributors seen by
// visitors, not buried on an About page few people open.
export default function AboutView() {
  const { t } = useT();

  return (
    <PageShell eyebrow={t("aboutEyebrow")} title={t("aboutTitle")}>
      <div className={cardClass}>
        <p className="whitespace-pre-line text-lg leading-relaxed text-neutral-700 sm:text-xl">{t("aboutMission")}</p>
      </div>

      <div className="mt-6 flex flex-col items-start gap-4 rounded-3xl bg-gradient-to-br from-indigo-600 via-blue-600 to-sky-500 p-6 text-white shadow-[0_20px_50px_-20px_rgba(37,99,235,0.55)] sm:flex-row sm:items-center sm:justify-between sm:p-8">
        <div>
          <h2 className="text-xl font-bold">{t("aboutCtaHeading")}</h2>
          <p className="mt-1.5 max-w-md text-white/85">{t("aboutCtaDescription")}</p>
        </div>
        <Link
          href="/submit-song"
          className="keep-light shrink-0 rounded-full bg-white px-6 py-3 text-sm font-semibold text-blue-700 shadow-lg transition hover:scale-[1.03]"
        >
          {t("submitSongTitle")}
        </Link>
      </div>
    </PageShell>
  );
}
