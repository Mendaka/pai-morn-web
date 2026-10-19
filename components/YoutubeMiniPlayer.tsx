"use client";

import { ExternalLink, X } from "lucide-react";
import { useT } from "@/components/LanguageProvider";

// A small floating YouTube player pinned to the corner (12rem on phones, 16rem
// on wider screens), so the original song plays while you read. Deliberately a
// real, visible player and not hidden or shrunk to nothing: hiding it would also hide YouTube's own "Skip ad" button
// whenever a pre-roll plays. (YouTube offers no audio-only embed.)
//
// If the video's owner has disabled embedding, YouTube shows its own message
// with a "Watch on YouTube" link inside the frame; the "Open on YouTube" link
// here is a second way out.
export default function YoutubeMiniPlayer({ videoId, onClose }: { videoId: string; onClose: () => void }) {
  const { t } = useT();
  return (
    <div className="no-print fixed bottom-20 right-3 z-50 w-48 max-w-[calc(100vw-1.5rem)] overflow-hidden rounded-xl bg-black shadow-[0_20px_50px_-10px_rgba(0,0,0,0.6)] ring-1 ring-white/10 md:bottom-5 md:right-5 md:w-64">
      <div className="flex items-center justify-between bg-neutral-900 px-2.5 py-1 text-[11px] text-white/80">
        <a
          href={`https://www.youtube.com/watch?v=${videoId}`}
          target="_blank"
          rel="noopener noreferrer"
          className="flex items-center gap-1.5 hover:text-white"
        >
          <ExternalLink size={11} /> {t("openOnYoutube")}
        </a>
        <button
          type="button"
          onClick={onClose}
          aria-label={t("closeLabel")}
          className="flex h-5 w-5 items-center justify-center rounded-full hover:bg-white/15"
        >
          <X size={13} />
        </button>
      </div>
      <iframe
        title="YouTube"
        src={`https://www.youtube.com/embed/${videoId}?autoplay=1&playsinline=1&rel=0`}
        allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
        allowFullScreen
        // Without a referrer YouTube's player can refuse to start ("Error 153").
        referrerPolicy="strict-origin-when-cross-origin"
        className="aspect-video w-full border-0"
      />
    </div>
  );
}
