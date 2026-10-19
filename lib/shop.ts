import { collection, getDocs, orderBy, query } from "firebase/firestore";
import { serverDb } from "@/lib/firebase/server";

// Small product showcase (2026-10-16) — each item just links out to its real
// Lazada listing; no cart/checkout/payment logic lives on this site at all.
// Admin-managed (components/admin/ShopAdminView.tsx) via the shopProducts
// Firestore collection — see firestore.rules for the read/write shape.
//
// nameShn (2026-10-17): an optional Shan-script override for the product
// name, shown instead of `name` when the interface language is Shan — not
// a full per-language map like the static i18n files, just the one language
// the owner actually asked for. Falls back to `name` when empty, same
// "missing translation falls back to the default" convention used
// elsewhere on the site.
export type ShopProduct = {
  id: string;
  name: string;
  nameShn: string;
  price: number;
  imageUrl: string;
  lazadaUrl: string;
};

export async function getShopProducts(): Promise<ShopProduct[]> {
  const snap = await getDocs(query(collection(serverDb, "shopProducts"), orderBy("createdAt", "desc")));
  return snap.docs.map((d) => {
    const x = d.data();
    return {
      id: d.id,
      name: typeof x.name === "string" ? x.name : "",
      nameShn: typeof x.nameShn === "string" ? x.nameShn : "",
      price: typeof x.price === "number" ? x.price : 0,
      imageUrl: typeof x.imageUrl === "string" ? x.imageUrl : "",
      lazadaUrl: typeof x.lazadaUrl === "string" ? x.lazadaUrl : "",
    };
  });
}
