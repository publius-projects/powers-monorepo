"use client";

import { useTheme } from "next-themes";
import { useEffect } from "react";

export function ThemeColorMeta() {
  const { resolvedTheme } = useTheme();

  useEffect(() => {
    // Remove any theme-color meta tags this component previously created so we
    // never leave duplicates. (The viewport export intentionally does NOT emit a
    // theme-color meta — see app/layout.tsx — so these are only our own nodes,
    // never React-managed ones.)
    document
      .querySelectorAll('meta[name="theme-color"]')
      .forEach((m) => m.remove());

    // Create new meta tag with the appropriate color
    const meta = document.createElement("meta");
    meta.name = "theme-color";
    meta.content = resolvedTheme === "dark" ? "#09090b" : "#ffffff";
    document.head.appendChild(meta);

    return () => {
      meta.remove();
    }; 
  }, [resolvedTheme]);

  return null;
}