"use client";

import { useEffect, useRef, useState } from "react";
import { Check, Globe } from "lucide-react";
import { useT } from "@/components/LanguageProvider";
import { LANGUAGES } from "@/lib/i18n";

// The globe button in the navbar: a dropdown of the four UI languages.
export default function LanguageMenu() {
  const { lang, setLang, t } = useT();
  const [open, setOpen] = useState(false);
  const rootRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const onPointer = (e: PointerEvent) => {
      if (!rootRef.current?.contains(e.target as Node)) setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setOpen(false);
    document.addEventListener("pointerdown", onPointer);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("pointerdown", onPointer);
      document.removeEventListener("keydown", onKey);
    };
  }, [open]);

  return (
    <div ref={rootRef} className="relative">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-label={t("languageLabel")}
        aria-haspopup="menu"
        aria-expanded={open}
        className="lift-spring flex h-9 w-9 items-center justify-center rounded-xl transition hover:bg-black/5 active:scale-90 sm:h-10 sm:w-10"
      >
        <Globe size={20} />
      </button>
      {open && (
        <div
          role="menu"
          className="absolute right-0 top-[calc(100%+10px)] z-50 w-48 overflow-hidden rounded-2xl border border-black/10 bg-white p-1.5 shadow-[0_20px_50px_-15px_rgba(0,0,0,0.35)]"
        >
          {LANGUAGES.map((l) => (
            <button
              key={l.code}
              type="button"
              role="menuitemradio"
              aria-checked={lang === l.code}
              onClick={() => {
                setLang(l.code);
                setOpen(false);
              }}
              className="flex w-full items-center justify-between rounded-xl px-3 py-2.5 text-left text-[15px] text-neutral-800 transition hover:bg-neutral-100"
            >
              <span lang={l.code === "mm" ? "my" : l.code}>{l.label}</span>
              {lang === l.code && <Check size={16} className="text-blue-600" />}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
