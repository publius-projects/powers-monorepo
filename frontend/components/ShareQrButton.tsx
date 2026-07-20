'use client'

import { useEffect, useState } from 'react';
import { usePathname } from 'next/navigation';
import QRCode from 'react-qr-code';
import { QrCodeIcon, XMarkIcon, ClipboardDocumentIcon, CheckIcon } from '@heroicons/react/24/outline';
import { ForumModal } from '@/components/ForumModal';

interface ShareQrButtonProps {
  /**
   * 'icon' - a bordered icon button for the desktop nav bar (default).
   * 'menu' - a full-width row with icon + label for the mobile slide-out menu.
   */
  variant?: 'icon' | 'menu';
}

/**
 * ShareQrButton - Shows a QR code of the current page URL in a popup, with the
 * full URL written out underneath and a "copy link" button. The URL is built
 * client-side (window.location.origin + pathname) so it reflects the exact page
 * the user is on.
 */
export function ShareQrButton({ variant = 'icon' }: ShareQrButtonProps) {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  const [url, setUrl] = useState('');
  const [copied, setCopied] = useState(false);

  // Resolve the full URL client-side whenever the modal opens or the path
  // changes. window is undefined during SSR, so this must stay in an effect.
  useEffect(() => {
    if (open && typeof window !== 'undefined') {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setUrl(`${window.location.origin}${pathname}`);
    }
  }, [open, pathname]);

  const copyUrl = () => {
    if (!url) return;
    navigator.clipboard.writeText(url);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <>
      {variant === 'icon' ? (
        <button
          onClick={() => setOpen(true)}
          className="p-2 border border-border hover:bg-foreground hover:text-background transition-colors cursor-pointer"
          aria-label="Share this page"
        >
          <QrCodeIcon className="h-4 w-4" />
        </button>
      ) : (
        <button
          onClick={() => setOpen(true)}
          className="flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground font-mono transition-colors cursor-pointer"
          aria-label="Share this page"
        >
          <QrCodeIcon className="h-4 w-4" />
          <span>Share this page</span>
        </button>
      )}

      <ForumModal open={open} onOpenChange={setOpen} className="font-mono max-w-sm">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-sm text-foreground uppercase tracking-wider">Share this page</h3>
          <button
            onClick={() => setOpen(false)}
            className="p-1 text-muted-foreground hover:text-foreground transition-colors cursor-pointer"
            aria-label="Close"
          >
            <XMarkIcon className="h-5 w-5" />
          </button>
        </div>

        {/* QR code on a fixed white panel so it scans in both light and dark themes */}
        <div className="flex items-center justify-center">
          <div className="bg-white p-4">
            {url ? (
              <QRCode value={url} size={192} />
            ) : (
              <div className="h-48 w-48" />
            )}
          </div>
        </div>

        {/* Full URL written out underneath */}
        <div className="mt-4 border border-border p-3">
          <p className="font-mono text-xs break-all text-muted-foreground">{url}</p>
        </div>

        <button
          onClick={copyUrl}
          className="mt-3 w-full flex items-center justify-center gap-2 px-3 py-2 border border-border cursor-pointer hover:bg-foreground hover:text-background transition-all text-xs uppercase font-mono leading-none"
        >
          {copied ? (
            <>
              <CheckIcon className="h-4 w-4 text-green-500" />
              <span className="leading-none">Copied</span>
            </>
          ) : (
            <>
              <ClipboardDocumentIcon className="h-4 w-4" />
              <span className="leading-none">Copy link</span>
            </>
          )}
        </button>
      </ForumModal>
    </>
  );
}
