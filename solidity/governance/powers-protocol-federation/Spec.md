# Powers Protocol Federation — Governance Specification

> **Status:** Draft
> **Network:** Ethereum Sepolia (chain id 11155111) — test deployment
> **Design date:** 2026-07-09

---

## Purpose

This is a **federation of three interlocking on-chain organisations** that together sustain the Powers Protocol and its mandate ecosystem. Rather than one monolithic council, authority is split across three formally-independent Powers contracts, each holding **its own treasury** (the Powers contract is itself the treasury — no external multisig) and its own elected membership, wired together through mutual funding dependencies:

- **Core Governance** — funds development and audits of the core protocol; holds the main treasury; distributes funding downstream to the Mandates organisation.
- **Mandates Governance** — funds development and audits of individual mandates and governs which mandates are listed in `MandateRegistry.sol`.
- **Endowment Governance** — invests the endowment corpus (Aave v3 on Ethereum Sepolia) and pays a recurring income stream upward to Core.

The three form a **ring of consent**: the Endowment streams income to Core, Core funds Mandates, and each cross-organisation link requires *both* organisations to approve their own side of it.

This structure is a deliberate implementation of Ostrom's eighth design principle — governance "organised in multiple layers of nested enterprises" (E. Ostrom 1990; Carlisle & Gruber 2017) — and of genuine polycentricity, which requires units that are *both* formally independent *and* functionally interdependent (E. Ostrom, 2009 Nobel lecture). In Powers terms: distinct mandate sets per organisation (independence) chained through cross-organisation `ExternalAction` requests and `needFulfilled` conditions (interdependence).

---

## Architecture Overview

```
   ┌─────────────────┐   (1) requests budget   ┌─────────────────┐
   │    MANDATES      │ ──────────────────────▶ │      CORE        │
   │   GOVERNANCE     │                         │   GOVERNANCE     │
   │                  │ ◀────────────────────── │                  │
   │ own treasury +   │   (2) funds sub-org     │ own treasury     │
   │ MandateRegistry  │                         │ (main)           │
   └─────────────────┘                         └───┬──────────▲────┘
                                    (3) income stream │          │ (4) veto
                                                      ▼          │ new investments
                                               ┌─────────────────┐
                                               │    ENDOWMENT     │
                                               │   GOVERNANCE     │
                                               │ own treasury +   │
                                               │ Aave v3 position │
                                               └─────────────────┘
```

**Cross-organisation seats** (assigned once, in each organisation's setup mandate):

| Seat | Held by | Located in | Enables |
|------|---------|-----------|---------|
| "Funded Sub-org" (role 4) | Mandates Powers **contract address** | Core Governance | Mandates can request a budget from Core |
| "Core Beneficiary" (role 2) | Core Powers **contract address** | Endowment Governance | Core can draw the income stream, and can veto new investments |

Because a Powers contract *is* an account, assigning it a role in another Powers contract lets it act there. When Mandates fires an `ExternalAction` into Core, Core sees the caller as the Mandates contract, which holds role 4 — so the `allowedRole` check passes. This is the documented child-to-parent call pattern, used here laterally between peers.

---

## Global conventions

- **No external multisig.** Each Powers contract is its own treasury (`setTreasury(address(powers))`) and holds and moves funds directly through governed mandates. Funds are secured by governance itself — elected votes plus timelocks — not by a separate signer set. Payments are `BespokeAction_Simple` token transfers; Aave calls are direct.
- **Treasury/payment token.** For this test deployment the treasuries transact in Aave's test **USDC** on Ethereum Sepolia (`0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8`, 6 decimals). The Endowment additionally handles test **WETH** (`0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c`).
- **Mandate version:** resolved at deploy time to each mandate's latest registered version on the canonical `MandateRegistry` (via `getLatestVersion`) — no version is pinned in the deploy script.
- **Time base (test deployment):** all durations are in minutes, using the rule "1 minute stands in for 1 day, with a 1-minute floor." On Ethereum Sepolia (~300 blocks/hour) 1 minute ≈ 5 blocks, computed at runtime via `minutesToBlocks(minutes, helperConfig.getBlocksPerHour(block.chainid))`.
- **Distributed power from day one.** The Admin role (0) in each organisation performs *setup only* — labelling roles, wiring cross-organisation seats, approving Aave, and seeding a small founding electorate — and holds no ongoing executive or spending power. It steps back after setup.
- **Founding cohort bootstrap.** Because elections need an electorate, each setup mandate pre-assigns a small founding set of members to the elected roles. These assignments are explicit in the deploy script and are meant to be tuned or removed before any live deployment. In tests they are exercised by the runner's initial-setup call and supplemented with direct `vm.prank(powers)` role assignments.
- **Metadata URI:** `TBD` for all three organisations — a placeholder empty string is used in the deploy script with a `// TODO` marker. Set before deploying live.
- **Veto timing rule:** wherever a veto exists, the executing mandate's `timelock` exceeds the veto window (the proposal `votingPeriod`, plus — for the cross-organisation veto — a full Core veto cycle), so an action cannot execute before its veto window closes.

---

## Organisation 1 — Core Governance

**Treasury:** the Core Powers contract itself (holds test USDC).

### Roles

| Role ID | Name | Description | How to join | Max |
|---------|------|-------------|-------------|-----|
| 0 | Admin | Deploy-time setup only; no ongoing power | Deployer at construction | 1 |
| max | Public | Everyone | Automatic | ∞ |
| 1 | Core Member | Governs protocol-development funding and audits | Election (`Nominate` → `PeerSelect`); founding cohort seeded at setup | ∞ |
| 2 | Security Council | Emergency pause/restart and reform veto | Elected by Core Members (`Nominate` → `PeerSelect`) | small (e.g. 3) |
| 3 | Whitelisted Auditor | Audit organisations eligible for paid audit work | Assigned by Core Member governance | ∞ |
| 4 | Funded Sub-org | Cross-org seat — the Mandates Powers contract | Assigned at setup | 1 |

### Governance Flows

**Flow C1 — Pay Core-Development Invoice**
| Step | Mandate | Who | Voting | Conditions |
|------|---------|-----|--------|------------|
| 1 | StatementOfIntent (`address Recipient, uint256 Amount, string Reference`) | Core Member (1) | Yes — 30% quorum, 51% | — |
| 2 | BespokeAction_Simple → `USDC.transfer(recipient, amount)` | Core Member (1) | No | needFulfilled = step 1; timelock 2 min |

**Flow C2 — Whitelist / De-whitelist an Audit Organisation**
| Step | Mandate | Who | Voting | Conditions |
|------|---------|-----|--------|------------|
| 1 | BespokeAction_Simple → `Powers.assignRole` (role 3) | Core Member (1) | Yes — 50% quorum, 66% | — |
| 2 | BespokeAction_Simple → `Powers.revokeRole` (role 3) | Core Member (1) | Yes — 50% quorum, 66% | — |

**Flow C3 — Commission a Core Audit → Pay on Completion**
| Step | Mandate | Who | Voting | Conditions |
|------|---------|-----|--------|------------|
| 1 | StatementOfIntent (`address Auditor, uint256 Fee, string Scope`) — commission | Core Member (1) | Yes — 30% quorum, 51% | — |
| 2 | BespokeAction_Simple → `USDC.transfer(auditor, fee)` | Core Member (1) | Yes — 30% quorum, 51% | needFulfilled = step 1; timelock 2 min (represents "after job completed") |

**Flow C4 — Fund the Mandates Organisation** *(cross-org, receiving end)*
| Step | Mandate | Who | Voting | Conditions |
|------|---------|-----|--------|------------|
| 1 | StatementOfIntent (`address To, uint256 Amount`) — Core ratifies the budget | Core Member (1) | Yes — 50% quorum, 51% | — |
| 2 | BespokeAction_Simple → `USDC.transfer(mandatesTreasury, amount)` | Funded Sub-org (4) = Mandates contract | No | needFulfilled = step 1; timelock 1 min |

> Mandates initiates by firing an `ExternalAction` into step 2 (see Flow M5). Step 2's `allowedRole` is the Mandates contract's seat, and `needFulfilled = step 1` guarantees Core's own members ratified the amount first — both sides consent.

**Flow C5 — Emergency Pause / Restart Core Flows**
| Step | Mandate | Who | Voting | Conditions |
|------|---------|-----|--------|------------|
| 1 | PauseMandates (targets the C1/C3/C4 funding mandates; `bool paused`) | Security Council (2) | No | Instant (no voting, no timelock) |

**Flow C6 — Treasury Transfer / Recover Tokens**
| Step | Mandate | Who | Voting | Conditions |
|------|---------|-----|--------|------------|
| 1 | OpenAction (`address[] targets, uint256[] values, bytes[] calldatas`) — move any token the org holds (covers mistaken-transfer recovery and general treasury ops) | Core Member (1) | Yes — 50% quorum, 66% | timelock 2 min |

**Flow C7 — Governance Reform (with Security Council veto)**
| Step | Mandate | Who | Voting | Conditions |
|------|---------|-----|--------|------------|
| 1 | StatementOfIntent (`address[] Mandates, uint256[] RoleIds`) — propose | Core Member (1) | Yes — 50% quorum, 66% | — |
| 2 | StatementOfIntent — Security Council veto | Security Council (2) | No | needFulfilled = step 1 |
| 3 | Adopt_Mandates — adopt approved mandates | Core Member (1) | No | needFulfilled = step 1; needNotFulfilled = step 2; timelock 6 min (> vote) |

**Flow C8 — Draw Endowment Income** *(cross-org; collects the recurring stream)*
| Step | Mandate | Who | Voting | Conditions |
|------|---------|-----|--------|------------|
| 1 | ExternalAction_Simple → Endowment Flow E3 | Core Member (1) | No | — (period is enforced on the Endowment side via `throttleExecution`) |

**Flow C9 — Veto an Endowment Investment** *(cross-org; casts Core's organisational veto)*
| Step | Mandate | Who | Voting | Conditions |
|------|---------|-----|--------|------------|
| 1 | StatementOfIntent (`address Asset, uint256 Amount`) — Core decides to veto | Core Member (1) | Yes — 30% quorum, 51% | — |
| 2 | ExternalAction_Simple → Endowment Flow E1 step 2 (the veto slot) | Core Member (1) | No | needFulfilled = step 1 |

---

## Organisation 2 — Mandates Governance

**Treasury:** the Mandates Powers contract itself (holds test USDC). **Governs:** a `MandateRegistry` instance it owns.

### Roles

| Role ID | Name | Description | How to join | Max |
|---------|------|-------------|-------------|-----|
| 0 | Admin | Setup only | Deployer | 1 |
| max | Public | Everyone | Automatic | ∞ |
| 1 | Mandate Assessor | Governs mandate funding, audits, and registry listings | Election (`Nominate` → `PeerSelect`); founding cohort seeded | ∞ |
| 2 | Security Council | Vetoes registry additions and reform | Election | small |
| 3 | Whitelisted Auditor | Eligible for paid mandate-audit work | Assigned by Assessor governance | ∞ |

### Governance Flows

**Flow M1 — Pay Mandate-Development Invoice** — StatementOfIntent (`address Recipient, uint256 Amount, string Reference`), Assessor, vote → BespokeAction_Simple `USDC.transfer` (needFulfilled, timelock 2 min).

**Flow M2 — Commission a Mandate Audit → Pay on Completion** — StatementOfIntent (`address Auditor, uint256 Fee, string Scope`) commission (Assessor, vote) → BespokeAction_Simple `USDC.transfer` to auditor (needFulfilled, timelock 2 min).

**Flow M3 — Add a Mandate to the Registry (Security Council veto window)**
| Step | Mandate | Who | Voting | Conditions |
|------|---------|-----|--------|------------|
| 1 | StatementOfIntent (`string MandateName, address MandateAddress, bytes32 CreationCodeHash`) | Mandate Assessor (1) | Yes — 50% quorum, 66% | — |
| 2 | StatementOfIntent — Security Council veto | Security Council (2) | No | needFulfilled = step 1 |
| 3 | BespokeAction_Simple → `MandateRegistry.registerMandate` | Mandate Assessor (1) | No | needFulfilled = step 1; needNotFulfilled = step 2; timelock 6 min (> vote) |

**Flow M4 — Remove a Mandate from the Registry** — StatementOfIntent (`uint16 Major, uint16 Minor, uint16 Patch, string MandateName`) propose (Assessor, vote) → BespokeAction_Simple → `MandateRegistry.deactivateMandate` (needFulfilled, timelock 2 min).

**Flow M5 — Request Funding from Core** *(cross-org, requesting end)*
| Step | Mandate | Who | Voting | Conditions |
|------|---------|-----|--------|------------|
| 1 | StatementOfIntent (`address To, uint256 Amount`) — Mandates decides its ask | Mandate Assessor (1) | Yes — 50% quorum, 51% | — |
| 2 | ExternalAction_Simple → Core Flow C4 step 2 | Mandate Assessor (1) | No | needFulfilled = step 1; timelock 1 min |

> The Mandates Powers contract holds Core role 4, so its `ExternalAction` satisfies C4 step 2's `allowedRole`; Core's own C4 step 1 must also have passed for the transfer to fire.

**Flow M6 — Treasury Transfer / Recover Tokens** — OpenAction, Assessor, vote, timelock 2 min.

**Flow M7 — Governance Reform (SC veto)** — same three-step shape as C7 (propose → SC veto → Adopt_Mandates).

---

## Organisation 3 — Endowment Governance

**Treasury:** the Endowment Powers contract itself (holds test USDC and WETH, plus the interest-bearing aTokens received from Aave). **Invests via:** Aave v3 Pool on Ethereum Sepolia.

**Verified external addresses (Ethereum Sepolia; aave-address-book AaveV3Sepolia):**
- Aave v3 Pool: `0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951`
- Test USDC: `0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8`
- Test WETH: `0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c`

At setup the Endowment grants the Aave Pool a standing max `approve` on both tokens, so `supply` can pull them in one step (see Limitations).

### Roles

| Role ID | Name | Description | How to join | Max |
|---------|------|-------------|-------------|-----|
| 0 | Admin | Setup only | Deployer | 1 |
| max | Public | Everyone | Automatic | ∞ |
| 1 | Endowment Investor | Governs investment strategy and distributions | Election (`Nominate` → `PeerSelect`); founding cohort seeded | ∞ |
| 2 | Core Beneficiary | Cross-org seat — the Core Powers contract | Assigned at setup | 1 |

### Governance Flows

**Flow E1 — Invest: Supply to Aave (with Core organisational veto)**
| Step | Mandate | Who | Voting | Conditions |
|------|---------|-----|--------|------------|
| 1 | StatementOfIntent (`address Asset, uint256 Amount`) — propose | Endowment Investor (1) | Yes — 50% quorum, 66% | — |
| 2 | StatementOfIntent — **Core veto slot** | Core Beneficiary (2) = Core contract | No | needFulfilled = step 1 |
| 3 | BespokeAction_Simple → Aave `Pool.supply(asset, amount, onBehalfOf=powers, referralCode=0)` | Endowment Investor (1) | No | needFulfilled = step 1; needNotFulfilled = step 2; **timelock 15 min** (long enough for Core to run its own veto vote and fire the veto — see caveat) |

> **Core's veto covers new investments only.** Divestment (E2) is deliberately *not* vetoable, so the endowment can always retreat to safety quickly. Core casts the veto through Flow C9: Core Members vote, then fire an `ExternalAction` into step 2. Because step 2's `allowedRole` is the Core Beneficiary seat, only Core-as-an-organisation can veto. The 15-minute timelock on step 3 is sized to contain the full cross-org veto cycle (Endowment vote + Core vote + Core's `ExternalAction`); this makes investing the slowest action in the federation, matching the "endowment moves slowly" intent.

**Flow E2 — Divest: Withdraw from Aave** — StatementOfIntent (`address Asset, uint256 Amount`) propose (Investor, vote 50%/66%) → BespokeAction_Simple → Aave `Pool.withdraw(asset, amount, to=powers)` (needFulfilled, timelock 3 min). No Core veto — exit stays fast.

**Flow E3 — Endowment Income Stream (to Core)** *(cross-org, recurring)*
| Step | Mandate | Who | Voting | Conditions |
|------|---------|-----|--------|------------|
| 1 | PresetActions → `USDC.transfer(coreTreasury, FIXED_PERIOD_AMOUNT)` | Core Beneficiary (2) = Core contract | No | `throttleExecution` = the stream period (e.g. 10 min); no vote |

> This is the recurring stream, following the **horizontal fiscal equalisation** pattern (Podger, Chan & Wanna 2020): a predictable, rules-based transfer rather than repeated political asks. The amount and period are fixed constitutionally; the Endowment retains full control — it can pause the stream via its emergency/reform powers or change the amount via reform (`Revoke_Mandates` + `Adopt_Mandates`). Core collects the stream through Flow C8 (an `ExternalAction`; the `throttleExecution` on this mandate enforces that it can fire at most once per period). Trade-off: the amount is a governance-set fixed figure per period, not a live percentage of realised yield — there is no on-chain yield oracle (see Limitations).

**Flow E4 — Treasury Transfer / Recover Tokens** — OpenAction, Investor, vote, timelock 2 min.

**Flow E5 — Governance Reform** — StatementOfIntent propose (Investor, vote) → Adopt_Mandates (needFulfilled, timelock 6 min). No Security Council here; endowment investors self-govern reform, and Core already holds an investment veto.

---

## Checks and Balances

| Mechanism | How it works | Who holds it |
|-----------|-------------|--------------|
| Security Council pause | Instantly pauses (and later restarts) Core funding flows C1/C3/C4 | Core Security Council (elected) |
| Registry-addition veto | Blocks a mandate listing during a veto window before it registers | Mandates Security Council (elected) |
| Reform veto | Blocks governance self-modification (`Adopt_Mandates`) in Core and Mandates | Security Councils |
| Core investment veto | Core (as an organisation) can block a new Endowment investment during a long timelock window | Core Members, via the Core Beneficiary seat |
| Cross-org double consent | Every inter-org action needs both organisations to approve their own side | Both organisations' members |
| Timelocks on spending | 1–6 min (15 min for Endowment investing) between approval and execution; always > the veto window | Automatic |
| Quorum + supermajority | 50% quorum / 66% threshold on high-stakes actions (registry, invest, reform); 30/51 on routine payments | Elected members |
| Recurring-stream off-switch | The Endowment can pause or revoke the income stream at any time | Endowment Investors |

**Security considerations**
- The Security Councils can pause/veto but cannot spend, govern, or seize — a deliberately narrow, reversible emergency power (graduated, not absolute: Ostrom DP5).
- Cross-org seats are held by *contract addresses*, not humans, so they cannot be socially captured; the acting organisation's own membership still gates every request.
- With no external multisig, funds are secured by governance: every spend passes an elected vote plus a timelock, and no single key can move treasury funds.

---

## External Dependencies

| System | Purpose | Required? |
|--------|---------|-----------|
| `MandateRegistry` (canonical, from config; to be owned by Mandates Powers) | Registry add/remove + paid-tier flows | Yes |
| Aave v3 Pool (Eth Sepolia) | Endowment investment venue | Yes |
| Test USDC / WETH (Eth Sepolia) | Treasury/payment token and investable assets | Yes |
| `Nominees` contracts | Candidate registries for the elections (one per elected role) | Yes |
| `PowersPaymaster` (×1, Core-owned) | Gasless participation across all three orgs | Yes (opted in) |

*(No Gnosis Safe / Allowance Module — each Powers contract is its own treasury.)*

---

## Account Abstraction

The federation deploys **one central `PowersPaymaster`** (ERC-4337), owned and funded by **Core Governance** and seeded with **0.15 ETH** at deployment, so members of *any* of the three organisations can participate without holding gas themselves. A single paymaster works because it sponsors any user operation whose target is in its `sponsoredTargets` list — Core's setup mandate registers all three Powers contracts (Core is registered by the paymaster constructor; Mandates and Endowment are added explicitly). Each organisation's `Powers.paymaster()` points at this same contract.

Because the paymaster is owned by Core, only Core can manage the sponsored-target list and withdraw funds. Core therefore holds the two standard flows (governed by the Core Member role):
- **Fund Paymaster** — `StatementOfIntent` propose → `PresetActions` deposit `0.05 ETH`.
- **Withdraw from Paymaster** — `StatementOfIntent` (`address withdrawAddress, uint256 amount`) → `BespokeAction_Simple` → `centralPaymaster.withdrawTo`.

Mandates and Endowment have no paymaster flows of their own (`deposit()` is public, so they could still voluntarily top the shared pool up, but management and withdrawal stay with Core). The deployer wallet must hold at least **0.15 ETH** plus gas at deploy time to seed the paymaster. Trade-off: a single shared gas pool and a single point of failure for the whole federation, accepted in exchange for centralised funding and a simpler ownership model.

---

## Design Rationale

- **Nested enterprises (Ostrom DP8; Carlisle 2017).** Three organisations around three distinct asset/decision domains is the empirically-robust structure for a complex commons, rather than one over-loaded council.
- **Genuine polycentricity (E. Ostrom 2009).** Independence comes from disjoint mandate sets and separate treasuries; interdependence from the funding ring wired via `ExternalAction` + `needFulfilled`. Each organisation truly does different things.
- **Collective-choice / affected-party participation (Ostrom DP3).** Reform (`Adopt_Mandates`) is member-driven, not admin-driven; impacted roles hold veto steps; Core — which depends on endowment income — holds a veto over how that endowment is put at risk.
- **Graduated sanctions, not binary control (Ostrom DP5).** Emergency powers are reversible pauses and bounded vetoes, never unilateral seizure or spending.
- **Horizontal fiscal equalisation (Podger, Chan & Wanna 2020).** Endowment→Core income is a standing, rules-based stream rather than ad-hoc politics.
- **Hard-coded over discretionary (governance reading-guide rule 10).** Timing and dependency constraints are enforced in-contract (`needFulfilled` / `needNotFulfilled` / `timelock` / `throttleExecution`) rather than left to after-the-fact judgement.
- **Minimal institutional surface.** Dropping the external multisig removes provisioning ceremony and keeps the whole federation self-contained and auditable in one place, at the cost of independent signer security — an acceptable trade for a governed test federation.

---

## Limitations

- **Aave token approval.** `Pool.supply` requires the Endowment to have `approve`d the Pool for the asset. This is a one-time standing max approval granted in the Endowment setup mandate (USDC and WETH). A production design would govern approvals per-investment rather than granting a standing approval.
- **Registry ownership.** The deploy points the Mandates org at the **canonical** `MandateRegistry` from configuration (`Configurations.getMandateRegistry`) rather than deploying a fresh instance. The deploy does not own that registry, so its owner-only calls (the paid-tier seeding that previously ran in the Mandates setup mandate, and the governed M3/M4/M8/M9/M10 flows) revert until the registry's ownership is transferred to the Mandates Powers contract out-of-band. Seed the exchange rate / protocol fee via the M8/M9 flows after that transfer.
- **Income is a fixed drip, not live yield.** Flow E3 streams a governance-set fixed amount per period; there is no on-chain "realised yield" oracle. A future `BespokeAction_OnReturnValue` reading aToken balances could size the stream to actual interest earned.
- **Membership boundaries at genesis.** Elections are the real mechanism, but the founding cohort is seeded by the setup mandate. Until the first elections run, the founding cohort holds voting power — tune this set carefully before a live deploy (Ostrom DP1, clear boundaries).
- **Cross-org veto timing.** Core's veto over new investments only works if the Endowment's investment timelock (15 min here) is long enough for Core to convene its own vote and fire the veto. If Core cannot act in time, the investment proceeds — the veto is a window, not a permanent hold.

---

## Implementation Notes

- **Folder:** `governance/powers-protocol-federation/`
- **One deploy script** brings up all three Powers contracts, their Nominees helpers, and the single Core-owned central paymaster, wires the cross-org seats, and points the Mandates org at the canonical `MandateRegistry` from config — they must be co-deployed to know each other's addresses.
- **Files:** `Deploy.s.sol`, `Actions.s.sol`, `Runners.s.sol`, `Test.t.sol`, `README.md`, `Makefile`, `.env.example`.
- **Mandate `nameDescription` strings must match character-for-character across Deploy / Actions / Runners.**
- **Mandate version:** MAJOR=0, MINOR=1, PATCH=8.
