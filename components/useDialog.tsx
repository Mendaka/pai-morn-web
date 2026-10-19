"use client";

import { useCallback, useRef, useState } from "react";

export type DialogAction<T> = { label: string; value: T; tone?: "primary" | "plain" | "danger" };
type Spec<T> = { title: string; message: string; actions: DialogAction<T>[] };

/**
 * Promise-based modal, so submit flows can `await` a decision like Flutter's
 * showDialog. `ask` resolves to the chosen action's value, or null when the
 * dialog is dismissed (backdrop click / Escape).
 *
 *   const { ask, dialog } = useDialog();
 *   const ok = await ask({ title, message, actions: [...] });
 *   ...render {dialog} somewhere in the component tree
 */
export function useDialog() {
  const [spec, setSpec] = useState<Spec<unknown> | null>(null);
  const resolver = useRef<((v: unknown) => void) | null>(null);

  const ask = useCallback(<T,>(s: Spec<T>) => {
    return new Promise<T | null>((resolve) => {
      resolver.current = resolve as (v: unknown) => void;
      setSpec(s as Spec<unknown>);
    });
  }, []);

  const close = (value: unknown) => {
    resolver.current?.(value);
    resolver.current = null;
    setSpec(null);
  };

  const dialog = spec && (
    <div
      className="fixed inset-0 z-[70] flex items-center justify-center bg-black/40 p-4 backdrop-blur-sm"
      onClick={() => close(null)}
      onKeyDown={(e) => e.key === "Escape" && close(null)}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-label={spec.title}
        onClick={(e) => e.stopPropagation()}
        className="w-full max-w-sm rounded-3xl bg-white p-6 shadow-2xl"
      >
        <h2 className="text-lg font-bold">{spec.title}</h2>
        <p className="mt-2 text-neutral-500">{spec.message}</p>
        <div className="mt-6 flex flex-wrap justify-end gap-2">
          {spec.actions.map((a) => (
            <button
              key={a.label}
              type="button"
              autoFocus={a.tone === "primary"}
              onClick={() => close(a.value)}
              className={`h-10 rounded-full px-5 text-sm font-semibold transition ${
                a.tone === "primary"
                  ? "bg-black text-white hover:bg-neutral-800"
                  : a.tone === "danger"
                    ? "bg-red-600 text-white hover:bg-red-700"
                    : "hover:bg-neutral-100"
              }`}
            >
              {a.label}
            </button>
          ))}
        </div>
      </div>
    </div>
  );

  return { ask, dialog };
}
