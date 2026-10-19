import type { Metadata } from "next";
import ShopView from "@/components/ShopView";
import { getShopProducts } from "@/lib/shop";

// Without this, Next statically freezes the page at build time (the
// state Firestore happened to be in during the last `npm run build`) and
// never re-fetches — found 2026-10-16: admin's onSnapshot list showed a
// newly added product immediately, but this public page kept showing the
// pre-launch empty state. Same fix every other catalog-backed page already
// has (see app/songbook/page.tsx).
export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Shop",
  description: "A few things we recommend.",
};

export default async function ShopPage() {
  const products = await getShopProducts();
  return <ShopView products={products} />;
}
