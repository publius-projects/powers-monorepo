'use client';

import React from 'react';

/**
 * Build-time stand-in for '@privy-io/react-auth', swapped in via the
 * E2E_MOCK_AUTH webpack alias (see next.config.mjs). Reads test-controlled
 * state from window.__E2E_PRIVY_STATE__, set per-test via page.addInitScript
 * before navigation (see e2e/mocks/auth-fixture.ts).
 */

// The serializable wallet shape seeded into window.__E2E_PRIVY_STATE__ via
// page.addInitScript (see auth-fixture.ts). addInitScript can only carry plain
// JSON, so no methods live here — useWallets() enriches these into full
// ConnectedWallet objects client-side below.
type SerializedWallet = { address: string; walletClientType?: string };

// The enriched wallet useWallets() returns. @privy-io/wagmi's
// useSyncPrivyWallets reads getEthereumProvider(), meta.*, and walletClientType
// off every connected wallet — a bare { address } makes it throw
// "getEthereumProvider is not a function" and crashes the WagmiProvider subtree.
export type ConnectedWallet = SerializedWallet & {
  connectorType: string;
  chainId: string;
  meta: { id: string; name: string; icon: string };
  getEthereumProvider: () => Promise<StubEip1193Provider>;
};

type E2EPrivyState = {
  ready: boolean;
  authenticated: boolean;
  wallets: SerializedWallet[];
};

declare global {
  interface Window {
    __E2E_PRIVY_STATE__?: E2EPrivyState;
  }
}

const DEFAULT_STATE: E2EPrivyState = { ready: true, authenticated: false, wallets: [] };

function getState(): E2EPrivyState {
  if (typeof window === 'undefined') return DEFAULT_STATE;
  return window.__E2E_PRIVY_STATE__ ?? DEFAULT_STATE;
}

type StubEip1193Provider = {
  request: (args: { method: string }) => Promise<unknown>;
  on: () => void;
  removeListener: () => void;
};

// Minimal EIP-1193 provider so wagmi's injected() connector can be set up
// without throwing. The tests only do public reads (via the wagmi config's HTTP
// transports, not this connector), so it just needs a valid shape.
function makeStubProvider(address: string): StubEip1193Provider {
  return {
    request: async ({ method }) => {
      if (method === 'eth_chainId') return '0xaa36a7'; // sepolia
      if (method === 'eth_accounts' || method === 'eth_requestAccounts') return [address];
      return null;
    },
    on: () => {},
    removeListener: () => {},
  };
}

function enrichWallet(w: SerializedWallet): ConnectedWallet {
  return {
    ...w,
    walletClientType: w.walletClientType ?? 'injected',
    connectorType: 'injected',
    chainId: 'eip155:11155111',
    meta: { id: 'io.e2e.mockwallet', name: 'Mock Wallet', icon: '' },
    getEthereumProvider: async () => makeStubProvider(w.address),
  };
}

// useWallets() must return a referentially STABLE array: @privy-io/wagmi's
// useSyncPrivyWallets keys an effect on the wallets array and calls reconnect()
// in it, so a fresh array each render loops forever and hangs the page. The
// source array is stable (DEFAULT_STATE.wallets is a constant;
// window.__E2E_PRIVY_STATE__ is set once by addInitScript), so cache the
// enriched result keyed on it.
const enrichedCache = new WeakMap<SerializedWallet[], ConnectedWallet[]>();

function enrichWallets(source: SerializedWallet[]): ConnectedWallet[] {
  let cached = enrichedCache.get(source);
  if (!cached) {
    cached = source.map(enrichWallet);
    enrichedCache.set(source, cached);
  }
  return cached;
}

export type PrivyClientConfig = Record<string, unknown>;

export function PrivyProvider({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}

export function usePrivy() {
  const state = getState();
  return {
    ready: state.ready,
    authenticated: state.authenticated,
    user: state.authenticated && state.wallets[0]
      ? { linkedAccounts: [] as { type: string }[] }
      : null,
    login: () => {},
    logout: () => {},
    connectWallet: () => {},
  };
}

export function useWallets() {
  const state = getState();
  return { ready: state.ready, wallets: enrichWallets(state.wallets) };
}

export function useCreateWallet() {
  return { createWallet: async () => {} };
}

// Used internally by @privy-io/wagmi's WagmiProvider (useSyncPrivyWallets)
// to react to live wallet-connect events. The mocked usePrivy/useWallets
// above never authenticate through a real flow, so these callbacks are
// never invoked — they only need to exist so that import doesn't fail.
export function useConnectWallet(_opts?: { onSuccess?: (...args: any[]) => void }) {
  return { connectWallet: () => {} };
}

export function useConnectOrCreateWallet(_opts?: { onSuccess?: (...args: any[]) => void }) {
  return { connectOrCreateWallet: () => {} };
}

export function useLogin(_opts?: { onComplete?: (...args: any[]) => void }) {
  return { login: () => {} };
}
