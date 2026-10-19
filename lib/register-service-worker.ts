// Registers public/sw.js — see that file for what it does and why.
//
// This is a plain function, called once from Navbar.tsx (rendered on every
// page), rather than a bare side-effect import from the root layout. A bare
// `import "./this-file"` in app/layout.tsx (a Server Component) looked right
// but silently did nothing: nothing on the client side ever actually used a
// binding from that module, so Next's client bundler never generated a real
// `require()` for it — the module's source ended up physically inside a
// shared chunk (confirmed with grep) but its top-level code never ran
// (confirmed with a temporary console.log that never printed). lib/pwa-
// install.ts's own bare import in that same file looks identical but its
// side effect DOES run — only because a separate client component
// (InstallBanner) imports and calls its `useInstallState` hook, which is
// what actually wires it into the client module graph. Moral: a "use
// client" module with zero imported exports can be dead code even though
// its text is present in a bundle — always trigger it from something real.
let attempted = false;

export function registerServiceWorker(): void {
  if (attempted || typeof window === "undefined" || !("serviceWorker" in navigator)) return;
  attempted = true;
  const register = () => {
    navigator.serviceWorker.register("/sw.js").catch(() => {
      // No caching this session; the site still works, just without the
      // resume-from-background resilience — not worth surfacing to the user.
    });
  };
  if (document.readyState === "complete") register();
  else window.addEventListener("load", register);
}
