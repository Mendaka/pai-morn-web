"use client";

import { useCallback, useRef, useState } from "react";
import { useT } from "@/components/LanguageProvider";

type Spec = { title: string; placeholder?: string; initial?: string; confirmLabel: string };

/**
 * A promise-based "type a name" dialog (Flutter's showDialog + TextField):
 * `prompt({...})` resolves to the trimmed text, or null if cancelled or left
 * empty. Render `{promptDialog}` somewhere in the component tree.
 */
export function usePrompt() {
  const { t } = useT();
  const [spec, setSpec] = useState<Spec | null>(null);
  const [value, setValue] = useState("");
  const resolver = useRef<((v: string | null) => void) | null>(null);

  const prompt = useCallback((s: Spec) => {
    return new Promise<string | null>((resolve) => {
      resolver.current = resolve;
      setValue(s.initial ?? "");
      setSpec(s);
    });
  }, []);

  const close = (result: string | null) => {
    resolver.current?.(result);
    resolver.current = null;
    setSpec(null);
  };
  const submit = () => close(value.trim() || null);

  const promptDialog = spec && (
    <div
      className="fixed inset-0 z-[70] flex items-center justify-center bg-black/40 p-4 backdrop-blur-sm"
      onClick={() => close(null)}
    >
      <form
        role="dialog"
        aria-modal="true"
        aria-label={spec.title}
        onClick={(e) => e.stopPropagation()}
        onSubmit={(e) => {
          e.preventDefault();
          submit();
        }}
        className="w-full max-w-sm rounded-3xl bg-white p-6 shadow-2xl"
      >
        <h2 className="text-lg font-bold">{spec.title}</h2>
        <input
          autoFocus
          value={value}
          onChange={(e) => setValue(e.target.value)}
          onKeyDown={(e) => e.key === "Escape" && close(null)}
          placeholder={spec.placeholder}
          maxLength={80}
          className="plain-input mt-4"
        />
        <div className="mt-6 flex justify-end gap-2">
          <button type="button" onClick={() => close(null)} className="h-10 rounded-full px-5 text-sm font-medium hover:bg-neutral-100">
            {t("cancelButton")}
          </button>
          <button type="submit" className="h-10 rounded-full bg-black px-5 text-sm font-semibold text-white hover:bg-neutral-800">
            {spec.confirmLabel}
          </button>
        </div>
      </form>
    </div>
  );

  return { prompt, promptDialog };
}
