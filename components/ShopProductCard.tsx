"use client";

import Image from "next/image";
import { ExternalLink } from "lucide-react";
import { useT } from "@/components/LanguageProvider";
import type { ShopProduct } from "@/lib/shop";

export default function ShopProductCard({ product }: { product: ShopProduct }) {
  const { t, lang } = useT();
  const name = lang === "shn" && product.nameShn.trim() ? product.nameShn : product.name;
  return (
    <a
      href={product.lazadaUrl}
      target="_blank"
      rel="noopener noreferrer sponsored"
      className="lift-spring group flex flex-col overflow-hidden rounded-3xl border border-black/5 bg-white shadow-[0_2px_16px_-8px_rgba(0,0,0,0.15)] transition duration-300 hover:-translate-y-1 hover:shadow-[0_18px_36px_-14px_rgba(37,99,235,0.35)] active:scale-[0.98] active:shadow-[0_2px_10px_-6px_rgba(0,0,0,0.2)]"
    >
      <div className="relative aspect-square w-full overflow-hidden bg-neutral-100">
        {product.imageUrl && (
          <Image src={product.imageUrl} alt={name} fill sizes="(min-width: 1024px) 25vw, (min-width: 640px) 33vw, 50vw" className="object-cover transition duration-300 group-hover:scale-105" />
        )}
      </div>
      <div className="flex flex-1 flex-col p-4">
        <h3 className="line-clamp-2 min-h-[2.6rem] text-sm font-semibold leading-snug text-neutral-900">{name}</h3>
        <p className="mt-2 text-lg font-bold text-neutral-900">฿{product.price.toLocaleString()}</p>
        <span className="mt-3 flex items-center gap-1.5 text-sm font-semibold text-blue-600">
          {t("buyOnLazadaLabel")} <ExternalLink size={14} />
        </span>
      </div>
    </a>
  );
}
