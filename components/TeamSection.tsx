"use client";

import { Star } from "lucide-react";
import { T, useT } from "@/components/LanguageProvider";
import UserAvatar from "@/components/UserAvatar";
import { badgeColor, badgeTier } from "@/lib/badge";
import { gradientFor } from "@/lib/palette";
import type { TeamMember } from "@/lib/team";

// Moved here from the About page (owner: "เพราะคนเหล่านี้คือผู้ช่วยเขียน" —
// visitors should actually see the people behind the songbook, not just find
// them buried on an About page nobody reads). Same data (lib/team.ts:
// admins first as developers, then everyone with an approved song, ranked by
// count) and the same per-member gradient card, just given its own proper
// section on Home instead of a small caps label.
export default function TeamSection({ team }: { team: TeamMember[] }) {
  const { t } = useT();
  if (team.length === 0) return null;

  const developers = team.filter((m) => m.role === "developer");
  const contributors = team.filter((m) => m.role === "contributor");
  const songs = (n: number) => t(n === 1 ? "songCountLabelSingular" : "songsCountLabel", { count: n });

  return (
    <section className="mt-16">
      <div className="text-center">
        <h2 className="text-xl font-bold tracking-tight sm:text-2xl">
          <T k="aboutTeamHeading" />
        </h2>
        <p className="mx-auto mt-2 max-w-xl text-sm text-neutral-500">
          <T k="teamSectionSubtitle" />
        </p>
      </div>
      <Group label={t("aboutDeveloperLabel")} members={developers} subtitle={() => t("aboutDeveloperLabel")} />
      <Group label={t("aboutContributorLabel")} members={contributors} subtitle={(m) => songs(m.count)} />
    </section>
  );
}

function Group({
  label,
  members,
  subtitle,
}: {
  label: string;
  members: TeamMember[];
  subtitle: (m: TeamMember) => string;
}) {
  if (members.length === 0) return null;
  return (
    <div className="mt-8">
      <p className="text-center text-xs font-semibold uppercase tracking-[0.2em] text-neutral-400">{label}</p>
      <div className="mt-5 flex flex-wrap justify-center gap-x-4 gap-y-8">
        {members.map((m) => {
          const tier = badgeTier(m.count);
          const color = badgeColor(tier);
          return (
            <div
              key={m.uid}
              className="relative flex h-40 w-full max-w-[10.5rem] flex-col items-center justify-end rounded-3xl px-3 pb-5 text-center text-white shadow-lg sm:w-[10.5rem]"
              style={{ background: gradientFor(m.name) }}
            >
              <UserAvatar uid={m.uid} name={m.name} photoUrl={m.photoUrl} size={64} className="absolute -top-8 ring-4 ring-white" />
              {tier > 0 && color && <Star size={14} fill={color} stroke="none" className="mb-1" />}
              <p className="line-clamp-2 text-[15px] font-bold leading-tight">{m.name}</p>
              <p className="mt-1 text-xs text-white/80">{subtitle(m)}</p>
            </div>
          );
        })}
      </div>
    </div>
  );
}
