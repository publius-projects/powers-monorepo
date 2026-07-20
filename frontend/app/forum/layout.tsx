'use client'

import React from "react";
import { useState, useEffect, useRef } from 'react';
import { useRouter, usePathname, useParams } from 'next/navigation';
import Link from 'next/link';
import { usePowersStore, setStatus, setError, useSavedProtocolsStore, setAction, useActionStore } from "@/context/store";
import { usePrivy, useWallets } from "@privy-io/react-auth";
import { useEffectiveAddress } from "@/hooks/useEffectiveAddress";

import { NavigationDropdownMenu } from './NavigationDropdownMenu';
import { ThemeToggle } from '@/components/ThemeToggle';
import { ShareQrButton } from '@/components/ShareQrButton';
import { ChevronRightIcon } from "@heroicons/react/24/solid";
import { useAddressDisplay } from "@/hooks/useAddressDisplay";

import { ArrowRightStartOnRectangleIcon, CheckCircleIcon, ArrowLeftIcon, Bars3Icon, XMarkIcon } from '@heroicons/react/24/outline';
import { usePowersLive } from "@/hooks/usePowersLive";
import { useActionStateSync } from "@/hooks/useActionStateSync";
import { usePowers } from "@/hooks/usePowers";
import { useConnection, useSwitchChain } from "wagmi";
import { useXmtpClient } from "@/hooks/useXmtpClient";

import { parseChainId } from "@/utils/parsers";

export default function ForumLayout({ children }: Readonly<{ children: React.ReactNode }>) {
    const router = useRouter(); 
    const pathname = usePathname();
    const powers = usePowersStore();
    const { savedProtocols, loadSavedProtocols, addProtocol } = useSavedProtocolsStore();
    const { wallets, ready: walletsReady } = useWallets();
    const {ready, authenticated, login, logout, connectWallet} = usePrivy();
    const { powers: powersAddress } = useParams<{ chainId: string, powers: string }>()
    const { chainId } = useParams<{ chainId: string }>()
    usePowersLive(
      powersAddress as `0x${string}` | undefined,
      chainId ? parseChainId(chainId) : undefined
    );
    useActionStateSync(
      powersAddress as `0x${string}` | undefined,
      chainId ? parseChainId(chainId) : undefined
    );
    const { fetchPowers } = usePowers();
    const fetchingPowersRef = useRef(false);
    const switchChain = useSwitchChain();
    const { chain } = useConnection();
    const action = useActionStore();
    const effectiveAddress = useEffectiveAddress();
    const { displayName, isLoading } = useAddressDisplay(effectiveAddress);
    const { client, isConnected: xmtpConnected, initializeClient, disconnect: disconnectXmtp} = useXmtpClient();
    const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

    console.log("layout being triggered")

    const triggerName =
      pathname.includes('/profile') ? "Profile" :
      !chainId ? "Navigation" :
      "Main"

    const powersBasePath = chainId && powersAddress ? `/forum/${chainId}/${powersAddress}` : null
    const isOnSubPage = powersBasePath !== null && pathname !== powersBasePath

    // Switch chain when selected chain changes
    useEffect(() => {
      if (chainId && chain?.id !== Number(chainId)) {
        switchChain.mutate({ chainId: Number(chainId) });
      }
    }, [ chain?.id ]);

    // Load powers instance if not loaded yet. Lives here (not in a specific
    // sub-page) so every route under /forum/[chainId]/[powers]/* - including
    // a direct/refreshed navigation to e.g. /new - gets the data. Dependency
    // array is route params only (not `powers` or `fetchPowers`) so a
    // successful fetch's new `powers` object reference doesn't re-trigger
    // this effect and loop; a ref guards against overlapping calls.
    useEffect(() => {
      if (!powersAddress || !chainId) return
      if (powers.contractAddress === undefined || powers.contractAddress === '0x0' || powers.contractAddress !== powersAddress) {
        if (fetchingPowersRef.current) return
        fetchingPowersRef.current = true
        fetchPowers(powersAddress as `0x${string}`, parseChainId(chainId)).finally(() => {
          fetchingPowersRef.current = false
        })
      }
    }, [powersAddress, chainId]);
  
    // reset status and error when pathname changes
    useEffect(() => {
      setError({error: null})
      setStatus({status: "idle"})
      setAction({...action, upToDate: false})
    }, [pathname])

    useEffect(() => {
      loadSavedProtocols()
    }, [loadSavedProtocols])

    // Auto-save current Powers instance if not already saved
    useEffect(() => {
      if (powers && powers.contractAddress && powers.contractAddress !== '0x0' && savedProtocols.length > 0) {
        const isAlreadySaved = savedProtocols.some(
          p => p.contractAddress.toLowerCase() === powers.contractAddress.toLowerCase()
        )
        
        if (!isAlreadySaved) {
          console.log('Auto-saving protocol to localStorage:', powers.contractAddress)
          addProtocol(powers)
        }
      }
    }, [powers, powers.contractAddress, savedProtocols, addProtocol])
 
  return (  
    <div className="h-screen w-screen flex flex-col bg-background scanlines overflow-hidden">
      <header className="hidden min-[700px]:flex w-full flex-col items-center border-b border-border px-3 sm:px-4 py-4 flex-shrink-0">
        <div className="w-full flex flex-nowrap items-center justify-between max-w-4xl gap-2 sm:gap-3">
          <div className="flex items-center gap-2 sm:gap-4">
            <Link href="/forum" className="font-mono text-base sm:text-lg text-foreground tracking-wider truncate hover:text-foreground/80 transition-colors">{
                powers.name ? powers.name : "Forum"
            }
            </Link>
          </div> 
          <div className="flex items-center gap-2 sm:gap-4">
            {ready && authenticated && walletsReady && wallets[0] &&
            <>
                <button
                onClick={() => router.push('/forum/profile')}
                className="text-xs text-muted-foreground hover:text-foreground font-mono transition-colors cursor-pointer">
                  {isLoading ? 'Loading...' : displayName}
                </button>
                <button
                onClick={() => { logout(); disconnectXmtp(); }}
                className="flex items-center gap-2 text-xs text-muted-foreground hover:text-foreground transition-colors cursor-pointer">

                  <ArrowRightStartOnRectangleIcon className="h-3 w-3" />
                  <span className="hidden sm:inline">DISCONNECT</span>
                </button>
                <span className="text-muted-foreground">|</span>
                <div className="flex items-center gap-2 font-mono text-xs">
                  {/* <CheckCircleIcon className="h-2 w-2 fill-primary text-primary" /> */}
                  <span className="text-foreground">CONNECTED</span>
                </div> 
              </>
            }
            {ready && !authenticated &&
            <button
              onClick={ login }
              className="flex items-center gap-2 font-mono text-xs text-muted-foreground hover:text-foreground hover:underline underline-offset-4 transition-all duration-200 cursor-pointer">

                <CheckCircleIcon className="h-2 w-2 fill-muted-foreground text-muted-foreground" />
                <span className="text-muted-foreground">NOT CONNECTED</span>
              </button>
            }
            {ready && authenticated && walletsReady && !wallets[0] &&
            <button
              onClick={ connectWallet }
              className="flex items-center gap-2 font-mono text-xs text-muted-foreground hover:text-foreground hover:underline underline-offset-4 transition-all duration-200 cursor-pointer">

                <CheckCircleIcon className="h-2 w-2 fill-muted-foreground text-muted-foreground" />
                <span className="text-muted-foreground">NOT CONNECTED</span>
              </button>
            }
            <ShareQrButton />
            <ThemeToggle />
          </div>
        </div>
      </header>

      <div className="border-b border-border px-4 py-1.5 bg-muted/5 flex-shrink-0">
        <div className="max-w-4xl mx-auto flex items-center justify-between gap-2">
          <div className="flex items-center gap-2">
      
          { isOnSubPage ?
              <button
                onClick={() => router.push(`/forum/${chainId}/${powersAddress}`)}
                className="flex items-center justify-center gap-2 px-3 py-2 border border-border border-foreground cursor-pointer hover:bg-foreground hover:text-background transition-all text-xs uppercase font-mono leading-none">
                <ArrowLeftIcon className="h-3 w-3" />
                <span className="leading-none">BACK TO ORGANISATION</span>
              </button>
              :
              <>
              <div className="w-3 h-3">
                <ChevronRightIcon />
              </div> 
              <NavigationDropdownMenu savedProtocols={savedProtocols} trigger={
                triggerName === "Main" && powers.name ? (
                  <>
                    <span className="sm:hidden">{powers.name}</span>
                    <span className="hidden sm:inline">Main</span>
                  </>
                ) : (
                  <span>{triggerName}</span>
                )
              } />
              </>
          }
          </div>
          
          {/* Hamburger button - only visible on mobile */}
          <div className="flex items-center gap-1 min-[700px]:hidden">
            <button
              onClick={() => setMobileMenuOpen(true)}
              className="p-2 text-foreground hover:text-foreground/80 transition-colors cursor-pointer"
              aria-label="Open menu"
            >
              <Bars3Icon className="h-6 w-6" />
            </button>
          </div>
        </div>
      </div>
      
      <main className="flex-1 overflow-y-auto min-h-0 pb-24">
        {children}
        {/* <Footer /> */}
      </main>

      

      {/* Mobile Slide-out Menu */}
      <div 
        className={`fixed inset-0 z-50 min-[700px]:hidden transition-transform duration-300 ease-in-out ${
          mobileMenuOpen ? 'translate-x-0' : 'translate-x-full'
        }`}
      >
        <div className="h-full w-full bg-background flex flex-col">
          {/* Header with close button */}
          <div className="flex items-center justify-between px-4 py-4 border-b border-border">
            <span className="font-mono text-lg text-foreground tracking-wider">
              {powers.name ? powers.name : "FORUM"}
            </span>
            <button
              onClick={() => setMobileMenuOpen(false)}
              className="p-2 text-foreground hover:text-foreground/80 transition-colors cursor-pointer"
              aria-label="Close menu"
            >
              <XMarkIcon className="h-6 w-6" />
            </button>
          </div>
          
          {/* Menu content */}
          <div className="flex-1 overflow-y-auto p-4 space-y-6">
            {/* Wallet Connection */}
            <div className="space-y-3">
              <span className="text-xs text-muted-foreground font-mono uppercase">Wallet</span>
              {ready && authenticated && walletsReady && wallets[0] ? (
                <div className="space-y-3">
                  <button
                    onClick={() => {
                      router.push('/profile');
                      setMobileMenuOpen(false);
                    }}
                    className="w-full text-left text-sm text-foreground font-mono py-2 hover:text-foreground/80 transition-colors cursor-pointer"
                  >
                    {isLoading ? 'Loading...' : displayName}
                  </button>
                  <div className="flex items-center gap-2 font-mono text-xs">
                    <CheckCircleIcon className="h-3 w-3 text-green-500" />
                    <span className="text-foreground">CONNECTED</span>
                  </div>
                  <button
                    onClick={() => {
                      logout();
                      disconnectXmtp();
                      setMobileMenuOpen(false);
                    }}
                    className="flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground transition-colors cursor-pointer"
                  >
                    <ArrowRightStartOnRectangleIcon className="h-4 w-4" />
                    <span>DISCONNECT</span>
                  </button>
                </div>
              ) : ready && !authenticated ? (
                <button
                  onClick={() => {
                    login();
                    setMobileMenuOpen(false);
                  }}
                  className="flex items-center gap-2 font-mono text-sm text-muted-foreground hover:text-foreground transition-colors cursor-pointer"
                >
                  <CheckCircleIcon className="h-3 w-3" />
                  <span>NOT CONNECTED - TAP TO LOGIN</span>
                </button>
              ) : ready && authenticated && walletsReady && !wallets[0] ? (
                <button
                  onClick={() => {
                    connectWallet();
                    setMobileMenuOpen(false);
                  }}
                  className="flex items-center gap-2 font-mono text-sm text-muted-foreground hover:text-foreground transition-colors cursor-pointer"
                >
                  <CheckCircleIcon className="h-3 w-3" />
                  <span>NOT CONNECTED - TAP TO CONNECT</span>
                </button>
              ) : null}
            </div>
            
            {/* Divider */}
            <div className="border-t border-border" />

            {/* Theme Toggle */}
            <div className="space-y-3">
              <span className="text-xs text-muted-foreground font-mono uppercase">Theme</span>
              <div className="flex items-center gap-2">
                <ThemeToggle />
                <span className="text-sm font-mono text-muted-foreground">Toggle theme</span>
              </div>
            </div>

            {/* Divider */}
            <div className="border-t border-border" />

            {/* Share */}
            <div className="space-y-3">
              <span className="text-xs text-muted-foreground font-mono uppercase">Share</span>
              <ShareQrButton variant="menu" />
            </div>
          </div>
        </div>
      </div>
    </div> 
    )
}
