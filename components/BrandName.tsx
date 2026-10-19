"use client";

import { useT } from "@/components/LanguageProvider";

// The site name as a wordmark: "Paimorn" (Lobster) in every language except
// Shan, where it becomes ပၢႆးမွၼ်း in the AJ Kunheing 19 brand font. The name
// itself is the `brandName` translation; sizing comes from the parent.
export default function BrandName({ className = "" }: { className?: string }) {
  const { lang, t } = useT();
  if (lang === "shn") {
    return (
      <span lang="shn" className={`brand-shn ${className}`}>
        {t("brandName")}
      </span>
    );
  }
  return <span className={`font-logo ${className}`}>{t("brandName")}</span>;
}
