import { Globe } from "lucide-react";
import { T } from "@/components/LanguageProvider";
import type { LiveVisitors as LiveVisitorsData } from "@/lib/ga-realtime";

// Public, on the Home page (owner: "อยากให้ทุกคนเห็น") — backed by the real
// Google Analytics Realtime report (lib/ga-realtime.ts), not a custom
// presence system. Renders nothing when there's no data (GA unreachable,
// credentials not yet set up) or nobody's currently on the site — an empty
// "0 people reading" line reads worse than no widget at all.
export default function LiveVisitors({ data }: { data: LiveVisitorsData | null }) {
  if (!data || data.total === 0) return null;

  const TOP = 5;
  const top = data.locations.slice(0, TOP);
  const rest = data.locations.slice(TOP).reduce((sum, l) => sum + l.count, 0);

  return (
    <div className="mt-6 rounded-2xl border border-black/5 bg-white p-4 shadow-[0_2px_16px_-8px_rgba(0,0,0,0.15)] sm:p-5">
      <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wider text-neutral-500">
        <span className="relative flex h-2 w-2 shrink-0" aria-hidden>
          <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-400 opacity-75" />
          <span className="relative inline-flex h-2 w-2 rounded-full bg-emerald-500" />
        </span>
        <T k="liveNowLabel" />
      </div>

      <div className="mt-2.5 flex flex-wrap items-center gap-x-3 gap-y-2">
        <span className="flex items-center gap-2 text-sm font-semibold text-neutral-800">
          <Globe size={16} className="shrink-0 text-neutral-500" aria-hidden />
          <T k={data.total === 1 ? "liveVisitorsLabelSingular" : "liveVisitorsLabel"} vars={{ n: data.total }} />
        </span>
        <span className="flex flex-wrap gap-1.5">
          {top.map((l) => (
            <span key={`${l.country}-${l.city ?? ""}`} className="rounded-full bg-neutral-100 px-2.5 py-1 text-xs font-medium text-neutral-600">
              {l.city ? `${l.city}, ${l.country}` : l.country} · {l.count}
            </span>
          ))}
          {rest > 0 && (
            <span className="rounded-full bg-neutral-100 px-2.5 py-1 text-xs font-medium text-neutral-600">+{rest}</span>
          )}
        </span>
      </div>
    </div>
  );
}
