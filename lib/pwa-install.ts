"use client";

import { useSyncExternalStore } from "react";

// Port of pwa_install_controller_web.dart. Chrome/Edge/Android fire
// `beforeinstallprompt` once, early, so it's captured at module load (the
// store is imported by the root layout) and kept until the banner needs it.
type InstallPromptEvent = Event & { prompt: () => Promise<void>; userChoice: Promise<{ outcome: string }> };

let deferred: InstallPromptEvent | null = null;
const listeners = new Set<() => void>();
const emit = () => listeners.forEach((l) => l());

if (typeof window !== "undefined") {
  window.addEventListener("beforeinstallprompt", (e) => {
    e.preventDefault(); // we show our own banner instead of the browser's mini-infobar
    deferred = e as InstallPromptEvent;
    emit();
  });
  window.addEventListener("appinstalled", () => {
    deferred = null;
    emit();
  });
}

const subscribe = (cb: () => void) => {
  listeners.add(cb);
  return () => void listeners.delete(cb);
};

export type InstallState = "none" | "prompt" | "ios";

const isIOS = () => /iphone|ipad|ipod/i.test(navigator.userAgent);
const isStandalone = () =>
  window.matchMedia("(display-mode: standalone)").matches || (navigator as Navigator & { standalone?: boolean }).standalone === true;

/** What (if anything) the install banner should offer on this device right now. */
export function useInstallState(): InstallState {
  return useSyncExternalStore(
    subscribe,
    (): InstallState => (isStandalone() ? "none" : isIOS() ? "ios" : deferred ? "prompt" : "none"),
    () => "none",
  );
}

export async function promptInstall(): Promise<void> {
  const event = deferred;
  if (!event) return;
  await event.prompt();
  await event.userChoice.catch(() => {});
  deferred = null; // a prompt can only be used once
  emit();
}
