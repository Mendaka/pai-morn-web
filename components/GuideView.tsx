"use client";

import { AlertTriangle, BookOpen, Gauge, Globe, Guitar, Heart, ListChecks, Mail, PlusCircle, Search, Smartphone, Users } from "lucide-react";
import PageShell, { cardClass } from "@/components/PageShell";
import { useT } from "@/components/LanguageProvider";

// [icon, title key, description key, accent] — the same twelve tips, in the
// same order, as the Flutter app's Guide screen.
const TIPS: [typeof BookOpen, string, string, string][] = [
  [BookOpen, "songbook", "guideSongbookDesc", "#6366f1"],
  [Search, "guideSearchTitle", "guideSearchDesc", "#0ea5e9"],
  [Gauge, "tunerLabel", "guideTunerDesc", "#14b8a6"],
  [Guitar, "chordsLabel", "guideChordsDesc", "#f59e0b"],
  [ListChecks, "setlistsTitle", "guideSetlistsDesc", "#22c55e"],
  [Heart, "favoritesTitle", "guideFavoritesDesc", "#f43f5e"],
  [Users, "communityLabel", "guideCommunityDesc", "#8b5cf6"],
  [PlusCircle, "submitSongTitle", "guideSubmitDesc", "#2563eb"],
  [Mail, "requestSongLabel", "guideRequestDesc", "#ec4899"],
  [AlertTriangle, "reportIssueTooltip", "guideReportDesc", "#ea580c"],
  [Smartphone, "installAppTitle", "guideInstallDesc", "#0d9488"],
  [Globe, "guideLanguageTitle", "guideLanguageDesc", "#64748b"],
];

export default function GuideView() {
  const { t } = useT();
  return (
    <PageShell title={t("guideTitle")} subtitle={t("guideIntro")} size="lg">
      <div className="grid gap-4 sm:grid-cols-2">
        {TIPS.map(([Icon, titleKey, descKey, accent]) => (
          <div key={titleKey} className={`${cardClass} !p-5 sm:!p-6`}>
            <div className="flex items-center gap-3">
              <span
                className="flex h-10 w-10 shrink-0 items-center justify-center rounded-2xl text-white shadow-md"
                style={{ background: accent }}
              >
                <Icon size={19} />
              </span>
              <h2 className="text-lg font-bold">{t(titleKey)}</h2>
            </div>
            <p className="mt-3 leading-relaxed text-neutral-600">{t(descKey)}</p>
          </div>
        ))}
      </div>
    </PageShell>
  );
}
