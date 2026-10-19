import type { MetadataRoute } from "next";

// Same web-app manifest the Flutter build shipped, so the phone home-screen
// install keeps its name, colours and icons.
export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Paimorn",
    short_name: "Paimorn",
    description: "Browse, submit, and read song lyrics and chords.",
    start_url: "/",
    display: "standalone",
    background_color: "#FFFFFF",
    theme_color: "#000000",
    orientation: "portrait-primary",
    prefer_related_applications: false,
    icons: [
      { src: "/icons/Icon-192.png", sizes: "192x192", type: "image/png" },
      { src: "/icons/Icon-512.png", sizes: "512x512", type: "image/png" },
      { src: "/icons/Icon-maskable-192.png", sizes: "192x192", type: "image/png", purpose: "maskable" },
      { src: "/icons/Icon-maskable-512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
    ],
  };
}
