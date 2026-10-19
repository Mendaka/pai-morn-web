"use client";

import { Smartphone, X } from "lucide-react";
import { useT } from "@/components/LanguageProvider";
import { promptInstall, useInstallState } from "@/lib/pwa-install";
import { useStored, writeStored } from "@/lib/stored";

const KEY = "pm.installDismissed";

// A dismissible "Install this app" strip at the top of Home. Hidden once the
// app is installed / running standalone, once dismissed, and on browsers that
// can't install. iPhones can't be prompted, so they get the manual steps.
export default function InstallBanner() {
  const { t } = useT();
  const state = useInstallState();
  const dismissed = useStored(KEY) === "1";
  if (dismissed || state === "none") return null;

  return (
    <div role="region" aria-label={t("installAppTitle")} className="mb-4 flex items-center gap-3 rounded-2xl border border-black/5 bg-neutral-100 p-4">
      <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-white text-neutral-800 shadow-sm">
        <Smartphone size={20} />
      </span>
      <div className="min-w-0 flex-1">
        <p className="font-semibold text-neutral-900">{t("installAppTitle")}</p>
        {state === "ios" && <p className="mt-0.5 text-sm text-neutral-600">{t("installAppIosInstructions")}</p>}
      </div>
      {state === "prompt" && (
        <button type="button" onClick={() => void promptInstall()} className="h-10 shrink-0 rounded-xl bg-black px-5 text-sm font-semibold text-white transition hover:bg-neutral-800">
          {t("installButtonLabel")}
        </button>
      )}
      <button type="button" onClick={() => writeStored(KEY, "1")} aria-label={t("notNowButtonLabel")} title={t("notNowButtonLabel")} className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-neutral-500 transition hover:bg-black/5">
        <X size={17} />
      </button>
    </div>
  );
}
