"use client";

import PageShell from "@/components/PageShell";
import ShopProductCard from "@/components/ShopProductCard";
import { useT } from "@/components/LanguageProvider";
import type { ShopProduct } from "@/lib/shop";

export default function ShopView({ products }: { products: ShopProduct[] }) {
  const { t } = useT();
  return (
    <PageShell title={t("shopLabel")} subtitle={t("shopIntro")}>
      {products.length === 0 ? (
        <p className="rounded-3xl border border-dashed border-black/10 px-6 py-12 text-center text-neutral-500">{t("noProductsYet")}</p>
      ) : (
        <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4">
          {products.map((p) => (
            <ShopProductCard key={p.id} product={p} />
          ))}
        </div>
      )}
    </PageShell>
  );
}
