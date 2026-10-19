"use client";

import { ExternalLink, Mail } from "lucide-react";
import PageShell from "@/components/PageShell";
import { useT } from "@/components/LanguageProvider";

const EMAIL = "hseng2018@gmail.com";
const FACEBOOK_URL = "https://www.facebook.com/taidevIT/?locale=th_TH";

export default function ContactView() {
  const { t } = useT();
  const rows = [
    { href: `mailto:${EMAIL}`, label: t("email"), value: EMAIL, icon: <Mail size={22} />, external: false },
    {
      href: FACEBOOK_URL,
      label: "Facebook",
      value: "facebook.com/taidevIT",
      icon: <span className="flex h-[22px] w-[22px] items-center justify-center rounded-full bg-neutral-800 text-[13px] font-bold leading-none text-white">f</span>,
      external: true,
    },
  ];

  return (
    <PageShell title={t("contact")}>
      <div className="space-y-4">
        {rows.map((r) => (
          <a
            key={r.label}
            href={r.href}
            {...(r.external ? { target: "_blank", rel: "noopener noreferrer" } : {})}
            className="lift-spring group flex items-center gap-4 rounded-3xl border border-black/5 bg-white/90 p-5 shadow-[0_2px_24px_-8px_rgba(0,0,0,0.12)] backdrop-blur transition hover:-translate-y-0.5 hover:shadow-[0_14px_36px_-16px_rgba(0,0,0,0.3)] active:scale-[0.98] active:shadow-[0_2px_10px_-6px_rgba(0,0,0,0.15)]"
          >
            <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-neutral-100 text-neutral-800">{r.icon}</span>
            <span className="min-w-0 flex-1">
              <span className="block text-sm text-neutral-500">{r.label}</span>
              <span className="block truncate text-lg font-semibold">{r.value}</span>
            </span>
            <ExternalLink size={18} className="shrink-0 text-neutral-300 transition group-hover:text-neutral-600" />
          </a>
        ))}
      </div>
    </PageShell>
  );
}
