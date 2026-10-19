"use client";

import { useState } from "react";

export type Suggestion = { key: string; title: string; subtitle?: string; pick: () => void };

// A text input with a dropdown of suggestions underneath. Suggestions open
// while the field is focused and there's something to show; picking one
// (mouse-down, so it lands before the input's blur) runs its `pick`.
export default function SuggestInput({
  label,
  value,
  onChange,
  suggestions,
  placeholder,
  right,
  required,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  suggestions: Suggestion[];
  placeholder?: string;
  right?: React.ReactNode;
  required?: boolean;
}) {
  const [focused, setFocused] = useState(false);
  const open = focused && suggestions.length > 0;

  return (
    <div className="flex items-start gap-2">
      <label className="relative block min-w-0 flex-1">
        <span className="mb-1.5 block text-sm font-medium text-neutral-700">
          {label}
          {required && <span className="text-rose-500"> *</span>}
        </span>
        <input
          className="plain-input"
          value={value}
          placeholder={placeholder}
          onChange={(e) => onChange(e.target.value)}
          onFocus={() => setFocused(true)}
          onBlur={() => setFocused(false)}
          autoComplete="off"
        />
        {open && (
          <ul
            role="listbox"
            onMouseDown={(e) => e.preventDefault()}
            className="absolute left-0 right-0 top-full z-40 mt-1 max-h-64 overflow-auto rounded-2xl border border-black/10 bg-white p-1 shadow-[0_20px_50px_-15px_rgba(0,0,0,0.35)]"
          >
            {suggestions.map((s) => (
              <li key={s.key}>
                <button
                  type="button"
                  role="option"
                  aria-selected={false}
                  onClick={() => {
                    s.pick();
                    setFocused(false);
                  }}
                  className="block w-full rounded-xl px-3 py-2 text-left transition hover:bg-neutral-100"
                >
                  <span className="block text-[15px] text-neutral-900">{s.title}</span>
                  {s.subtitle && <span className="block text-xs text-neutral-500">{s.subtitle}</span>}
                </button>
              </li>
            ))}
          </ul>
        )}
      </label>
      {right}
    </div>
  );
}
