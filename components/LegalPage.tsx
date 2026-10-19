"use client";

import PageShell, { cardClass } from "@/components/PageShell";
import { useT } from "@/components/LanguageProvider";

// Privacy Policy / Terms of Service: one long text per language, stored under
// a single i18n key. Same tiny convention as the Flutter app — blocks are
// separated by a blank line, and a block starting with "## " is a section
// heading (the rest of that block is its body).
function parseSections(raw: string): { heading: string | null; body: string }[] {
  return raw.split("\n\n").map((block) => {
    if (!block.startsWith("## ")) return { heading: null, body: block };
    const nl = block.indexOf("\n");
    return nl === -1
      ? { heading: block.slice(3), body: "" }
      : { heading: block.slice(3, nl), body: block.slice(nl + 1) };
  });
}

export default function LegalPage({ titleKey, updatedKey, bodyKey }: { titleKey: string; updatedKey: string; bodyKey: string }) {
  const { t } = useT();
  const sections = parseSections(t(bodyKey));

  return (
    <PageShell title={t(titleKey)} subtitle={t(updatedKey)}>
      <article className={`${cardClass} space-y-5`}>
        {sections.map((s, i) => (
          <section key={i}>
            {s.heading && <h2 className="text-lg font-bold text-neutral-900">{s.heading}</h2>}
            {s.body && <p className={`whitespace-pre-line leading-relaxed text-neutral-600 ${s.heading ? "mt-2" : ""}`}>{s.body}</p>}
          </section>
        ))}
      </article>
    </PageShell>
  );
}
