import React from "react";
import type { Metadata, Viewport } from "next";
import { Providers } from "../context/Providers"
import "./globals.css";
import "reactflow/dist/style.css";
import { ThemeProvider } from "next-themes";
import { ThemeColorMeta } from "../components/ThemeColorMeta";

export const metadata: Metadata = {
  title: "Powers Protocol",
  description: "UI to interact with organisations using the Powers Protocol.",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
  viewportFit: "cover",
  // NOTE: theme-color is managed dynamically by <ThemeColorMeta/> so it can
  // follow next-themes' resolvedTheme. Do NOT also declare `themeColor` here:
  // that makes React/Next render its own theme-color meta nodes, which
  // ThemeColorMeta then removes from the DOM, causing a "removeChild of null"
  // crash in React's commit phase on the next navigation.
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  
  return (
    <html suppressHydrationWarning lang="en">
      <head />
     
      <body className="h-screen w-screen relative bg-background overflow-hidden">
        <ThemeProvider attribute="class">
          <ThemeColorMeta />
          <Providers>
            {children}
          </Providers>
        </ThemeProvider>
      </body>
    </html>
  );
}
