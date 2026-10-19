"use client";

import { useEffect, useState } from "react";
import Image from "next/image";
import { collection, deleteDoc, doc, onSnapshot, orderBy, query, serverTimestamp, setDoc, updateDoc } from "firebase/firestore";
import { Loader2, Pencil, Plus, ShoppingBag, Trash2, X } from "lucide-react";
import { useAuth } from "@/components/AuthProvider";
import { useT } from "@/components/LanguageProvider";
import { db } from "@/lib/firebase/client";
import { resizeImageForUpload } from "@/lib/image-resize";

type Row = { id: string; name: string; nameShn: string; price: number; imageUrl: string; lazadaUrl: string };

// Same upload shape as PlaylistEditorView's uploadCover: resize in the
// browser, post to the admin-checked uploadShopProductImage Cloud Function
// (Admin SDK write — see functions/index.js and storage.rules).
async function uploadImage(productId: string, file: File, idToken: string): Promise<void> {
  const blob = await resizeImageForUpload(file, 900);
  const base64 = await new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result).split(",")[1] ?? "");
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(blob);
  });
  const res = await fetch(`${process.env.NEXT_PUBLIC_API_BASE ?? ""}/api/upload-shop-product-image`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${idToken}` },
    body: JSON.stringify({ productId, imageBase64: base64 }),
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.error || `Upload failed (${res.status})`);
  }
}

export default function ShopAdminView() {
  const { t } = useT();
  const { user } = useAuth();
  const [rows, setRows] = useState<Row[] | null>(null);
  const [dialogTarget, setDialogTarget] = useState<"new" | Row | null>(null);

  useEffect(() => {
    return onSnapshot(query(collection(db, "shopProducts"), orderBy("createdAt", "desc")), (snap) =>
      setRows(
        snap.docs.map((d) => {
          const x = d.data();
          return {
            id: d.id,
            name: typeof x.name === "string" ? x.name : "",
            nameShn: typeof x.nameShn === "string" ? x.nameShn : "",
            price: typeof x.price === "number" ? x.price : 0,
            imageUrl: typeof x.imageUrl === "string" ? x.imageUrl : "",
            lazadaUrl: typeof x.lazadaUrl === "string" ? x.lazadaUrl : "",
          };
        }),
      ),
    );
  }, []);

  async function remove(id: string) {
    if (!confirm(t("deleteProductConfirm"))) return;
    await deleteDoc(doc(db, "shopProducts", id));
  }

  return (
    <div>
      <div className="flex items-center justify-between gap-3">
        <h1 className="text-2xl font-extrabold tracking-tight">{t("adminShopLabel")}</h1>
        <button
          type="button"
          onClick={() => setDialogTarget("new")}
          className="flex h-11 shrink-0 items-center gap-2 rounded-full bg-black px-5 text-sm font-semibold text-white transition hover:scale-[1.02]"
        >
          <Plus size={16} /> {t("addProductButton")}
        </button>
      </div>

      <div className="mt-6 space-y-2">
        {rows === null ? (
          [0, 1].map((i) => <div key={i} className="h-20 animate-pulse rounded-2xl bg-black/5" />)
        ) : rows.length === 0 ? (
          <p className="rounded-3xl border border-dashed border-black/10 px-6 py-10 text-center text-neutral-500">{t("noProductsYet")}</p>
        ) : (
          rows.map((r) => (
            <div key={r.id} className="flex items-center gap-3 rounded-2xl border border-black/5 bg-white p-3 pr-4 shadow-[0_2px_16px_-8px_rgba(0,0,0,0.15)]">
              {r.imageUrl ? (
                <div className="relative h-14 w-14 shrink-0 overflow-hidden rounded-xl bg-neutral-100">
                  <Image src={r.imageUrl} alt="" fill sizes="56px" className="object-cover" />
                </div>
              ) : (
                <span className="flex h-14 w-14 shrink-0 items-center justify-center rounded-xl bg-neutral-100 text-neutral-400">
                  <ShoppingBag size={22} />
                </span>
              )}
              <span className="min-w-0 flex-1">
                <span className="line-clamp-2 font-semibold leading-snug text-neutral-900">{r.name}</span>
                <span className="mt-0.5 block text-sm text-neutral-500">฿{r.price.toLocaleString()}</span>
              </span>
              <button
                type="button"
                onClick={() => setDialogTarget(r)}
                aria-label={t("editButton")}
                className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-neutral-500 transition hover:bg-neutral-100 hover:text-neutral-900"
              >
                <Pencil size={16} />
              </button>
              <button
                type="button"
                onClick={() => remove(r.id)}
                aria-label={t("deleteButton")}
                className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-neutral-500 transition hover:bg-red-50 hover:text-red-600"
              >
                <Trash2 size={16} />
              </button>
            </div>
          ))
        )}
      </div>

      {dialogTarget && user && (
        <ProductDialog
          product={dialogTarget === "new" ? null : dialogTarget}
          idToken={user.getIdToken.bind(user)}
          onClose={() => setDialogTarget(null)}
        />
      )}
    </div>
  );
}

function ProductDialog({ product, idToken, onClose }: { product: Row | null; idToken: () => Promise<string>; onClose: () => void }) {
  const { t } = useT();
  const [name, setName] = useState(product?.name ?? "");
  const [nameShn, setNameShn] = useState(product?.nameShn ?? "");
  const [price, setPrice] = useState(product ? String(product.price) : "");
  const [lazadaUrl, setLazadaUrl] = useState(product?.lazadaUrl ?? "");
  const [file, setFile] = useState<File | null>(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Strips anything that isn't a digit or decimal point — thousands
  // separators ("2,490") and a typed "฿" (now shown as a fixed prefix
  // instead, but still stripped here as a second line of defense) both
  // broke Number() into NaN before, which silently disabled Save with no
  // visible reason why (found 2026-10-16).
  const priceNumber = Number(price.replace(/[^\d.]/g, "").trim());

  async function save() {
    setError(null);
    // Editing an existing product keeps its current image when no new
    // file is chosen — only a brand-new product requires one up front.
    if (!name.trim() || !price.trim() || !lazadaUrl.trim() || (!product && !file)) {
      setError(t("productFillRequiredFieldsMessage"));
      return;
    }
    if (!Number.isFinite(priceNumber) || priceNumber < 0) {
      setError(t("productPriceInvalidMessage"));
      return;
    }
    setSaving(true);
    try {
      const id = product?.id ?? doc(collection(db, "shopProducts")).id;
      const fields = {
        name: name.trim(),
        nameShn: nameShn.trim(),
        price: priceNumber,
        lazadaUrl: lazadaUrl.trim(),
      };
      if (product) {
        await updateDoc(doc(db, "shopProducts", id), fields);
      } else {
        await setDoc(doc(db, "shopProducts", id), { ...fields, imageUrl: "", createdAt: serverTimestamp() });
      }
      if (file) await uploadImage(id, file, await idToken());
      onClose();
    } catch (err) {
      setError(err instanceof Error && err.message ? err.message : t("adminPhotoFailed"));
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="no-print fixed inset-0 z-[70] flex items-center justify-center bg-black/40 p-4 backdrop-blur-sm" onClick={onClose}>
      <div role="dialog" aria-modal="true" aria-label={t(product ? "editProductButton" : "addProductButton")} onClick={(e) => e.stopPropagation()} className="max-h-[85vh] w-full max-w-sm overflow-y-auto rounded-3xl bg-white p-6 text-neutral-900 shadow-2xl">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-bold">{t(product ? "editProductButton" : "addProductButton")}</h2>
          <button type="button" onClick={onClose} aria-label={t("closeLabel")} className="flex h-8 w-8 items-center justify-center rounded-full text-neutral-500 hover:bg-neutral-100">
            <X size={16} />
          </button>
        </div>

        <div className="mt-4 space-y-3">
          <label className="block">
            <span className="mb-1.5 block text-sm font-medium text-neutral-700">{t("productNameLabel")}</span>
            <input value={name} onChange={(e) => setName(e.target.value)} className="plain-input" />
          </label>
          <label className="block">
            <span className="mb-1.5 block text-sm font-medium text-neutral-700">{t("productNameShnLabel")}</span>
            <input value={nameShn} onChange={(e) => setNameShn(e.target.value)} className="plain-input" />
          </label>
          <label className="block">
            <span className="mb-1.5 block text-sm font-medium text-neutral-700">{t("productPriceLabel")}</span>
            <span className="relative block">
              <span className="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-neutral-400">฿</span>
              <input value={price} onChange={(e) => setPrice(e.target.value)} inputMode="decimal" placeholder="2,490" className="plain-input pl-8" />
            </span>
          </label>
          <label className="block">
            <span className="mb-1.5 block text-sm font-medium text-neutral-700">{t("productLazadaLinkLabel")}</span>
            <input value={lazadaUrl} onChange={(e) => setLazadaUrl(e.target.value)} inputMode="url" placeholder="https://s.lazada.co.th/..." className="plain-input" />
          </label>
          <label className="block">
            <span className="mb-1.5 block text-sm font-medium text-neutral-700">{t("productImageLabel")}</span>
            {product?.imageUrl && !file && (
              <div className="relative mb-2 h-20 w-20 overflow-hidden rounded-xl bg-neutral-100">
                <Image src={product.imageUrl} alt="" fill sizes="80px" className="object-cover" />
              </div>
            )}
            <input type="file" accept="image/*" onChange={(e) => setFile(e.target.files?.[0] ?? null)} className="block w-full text-sm" />
          </label>
        </div>

        {error && (
          <p role="alert" className="mt-3 rounded-xl bg-red-50 px-4 py-2.5 text-sm text-red-700">
            {error}
          </p>
        )}

        <div className="mt-5 flex justify-end gap-2">
          <button type="button" onClick={onClose} className="h-10 rounded-full px-5 text-sm font-medium hover:bg-neutral-100">
            {t("cancelButton")}
          </button>
          <button type="button" onClick={save} disabled={saving} className="flex h-10 items-center gap-2 rounded-full bg-black px-5 text-sm font-semibold text-white hover:bg-neutral-800 disabled:opacity-60">
            {saving && <Loader2 size={15} className="animate-spin" />}
            {t("saveButton")}
          </button>
        </div>
      </div>
    </div>
  );
}
