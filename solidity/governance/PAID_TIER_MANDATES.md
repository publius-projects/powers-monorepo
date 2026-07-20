# Paid Tier for Mandates — Design

> Status: implemented (Phase 1 + developer-priced revision). This document is the design-of-record.
>
> The paywall is **unified with the `MandateRegistry`** — one primitive — and charges a
> **one-time fee on adoption** rather than a recurring subscription.
>
> **Revision (developer-set credit pricing + global exchange rate):** per-mandate pricing is now
> **declared by the mandate itself** (`IMandate.priceInCredits()` / `IMandate.devs()`), mirroring the
> existing `version()` pattern, instead of being set by the registry owner. The registry owner sets a
> **single global credit→wei exchange rate** (`weiPerCredit`). This lets the owning org adjust for ETH
> price swings in one action without re-pricing every mandate, and stops the org from repricing a
> mandate out from under its developer.

## Goals

Powers wants to monetize advanced mandates **and** let third-party developers earn from
mandates they author, under four constraints:

1. **Developer-owned pricing** — the developer of a mandate decides what it costs (in credits),
   declared on the mandate contract itself; the owning org cannot change an individual mandate's
   price. Pricing is *not* hardcoded protocol-wide — each mandate opts in by overriding a getter.
2. **Third-party devs get paid** — a mandate declares one or more developer payees.
3. **No ecosystem fragmentation** — a user (an org paying to use paid mandates) pays **one
   address, once**, and never has to pay each individual developer.
4. **Elegant** — few primitives that can be broken; the `MandateRegistry` and the paid tier
   are **one and the same system**.

## Key architectural findings

- **The whitelist is currently opt-in, not a security boundary.** The `MandateRegistry` is
  consulted at adoption time, inside `PowersUtilities.storeMandate` via
  `isMandateAddressActive(targetMandate)`. But a Powers instance stores its registry as an
  **immutable** value set at construction, and `address(0)` disables enforcement entirely.
- **Mandates are singletons** shared across all DAOs; per-DAO state is keyed by
  `(powers, mandateId)`. There is no per-DAO mandate deployment to attach payment to.
- **The mandate contract is the only component that always runs**, regardless of which
  registry/Powers is used. So to bind every adoption of the *registered* singleton, the paywall
  lives *inside* the mandate — though it still only binds the canonical registered copy, not
  forked redeployments (see threat model).
- **The registry already reads developer-declared values on-chain.** `registerMandate` reads
  `IMandate(mandate).version()` from the mandate itself, so the version an entry claims cannot be
  faked by the owner. This is the precedent the pricing revision follows: `priceInCredits()` and
  `devs()` are declared by the mandate the same way `version()` is.
- The reusable payment building blocks already in the repo are the ETH-transfer + percentage
  split patterns in `src/addons/helpers/Governed721.sol` and
  `src/addons/mandates/integrations/GovernedToken/GovernedToken_CollectSplitPayment.sol`.

## The core move: invert the check to **mandate → registry**

Each mandate, inside its own `initializeMandate`, calls back to the canonical registry to:

1. Confirm it is registered/active (the whitelist gate), and
2. If it is priced, charge the adopting org's prepaid balance and book the proceeds to its
   developers (minus a protocol fee).

Because `initializeMandate` always runs on adoption, inverting the check **upgrades the
enforcement boundary**: you cannot adopt *the vetted, registered* mandate without `onAdopt`
running and charging you, no matter which `Powers` you point at it.

**Threat model.** This is not cryptographic un-bypassability. A party unwilling to pay can
redeploy the same mandate bytecode with its `MANDATE_REGISTRY` immutable pointing at a registry
they control (or one that returns price `0`) and adopt it for free. The enforced asset is the
**vetted canonical singleton**; the economic moat is **governance vetting / trust, not
enforcement**. Note the price now lives on the mandate, so a clone that keeps the real code keeps
the real price too — to go free, a cloner must fork the code (forfeiting the vetting that
"registered" signals) or point at a registry with `weiPerCredit == 0` / a different rate.

## Design decisions

| Decision | Choice | Consequence |
|---|---|---|
| **Charge cadence** | **One-time on adoption.** Check lives only in `initializeMandate`. | Execution never touches the registry. A broken/deactivated registry blocks **new adoptions only**; already-adopted mandates keep executing. |
| **Enforcement** | **Mandatory** for the canonical registered singleton. | Acceptable because ongoing execution is unaffected — orgs keep running even if the registry is down. |
| **Price authority** | **Developer-declared, on the mandate.** `priceInCredits()` returns the price in credits; `devs()` returns the payees. Both are `virtual` getters defaulting to `0` / empty in the base, overridden per paid mandate. | The owner cannot alter an individual mandate's price or payees; it vets both at registration. A mandate re-prices only by shipping a new version. |
| **Exchange rate** | **Owner-set global `weiPerCredit`.** One knob converts every mandate's credit price to wei. | The owning org adjusts for ETH volatility in a single action, without touching individual mandates. Changing it never re-values existing prepaid balances (they are held in wei). |
| **Credit representation** | **Prepaid balance denominated in wei; "credit" is a pricing unit only.** `buyCredits` deposits ETH as-is; at adoption the cost is `priceInCredits × weiPerCredit`, debited in wei. | Always solvent — a rate change reprices future adoptions but never re-values what an org already prepaid. No ERC20, no rate oracle, no cross-org insolvency. A UI can show balance ÷ rate as a credit figure. |
| **Registry owner** | **A Powers org.** Only that org can register/deactivate mandates, set `weiPerCredit`, and set `feeBps`. | Governance *is* the trust vector — "registered" keeps meaning "vetted". |

## Design

### 1. `MandateRegistry` — unified registry + credits contract
Path: `src/core/helpers/MandateRegistry.sol`. Stays `Ownable`; the owner is a Powers org.

**Global pricing state:**
- `uint256 public weiPerCredit;` — how many wei one credit is worth. Owner-set via
  `setWeiPerCredit(uint256)`; seeded to `DEFAULT_WEI_PER_CREDIT` (1) in the constructor.

**Credit / earnings ledger** (all native ETH, internal):
- `mapping(address org => uint256) public credits;` — prepaid balance per org, in **wei**.
- `mapping(address payee => uint256) public earnings;` — withdrawable; the owning org is a payee
  for the protocol fee.
- `uint16 public feeBps;` — protocol fee in basis points (default `1000` = 10%), owner-settable,
  capped at `MAX_FEE_BPS` (3000).

**Functions:**
- `setWeiPerCredit(uint256)` / `setFeeBps(uint16)` — owner-only global knobs.
- `buyCredits(address org) external payable` — anyone tops up any org: `credits[org] += msg.value`.
- `onAdopt(address org) external` — **called by the mandate** during `initializeMandate`;
  `msg.sender` **is the mandate** (trustless identity). Logic:
  - `require(isMandateAddressActive(msg.sender), NotRegistered)` — mandatory whitelist gate.
  - `priceCredits = IMandate(msg.sender).priceInCredits()`; if `0` → return (free).
  - `rate = weiPerCredit`; if `0` → revert `ExchangeRateNotSet` (never silently underpay devs).
  - `costWei = priceCredits * rate`; `credits[org] -= costWei` (reverts if insufficient).
  - `devs = IMandate(msg.sender).devs()`; if empty → revert `NoDevs`.
  - `fee = costWei * feeBps / 10000` → `earnings[owner()]`; split `costWei - fee` equally across
    `devs` into `earnings`, remainder wei to `devs[0]`. Emits `MandateCharged(mandate, org, costWei, fee)`.
- `withdrawEarnings() external nonReentrant` — pull pattern; sends `earnings[msg.sender]` in ETH
  after zeroing it (checks-effects-interactions), via `.call` with a success check.

**Removed vs. the owner-priced draft:** `mandatePrice` / `mandateDevs` mappings,
`setMandatePricing`, `getMandateDevs`, and the `MandatePricingSet` event — price and payees now
come from the mandate.

### 2. Mandate base classes declare price + payees
Files: `src/Mandate.sol`, `src/AsyncMandate.sol`, and the `src/interfaces/IMandate.sol` interface.
- `IMandate` gains `priceInCredits() external view returns (uint256)` and
  `devs() external view returns (address[] memory)`, alongside `version()`.
- Each base adds `virtual` defaults returning `0` / an empty array, so **every existing mandate
  inherits free behavior with no per-mandate change**. Declared `view` (not `pure`) so a developer
  may override with a baked-in constant or a storage-backed value.
- The `onAdopt` call at the top of `initializeMandate` is unchanged.

**Interface-id consequence:** adding functions to `IMandate` changes `type(IMandate).interfaceId`,
which registration (`registerMandate`) and adoption (`storeMandate`) both gate on. All mandates
must be recompiled/redeployed — fine on testnet; `DeployMandates.s.sol` re-registers everything.

### 3. Making a mandate paid (developer usage)
A developer charges by overriding the two getters in their concrete mandate:
```solidity
function priceInCredits() public pure override returns (uint256) { return 100; }
function devs() public view override returns (address[] memory d) { d = new address[](1); d[0] = DEV; }
```
No core change is needed; free mandates simply don't override.

### 4. `Powers.sol` / `PowersUtilities` — left unchanged
No edits to `Powers.sol` or `PowersUtilities.storeMandate`. The existing Powers-side
`isMandateAddressActive` check remains a belt-and-suspenders for the sanctioned path; the
authoritative check lives in the mandate base.

### 5. Deployment & config
File: `script/DeployMandates.s.sol` + `script/Configurations.s.sol`.
- `Configurations.getWeiPerCredit(chainId)` provides the per-network seed rate.
- On a fresh registry deploy, the script calls `registry.setWeiPerCredit(...)` (owner-gated) so
  priced mandates work out of the box. Existing registries are left at their on-chain rate.
- Mandates are registered via `batchRegisterMandates` (free by default; a mandate is paid only if
  it overrides `priceInCredits()`).

### 6. Frontend / ABIs
- `make update-builds` from `solidity/` to sync ABIs (the `IMandate` interfaceId and the registry
  ABI both change).
- No frontend paid-tier code exists yet — the credits/pricing UI is a green field.

## Payment at deployment (one transaction)

The credits ledger makes "pay one address, once" work across a multi-mandate adoption without a
separate user step. The adoption call stack is non-payable, so money can never reach a mandate
through the path that adopts it — that is *why* the ledger exists: it decouples "money in"
(`buyCredits`) from "charge" (`onAdopt` debits the ledger).

A single-transaction deploy UX (future work, `PowersFactory`): add a public **payable** deploy
entry point that sums each constitution mandate's `priceInCredits() × weiPerCredit`, calls
`buyCredits{value: total}(newPowers)`, runs `constitute` (each `onAdopt` debits the fresh
credits), and refunds excess. The user sees one transaction, one payment.

## Worked example

1. A dev writes `FancyMandate`, overriding `priceInCredits()` to return `100` and `devs()` to
   return `[devA, devB]`. They deploy the singleton and propose it to the protocol's governance org.
2. Governance vets and calls `registerMandate("FancyMandate", addr, codeHash)` — whitelisted. The
   price (100 credits) and payees are already baked into the contract; the owner cannot change them.
3. The owning org has set `weiPerCredit = 1e14` (0.0001 ETH/credit), so `FancyMandate` costs
   `100 × 1e14 = 0.01 ETH` per adoption. If ETH doubles, governance halves `weiPerCredit` in one
   action and every priced mandate re-prices at once.
4. A DAO wants it. Any member calls `buyCredits{value: 0.05 ETH}(dao)`.
5. The DAO adopts `FancyMandate`. During `initializeMandate`, `onAdopt(dao)`: registered ✓, cost
   `0.01 ETH` deducted from `credits[dao]` (→ 0.04 left), 10% fee (0.001 ETH) to the owning org,
   0.0045 ETH each to `devA` and `devB`.
6. `devA`, `devB`, and the owning org later call `withdrawEarnings()` for their ETH.

## Critical files
- **Core:** `src/core/helpers/MandateRegistry.sol` (weiPerCredit + credits + split + withdraw +
  `onAdopt`), plus its `IMandateRegistry` interface.
- **Interface / bases:** `src/interfaces/IMandate.sol`, `src/Mandate.sol`, `src/AsyncMandate.sol` —
  `priceInCredits()` / `devs()`.
- **Deploy / config:** `script/DeployMandates.s.sol`, `script/Configurations.s.sol`.
- **Tests:** `test/unit/MandateRegistryCredits.t.sol` (uses a `PricedMandate` test double that
  overrides the getters).

## What is deliberately NOT changed
- `Powers.sol` — untouched (it is not meant to be modified).
- **No ERC20 credit token** — internal wei ledger only.
- **No per-execution / subscription logic** — a single one-time charge on adoption.

## Verification
1. `cd solidity && forge build`.
2. `forge test --match-contract MandateRegistryCreditsTest -vvv` — pricing, exchange-rate math,
   split, withdrawals, guards (`ExchangeRateNotSet`, `NoDevs`), and the registry-down invariant.
3. Free-mandate regression across `Mandate.t.sol`, `AsyncMandate.t.sol`, `Powers.t.sol`,
   `Reform.t.sol` — all `registerTestMandate` adoptions still pass at zero cost.
4. `make update-builds`.

## Open design points
- **Split weighting** — equal split assumed; switch to weighted (bps per dev) only if devs need
  unequal shares. Since payees are now mandate-declared, weighting would also live on the mandate.
- **Runtime price updates** — `priceInCredits()` is `view`, so a developer *may* back it with a
  dev-owned storage setter instead of a constant. Default guidance is a constant per version.
- **USD-denominated rate** — `weiPerCredit` is set manually today. A future upgrade could derive it
  from a Chainlink ETH/USD feed so credits track USD automatically; the one-time adoption cadence
  means a stale/down feed only blocks *new* adoptions, matching the existing failure model.
- **Credit refunds / org withdrawals** — not included (prepaid, non-refundable).
