"use client";

import Link from "next/link";
import { PenLine } from "lucide-react";
import { useAuth } from "@/components/AuthProvider";
import { useT } from "@/components/LanguageProvider";

// The pencil that appears next to songs while an admin has Edit Mode on
// (account menu). It opens the editor in admin "release" mode
// (/submit-song?edit=<id>). Renders nothing for everyone else — the actual
// protection is firestore.rules, this only keeps the button out of sight.
export default function EditSongButton({
  songId,
  variant,
}: {
  songId: string;
  /** cover: floats on a song card's cover; row: sits in a list row; pill: labelled button in the reader header */
  variant: "cover" | "row" | "pill";
}) {
  const { editMode } = useAuth();
  const { t } = useT();
  if (!editMode) return null;

  const href = `/submit-song?edit=${songId}`;
  const label = t("editSongTooltip");
  if (variant === "pill") {
    return (
      <Link
        href={href}
        className="no-print inline-flex h-10 items-center gap-2 rounded-full bg-neutral-100 px-4 text-sm font-semibold text-neutral-800 transition hover:bg-neutral-200"
      >
        <PenLine size={16} /> {t("editModeLabel")}
      </Link>
    );
  }
  return (
    <Link
      href={href}
      title={label}
      aria-label={label}
      className={
        variant === "cover"
          ? "absolute right-2 top-2 z-10 flex h-8 w-8 items-center justify-center rounded-full bg-black/60 text-white backdrop-blur transition hover:bg-black/80"
          : "mr-3 flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-neutral-600 transition hover:bg-black/5"
      }
    >
      <PenLine size={variant === "cover" ? 15 : 17} />
    </Link>
  );
}
