// Shared frame for the text pages (About, Guide, Contact, Privacy, Terms):
// the same soft "aurora" backdrop as Home, a centered column, and a heading.
export default function PageShell({
  eyebrow,
  title,
  subtitle,
  children,
  size = "md",
}: {
  eyebrow?: string;
  title: React.ReactNode;
  subtitle?: React.ReactNode;
  children: React.ReactNode;
  size?: "md" | "lg";
}) {
  return (
    <div className="relative overflow-hidden">
      <div className="pointer-events-none absolute -right-24 -top-16 h-80 w-80 rounded-full bg-fuchsia-300/30 blur-3xl" />
      <div className="pointer-events-none absolute -left-28 top-72 h-72 w-72 rounded-full bg-indigo-300/30 blur-3xl" />

      <div className={`relative mx-auto w-full px-4 pb-24 pt-12 sm:px-6 sm:pt-16 ${size === "lg" ? "max-w-4xl" : "max-w-3xl"}`}>
        {eyebrow && <p className="text-sm font-semibold uppercase tracking-[0.18em] text-neutral-500">{eyebrow}</p>}
        <h1 className="mt-2 flex items-center gap-3 text-3xl font-extrabold leading-tight tracking-tight sm:text-4xl">
          <span className="h-9 w-1.5 shrink-0 rounded bg-gradient-to-b from-indigo-500 to-fuchsia-500" />
          {title}
        </h1>
        {subtitle && <p className="mt-3 text-neutral-500">{subtitle}</p>}
        <div className="mt-8">{children}</div>
      </div>
    </div>
  );
}

export const cardClass =
  "rounded-3xl border border-black/5 bg-white/90 p-6 shadow-[0_2px_24px_-8px_rgba(0,0,0,0.12)] backdrop-blur sm:p-8";
