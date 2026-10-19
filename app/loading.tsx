// Shown the instant a menu link is clicked, while the next page is being built on
// the server. Pages that read live data (Home, SongBook, songs, artists) take
// ~0.4-0.9s to come back, and without this the old page just sat there with no sign
// that anything happened, which felt like the menu was hanging. Next also prefetches
// this shell, so the switch itself is immediate.
export default function Loading() {
  return (
    <div role="status" aria-live="polite" aria-label="Loading">
      <div className="fixed inset-x-0 top-16 z-50 h-[3px] overflow-hidden">
        <div className="load-bar h-full w-2/5 rounded-full bg-gradient-to-r from-indigo-500 via-blue-500 to-sky-400" />
      </div>
      <div className="mx-auto w-full max-w-5xl px-4 py-10 sm:px-6">
        <div className="h-9 w-56 animate-pulse rounded-xl bg-black/10" />
        <div className="mt-3 h-4 w-80 max-w-full animate-pulse rounded-lg bg-black/5" />
        <div className="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {Array.from({ length: 6 }, (_, i) => (
            <div key={i} className="h-40 animate-pulse rounded-3xl bg-black/5" />
          ))}
        </div>
      </div>
    </div>
  );
}
