"use client";

import { useEffect, useState } from "react";
import Image from "next/image";
import { collection, onSnapshot, orderBy, query } from "firebase/firestore";
import { HeartHandshake } from "lucide-react";
import PageShell, { cardClass } from "@/components/PageShell";
import { useT } from "@/components/LanguageProvider";
import { db } from "@/lib/firebase/client";

// Owner-provided (2026-09-22). If this ever needs to change, replace just this string.
const PAYPAL_URL = "https://paypal.me/nankhanlone";

type Supporter = { id: string; name: string; message: string };

// Voluntary support for hosting costs — no ads on the site (see the privacy
// policy), so this is the alternative. Two methods for now: a PromptPay QR
// (pre-generated as a static image by scripts/generate-promptpay-qr.mjs, see
// its header comment — never hand-roll a payment QR here) and a PayPal link.
export default function SupportView() {
  const { t } = useT();

  // Manually curated by an admin (components/admin/SupportersAdminView.tsx) — neither
  // payment method here gives this app a way to detect a donation automatically.
  const [supporters, setSupporters] = useState<Supporter[] | null>(null);
  useEffect(() => {
    return onSnapshot(query(collection(db, "supporters"), orderBy("createdAt", "desc")), (snap) =>
      setSupporters(
        snap.docs.map((d) => {
          const x = d.data();
          return { id: d.id, name: typeof x.name === "string" ? x.name : "", message: typeof x.message === "string" ? x.message : "" };
        }),
      ),
    );
  }, []);

  return (
    <PageShell eyebrow={t("supportLabel")} title={t("supportTitle")} subtitle={t("supportSubtitle")}>
      <div className="grid gap-5 sm:grid-cols-2">
        <div className={`${cardClass} flex flex-col items-center text-center`}>
          <h2 className="font-bold text-neutral-900">{t("supportPromptPayTitle")}</h2>
          <p className="mt-1.5 text-sm text-neutral-500">{t("supportPromptPayBody")}</p>
          <div className="mt-5 overflow-hidden rounded-2xl border border-black/5 p-2">
            <Image src="/promptpay-qr.png" alt={t("supportPromptPayTitle")} width={260} height={260} />
          </div>
        </div>

        <div className={`${cardClass} flex flex-col items-center text-center`}>
          <h2 className="font-bold text-neutral-900">{t("supportPaypalTitle")}</h2>
          <p className="mt-1.5 text-sm text-neutral-500">{t("supportPaypalBody")}</p>
          <a
            href={PAYPAL_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="mt-6 flex h-12 items-center gap-2 rounded-full bg-[#0070ba] px-7 text-[15px] font-bold text-white shadow-lg shadow-[#0070ba]/25 transition hover:scale-[1.03]"
          >
            {t("supportPaypalButton")}
          </a>
        </div>
      </div>

      <p className="mt-8 flex items-center justify-center gap-2 text-center text-neutral-500">
        <HeartHandshake size={18} className="shrink-0 text-rose-500" /> {t("supportThanks")}
      </p>

      {/* Hidden entirely until there's at least one name — an empty "With thanks to"
          section would read oddly on a brand-new page. */}
      {supporters && supporters.length > 0 && (
        <div className="mt-10">
          <h2 className="text-center text-sm font-bold uppercase tracking-[0.14em] text-neutral-400">{t("supportersTitle")}</h2>
          <div className="mt-4 flex flex-wrap justify-center gap-2">
            {supporters.map((s) => (
              <span
                key={s.id}
                title={s.message || undefined}
                className="rounded-full border border-black/5 bg-white px-4 py-2 text-sm font-semibold text-neutral-700 shadow-[0_2px_12px_-8px_rgba(0,0,0,0.15)]"
              >
                {s.name}
              </span>
            ))}
          </div>
        </div>
      )}
    </PageShell>
  );
}
