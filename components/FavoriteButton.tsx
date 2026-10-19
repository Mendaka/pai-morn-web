"use client";

import { useEffect, useState } from "react";
import { deleteDoc, doc, onSnapshot, serverTimestamp, setDoc } from "firebase/firestore";
import { Heart } from "lucide-react";
import { useAuth } from "@/components/AuthProvider";
import { useT } from "@/components/LanguageProvider";
import { db } from "@/lib/firebase/client";

// Heart toggle. Membership is just the existence of users/{uid}/favorites/{songId}
// (see firestore.rules), so favoriting never needs write access to the song.
// Renders nothing for signed-out visitors, like the Flutter app.
export default function FavoriteButton({
  songId,
  variant = "light",
}: {
  songId: string;
  variant?: "light" | "onDark";
}) {
  const { user } = useAuth();
  const { t } = useT();
  const uid = user?.uid;
  const [favorited, setFavorited] = useState(false);
  const [pop, setPop] = useState(false);

  useEffect(() => {
    if (!uid) return;
    return onSnapshot(doc(db, "users", uid, "favorites", songId), (snap) => setFavorited(snap.exists()));
  }, [uid, songId]);

  if (!uid) return null;

  function toggle() {
    const ref = doc(db, "users", uid!, "favorites", songId);
    if (favorited) {
      deleteDoc(ref).catch(() => {});
    } else {
      setDoc(ref, { addedAt: serverTimestamp() }).catch(() => {});
      setPop(true);
      setTimeout(() => setPop(false), 400);
    }
  }

  const idle =
    variant === "onDark"
      ? "bg-white/20 text-white hover:bg-white/30 backdrop-blur"
      : "bg-neutral-100 text-neutral-600 hover:bg-neutral-200";

  return (
    <button
      type="button"
      onClick={toggle}
      aria-pressed={favorited}
      aria-label={favorited ? t("removeFromFavorites") : t("addToFavorites")}
      title={favorited ? t("removeFromFavorites") : t("addToFavorites")}
      className={`no-print flex h-10 w-10 shrink-0 items-center justify-center rounded-full transition ${
        favorited ? "bg-white text-rose-500 shadow-md" : idle
      } ${pop ? "scale-125" : "scale-100"}`}
    >
      <Heart size={19} className={favorited ? "fill-current" : ""} />
    </button>
  );
}
