# Paid Tier for Advanced Mandates — Design Proposal

> Status: proposal / plan only. No protocol code has been changed by this document.

## Context

Powers wants to monetize its "advanced" mandates (the Tier 4 contracts under
`src/addons/mandates/`). The question was whether a paid tier is possible given the
current whitelisting architecture, and if so how.

**Feasibility answer: yes, it is possible** — but *where* the paywall lives determines
whether it's actually enforceable.

Key architectural findings:

- **The whitelist is opt-in, not a security boundary.** The `MandateRegistry` is
  consulted exactly once — at adoption time, inside `PowersUtilities.storeMandate`
  (`src/libraries/PowersUtilities.sol:56-62`) via `isMandateAddressActive(targetMandate)`.
  But a Powers instance stores its registry as an **immutable** value set at construction
  (`src/Powers.sol:84`), and `address(0)` disables enforcement entirely. Anyone can deploy
  their own `Powers` pointing at `address(0)` and adopt any mandate. So a registry-level
  gate only paywalls the sanctioned deployment path (factory/frontend), not the protocol.
- **Mandates are singletons** shared across all DAOs; per-DAO state is keyed by
  `(powers, mandateId)` (`src/Mandate.sol:56-60`). There is no per-DAO mandate deployment
  to attach payment to.
- **The mandate contract is the only component that always runs**, regardless of which
  registry/Powers is used. Therefore the paywall must live *inside* the premium mandate to
  be tamper-proof.
- There is **no on-chain tier/price/subscription primitive today** — "advanced/Tier 4"
  exists only in folder layout and `governance/CORE_MANDATES.md`. The reusable payment
  building block is the `Governed721` / `GovernedToken_CollectSplitPayment` ERC20
  `transferFrom` pattern.

**Chosen requirements:** hard, mandate-enforced paywall · recurring subscription
(time-bounded access) · payment in an ERC20 stablecoin to a protocol-owned recipient.

## Design

Two new contracts + a one-word change to the two mandate base classes. No change to
`Powers.sol` or `MandateRegistry.sol`.

### 1. `PremiumMandateManager` (new subscription/access manager)
Path: `src/addons/helpers/PremiumMandateManager.sol`. `Ownable`, protocol-owned.

State:
- `IERC20 public paymentToken;` and `address public revenueRecipient;` (both owner-settable).
- `struct Plan { uint256 pricePerPeriod; uint256 period; bool isPremium; }` and
  `mapping(address mandate => Plan) public plans;`
- `mapping(address dao => mapping(address mandate => uint256 expiry)) public subscriptions;`

Functions:
- `setPlan(address mandate, uint256 pricePerPeriod, uint256 period)` — `onlyOwner`; marks a
  mandate premium and prices it.
- `setPaymentToken` / `setRevenueRecipient` — `onlyOwner`.
- `subscribe(address dao, address mandate, uint256 periods)` — anyone can pay (e.g. a DAO
  member funds their org). Uses **`SafeERC20.safeTransferFrom`**
  (`lib/openzeppelin-contracts/.../SafeERC20.sol`, already vendored) to pull
  `pricePerPeriod * periods` from `msg.sender` to `revenueRecipient`; extends
  `subscriptions[dao][mandate]` from `max(now, currentExpiry)` by `period * periods`. Emits
  `Subscribed`.
- `hasAccess(address dao, address mandate) view returns (bool)` — returns `true` when the
  mandate is **not** premium (so the base class is safe for all mandates), else
  `subscriptions[dao][mandate] > block.timestamp`.

Design consequence: a mandate can inherit the premium base and stay **free** until the
owner calls `setPlan`. This makes it safe to convert every addon mandate to the premium
base without forcing any of them to be paid.

### 2. Premium mandate base classes
`Mandate` and `AsyncMandate` are independent bases (`src/Mandate.sol`,
`src/AsyncMandate.sol`), so two thin abstracts:
- `src/addons/PremiumMandate.sol` (`abstract PremiumMandate is Mandate`)
- `src/addons/PremiumAsyncMandate.sol` (`abstract PremiumAsyncMandate is AsyncMandate`)

Each:
```solidity
address public immutable ACCESS_MANAGER;
constructor(address accessManager) { ACCESS_MANAGER = accessManager; }

function initializeMandate(uint16 i, string memory nd, bytes memory ip, bytes memory cfg)
    public virtual override
{
    require(IPremiumMandateManager(ACCESS_MANAGER).hasAccess(msg.sender, address(this)), "no active subscription");
    super.initializeMandate(i, nd, ip, cfg);      // msg.sender == adopting DAO
}

function executeMandate(address caller, uint16 id, bytes calldata data, uint256 nonce)
    public virtual override returns (bool)
{
    require(IPremiumMandateManager(ACCESS_MANAGER).hasAccess(msg.sender, address(this)), "subscription expired");
    return super.executeMandate(caller, id, data, nonce);   // msg.sender == DAO (Powers.sol:340)
}
```
- The `initializeMandate` override gates **adoption** (fail early).
- The `executeMandate` override gates **every execution** — this is what makes the
  subscription *recurring* (an expired sub blocks runs even after adoption). Powers calls
  `executeMandate` at `src/Powers.sol:340`; `msg.sender` there is the DAO's Powers contract,
  keying `hasAccess` correctly.

### 3. Required base change — make `executeMandate` overridable
`executeMandate` is currently **not `virtual`** in either base (`src/Mandate.sol:72`,
`src/AsyncMandate.sol:72`), so it cannot be overridden. Add the `virtual` keyword to both
signatures. This is the only change to core/base files; `initializeMandate` and
`handleRequest` are already `virtual`.

_Fallback if base edits are undesirable:_ instead put a `_requirePremiumAccess(powers)`
internal helper on the base abstracts and call it at the top of each premium mandate's
already-`virtual` `handleRequest` — one line per mandate, no base edit, but forgettable.

### 4. Convert the advanced mandates
Change each of the ~20 files under `src/addons/mandates/` from `is Mandate` →
`is PremiumMandate` (and the one async case, `ChainlinkFunctions_Open.sol`, →
`is PremiumAsyncMandate`), threading `accessManager` into their constructors (forwarded via
`PremiumMandate(accessManager)`). They remain free until priced. Optionally scope the first
cut to a chosen subset rather than all 20.

## Critical files
- **New:** `src/addons/helpers/PremiumMandateManager.sol`, `src/addons/PremiumMandate.sol`,
  `src/addons/PremiumAsyncMandate.sol`, interface `src/interfaces/IPremiumMandateManager.sol`.
- **Edit (add `virtual`):** `src/Mandate.sol:72`, `src/AsyncMandate.sol:72`.
- **Edit (change base + constructor):** the ~20 mandates under `src/addons/mandates/**`.
- **Deploy:** extend `script/DeployMandates.s.sol` to deploy the manager and pass its
  address into premium-mandate constructors; the deployer becomes manager owner (mirrors the
  current registry-owner pattern at `script/DeployMandates.s.sol:133`).
- **After deploy:** `make update-builds` (per CLAUDE.md) to sync ABIs to
  `frontend/context/builds/`; add manager address to `frontend/context/constants.ts`.

## What is deliberately NOT changed
- `MandateRegistry.sol` — the whitelist is orthogonal; premium mandates still register
  normally. No paid logic added there.
- `Powers.sol` — untouched (it is not meant to be modified).

## Verification
1. `cd solidity && forge build` — confirm the base `virtual` change and new contracts
   compile and Powers stays under the 24KB EIP-170 limit.
2. New Foundry test `test/unit/PremiumMandate.t.sol` (inherit `test/TestSetup.t.sol`),
   covering:
   - Deploy `PremiumMandateManager`, a premium test mandate, a mock ERC20; owner calls
     `setPlan`.
   - **Unpriced mandate** → `hasAccess` true → adoption + execution succeed (free-by-default
     holds).
   - **Priced, no subscription** → `constitute`/`adoptMandate` reverts "no active
     subscription".
   - **Subscribe then adopt** → `subscribe` pulls the correct ERC20 amount to
     `revenueRecipient` (assert balances), adoption + execution succeed.
   - **Expiry** → `vm.warp` past expiry → `executeMandate` reverts "subscription expired"
     even though already adopted (proves recurring enforcement).
   - **Re-subscribe** → access restored; `subscribe` while active extends from current
     expiry, not `now`.
3. `forge test --match-contract PremiumMandate -vvv`.
4. Manual bypass check (documents the known property): a `Powers` deployed with
   `mandateRegistry = address(0)` still cannot execute a priced premium mandate, because
   enforcement is in the mandate itself — this is what makes it "hard".
