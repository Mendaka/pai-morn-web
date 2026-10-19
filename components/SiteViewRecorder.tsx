"use client";

import { useEffect } from "react";
import { recordSiteViewOnce } from "@/lib/record-views";

// Counts one site visit per real page load (mounted once in the root layout).
export default function SiteViewRecorder() {
  useEffect(() => {
    recordSiteViewOnce();
  }, []);
  return null;
}
