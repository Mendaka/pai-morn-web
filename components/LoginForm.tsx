"use client";

import { useEffect, useState } from "react";
import BrandName from "@/components/BrandName";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { ArrowLeft, Eye, EyeOff, Heart, ListMusic, Loader2, Lock, Mail, Music2, UserRound } from "lucide-react";
import { useAuth } from "@/components/AuthProvider";
import { useT } from "@/components/LanguageProvider";

type Mode = "login" | "register" | "forgot";

// Only ever send people back to a path on this site — never an absolute or
// protocol-relative URL smuggled in through ?next=.
function safeNext(raw: string | null): string {
  return raw && raw.startsWith("/") && !raw.startsWith("//") ? raw : "/";
}

export default function LoginForm() {
  const { status, signIn, register, resetPassword } = useAuth();
  const { t } = useT();
  const router = useRouter();
  const next = safeNext(useSearchParams().get("next"));

  const [mode, setMode] = useState<Mode>("login");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [displayName, setDisplayName] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  // Already signed in (or just finished signing in / registering). Waits for
  // `busy` so a new account's profile doc is fully written before we leave.
  useEffect(() => {
    if (status === "signedIn" && !busy) router.replace(next);
  }, [status, busy, next, router]);

  const switchMode = (m: Mode) => {
    setMode(m);
    setError(null);
    setNotice(null);
  };

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setNotice(null);

    if (!email.trim()) return setError(t("pleaseFillAllFields"));
    if (mode !== "forgot" && !password) return setError(t("pleaseFillAllFields"));
    if (mode === "register") {
      if (password !== confirm) return setError(t("passwordsDontMatch"));
    }

    setBusy(true);
    const result =
      mode === "login"
        ? await signIn(email, password)
        : mode === "register"
          ? await register(email, password, displayName)
          : await resetPassword(email);
    setBusy(false);

    if (result) return setError(t(result));
    if (mode === "forgot") setNotice(t("resetEmailSentMessage"));
    // login/register success: the effect above redirects once auth state flips.
  }

  const copy = {
    login: { title: t("welcomeBack"), subtitle: t("welcomeBackSubtitle"), cta: t("login") },
    register: { title: t("createAccountTitle"), subtitle: t("createAccountSubtitle"), cta: t("register") },
    forgot: { title: t("resetPasswordTitle"), subtitle: t("resetPasswordInstructions"), cta: t("sendResetLink") },
  }[mode];

  return (
    <div className="mx-auto grid w-full max-w-5xl overflow-hidden rounded-[2rem] border border-black/5 bg-white shadow-[0_30px_80px_-30px_rgba(37,99,235,0.35)] lg:grid-cols-[1fr_1.1fr]">
      <aside className="relative hidden overflow-hidden bg-neutral-950 p-10 text-white lg:block">
        <div className="pointer-events-none absolute -left-20 -top-24 h-80 w-80 rounded-full bg-indigo-500/40 blur-3xl" />
        <div className="pointer-events-none absolute -bottom-32 -right-10 h-96 w-96 rounded-full bg-sky-500/30 blur-3xl" />
        <div className="relative flex h-full flex-col">
          <Link href="/" className="text-4xl leading-none">
            <BrandName />
          </Link>
          <h2 className="mt-14 text-3xl font-extrabold leading-tight tracking-tight">
            {t("authTaglineLine1")}
            <br />
            <span className="bg-gradient-to-r from-sky-300 to-fuchsia-300 bg-clip-text text-transparent">{t("authTaglineLine2")}</span>
          </h2>
          <ul className="mt-10 space-y-5 text-[15px] text-white/80">
            {[
              [Music2, t("authPerkSubmit")],
              [Heart, t("authPerkFavorites")],
              [ListMusic, t("authPerkSetlists")],
            ].map(([Icon, text]) => {
              const I = Icon as typeof Music2;
              return (
                <li key={text as string} className="flex items-start gap-3.5">
                  <span className="mt-0.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-white/10 backdrop-blur">
                    <I size={18} />
                  </span>
                  <span className="pt-1.5">{text as string}</span>
                </li>
              );
            })}
          </ul>
        </div>
      </aside>

      <section className="p-6 sm:p-10">
        {mode === "forgot" && (
          <button
            type="button"
            onClick={() => switchMode("login")}
            className="mb-4 flex items-center gap-1.5 text-sm font-medium text-neutral-500 hover:text-black"
          >
            <ArrowLeft size={16} /> {t("backToLogin")}
          </button>
        )}
        <h1 className="text-3xl font-extrabold tracking-tight">{copy.title}</h1>
        <p className="mt-2 text-neutral-500">{copy.subtitle}</p>

        <form onSubmit={onSubmit} noValidate className="mt-8 space-y-4">
          {mode === "register" && (
            <Field icon={UserRound} label={t("displayName")}>
              <input
                value={displayName}
                onChange={(e) => setDisplayName(e.target.value)}
                autoComplete="nickname"
                maxLength={60}
                placeholder={t("displayNameOptionalPlaceholder")}
                className="field-input"
              />
            </Field>
          )}
          <Field icon={Mail} label={t("email")}>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              autoComplete="email"
              placeholder={t("emailPlaceholder")}
              className="field-input"
            />
          </Field>
          {mode !== "forgot" && (
            <Field icon={Lock} label={t("password")}>
              <input
                type={showPassword ? "text" : "password"}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                autoComplete={mode === "login" ? "current-password" : "new-password"}
                placeholder={mode === "register" ? t("newPasswordPlaceholder") : t("passwordPlaceholder")}
                className="field-input pr-12"
              />
              <button
                type="button"
                onClick={() => setShowPassword((s) => !s)}
                aria-label={showPassword ? t("hidePassword") : t("showPassword")}
                className="absolute right-3 top-1/2 flex h-8 w-8 -translate-y-1/2 items-center justify-center rounded-full text-neutral-400 hover:bg-black/5 hover:text-neutral-700"
              >
                {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
              </button>
            </Field>
          )}
          {mode === "register" && (
            <Field icon={Lock} label={t("confirmPassword")}>
              <input
                type={showPassword ? "text" : "password"}
                value={confirm}
                onChange={(e) => setConfirm(e.target.value)}
                autoComplete="new-password"
                placeholder={t("confirmPasswordPlaceholder")}
                className="field-input"
              />
            </Field>
          )}

          {mode === "login" && (
            <div className="text-right">
              <button
                type="button"
                onClick={() => switchMode("forgot")}
                className="text-sm font-medium text-blue-600 hover:underline"
              >
                {t("forgotPassword")}
              </button>
            </div>
          )}

          {error && (
            <p role="alert" className="rounded-xl bg-red-50 px-4 py-3 text-sm font-medium text-red-700">
              {error}
            </p>
          )}
          {notice && (
            <p role="status" className="rounded-xl bg-emerald-50 px-4 py-3 text-sm font-medium text-emerald-700">
              {notice}
            </p>
          )}

          <button
            type="submit"
            disabled={busy}
            className="flex h-12 w-full items-center justify-center gap-2 rounded-2xl bg-black text-[15px] font-bold text-white shadow-lg transition hover:scale-[1.01] disabled:opacity-60"
          >
            {busy && <Loader2 size={18} className="animate-spin" />}
            {copy.cta}
          </button>
        </form>

        {mode !== "forgot" && (
          <p className="mt-6 text-center text-sm">
            <button
              type="button"
              onClick={() => switchMode(mode === "login" ? "register" : "login")}
              className="font-semibold text-blue-600 hover:underline"
            >
              {mode === "login" ? t("dontHaveAccount") : t("alreadyHaveAccount")}
            </button>
          </p>
        )}
      </section>
    </div>
  );
}

function Field({
  icon: Icon,
  label,
  children,
}: {
  icon: typeof Mail;
  label: string;
  children: React.ReactNode;
}) {
  return (
    <label className="block">
      <span className="mb-1.5 block text-sm font-semibold text-neutral-700">{label}</span>
      <span className="relative block">
        <Icon size={18} className="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-neutral-400" />
        {children}
      </span>
    </label>
  );
}
