---
title: "Yield Endowment — Governance Specification"
description: "Governance design specification for a yield-distributing endowment"
---

# Yield Endowment — Governance Specification

> **Status:** Draft
> **Network:** Sepolia / Arb Sepolia / Opt Sepolia / Anvil
> **Design date:** 2026-06-11

---

## Purpose

A yield-distributing endowment that receives funds at undefined intervals and allocates them through competitive slate voting every six months. The corpus is untouchable; only incoming yield is distributed. Members — drawn exclusively from past grantees — govern both the allocation process and the organisation's mission statement. A small, permanent group of Founding Members holds veto and emergency powers, ensuring institutional stability without day-to-day control.

---

## Roles

| Role ID | Name | Description | How to join | Max members |
|---------|------|-------------|-------------|-------------|
| 0 | Admin | Deployer account — technical setup only, no ongoing governance use | Assigned at deployment | 1 |
| 1 | Founding Members | Five permanent stewards; hold veto, emergency, and reform-proposal authority | Assigned at deployment, never change | 5 |
| 2 | Members | Former grantees admitted by Founding Members; drive elections and vote | Assigned by Founding Members | Unlimited |
| 3 | SlateRegistry | The SlateRegistry contract address; required for slate execution routing | Assigned at deployment | 1 (contract) |

> Role IDs 0 and type(uint256).max are reserved by the protocol.

---

## Governance Flows

### Flow A: Slate Election

**Purpose:** Distribute incoming yield every six months by having Members vote on competing funding slates.

**Steps:**

| Step | Mandate type | Who can call | Conditions |
|------|-------------|--------------|------------|
| 1 | `BespokeAction_Simple` → `slateRegistry.createElection` | Members (role 2) | Throttled: min 6 months between elections |
| 2 | `BespokeAction_Simple` → `slateRegistry.vote` | Members (role 2) | Within the SlateRegistry voting window |
| 3 | `StatementOfIntent` (Veto) | Founding Members (role 1) | Voting: 3-day period, 60% quorum, 51% threshold |
| 4 | `SlateRegistry_ExecuteResult` | Public (anyone) | `needNotFulfilled` = veto mandate; 4-day timelock |

**How the veto works:** After an election closes, anyone can propose execution of the results. Founding Members then have a 3-day window to vote (3 of 5 must agree) and execute a veto with the same `ElectionTitle` and nonce. The execution mandate has a 4-day timelock — longer than the veto window — so a successful veto lands before execution becomes possible.

> **Known limitation:** The veto blocks the *entire* election result (all winning slates), not individual slates. There is currently no protocol mechanism to selectively block one winning slate while permitting others.

**Rationale:** Slate voting (rather than per-candidate voting) lets members choose between complete programmes of action — bundles of specific transfers and calls — rather than endorsing abstract proposals. A six-month throttle ensures the endowment operates on a stable cycle without requiring any central scheduler. The founding-member veto on execution (rather than on submission) gives the widest possible voice to Members during the submission and voting stages, while preserving a safety brake for the Founding Members if a result is clearly wrong or harmful.

---

### Flow B: Slate Submission

**Purpose:** Allow Members to propose and withdraw funding slates during an election's submission window.

**Steps:**

| Step | Mandate type | Who can call | Conditions |
|------|-------------|--------------|------------|
| 1 | `SlateRegistry_AddSlate` | Members (role 2) | During election submission window |
| 2 | `SlateRegistry_RemoveSlate` | Members (role 2) | `needFulfilled` = Add Slate (same calldata + nonce); before voting opens |

**Rationale:** Only Members (past grantees) may propose slates. This ties proposal power to lived experience of receiving a grant, reducing capture by external parties. The withdraw mechanism uses the same-calldata-and-nonce linkage built into the protocol — only the original submitter can withdraw their own slate.

---

### Flow C: Mission Statement

**Purpose:** Allow Founding Members to collectively update the organisation's URI — the on-chain pointer to its name, description, and logo, which encodes the mission statement.

**Steps:**

| Step | Mandate type | Who can call | Conditions |
|------|-------------|--------------|------------|
| 1 | `StatementOfIntent` (Propose) | Founding Members (role 1) | Voting: 3-day period, 60% quorum, 51% threshold |
| 2 | `BespokeAction_Simple` → `powers.setUri` | Founding Members (role 1) | `needFulfilled` = proposal; 4-day timelock |

**Rationale:** The mission statement is a founding-level prerogative — it defines the endowment's purpose and should not be changeable by the general membership. Requiring a majority of Founding Members prevents any single founder from unilaterally rewriting the mission. The short timelock gives Members time to observe a proposed change before it takes effect, even though they cannot block it.

---

### Flow D: Membership

**Purpose:** Manage the lifecycle of Member accounts — admission, lapse, revocation, and voluntary exit.

**Steps:**

| Step | Mandate type | Who can call | Conditions |
|------|-------------|--------------|------------|
| 1 | `BespokeAction_Advanced` → `powers.assignRole(2, account)` | Founding Members (role 1) | No vote; immediate |
| 2 | `BespokeAction_Advanced` → `powers.revokeRole(2, account)` | Founding Members (role 1) | No vote; immediate |
| 3 | `StatementOfIntent` (Propose Lapse Sweep) | Founding Members (role 1) | Voting: 3-day period, 60% quorum, 51% threshold |
| 4 | `RevokeInactiveAccounts` | Founding Members (role 1) | `needFulfilled` = proposal (step 3) |
| 5 | `RenounceRole` | Members (role 2) | No vote; self-service |

**Membership admission:** Founding Members verify off-chain that an applicant received a grant, then call the Grant Membership mandate. There is no on-chain grant-receipt check — the verification is social and trusted to the Founding Members.

**Lapse sweep:** The `RevokeInactiveAccounts` mandate checks each current Member's participation in the last N governance actions. Members who haven't participated in at least 1 of the last 500 actions are revoked. This approximates annual lapse for a moderately active organisation. The 500-action window is a deploy-time constant; operators should adjust it if the organisation's activity level is much higher or lower than expected.

**Rationale:** Tying membership to grant receipt creates a meaningful barrier to entry — you must have received funding to govern. Annual lapse prevents the membership roll from accumulating inactive accounts over time, keeping quorum thresholds meaningful.

---

### Flow E: Governance Reform

**Purpose:** Allow the governance structure itself to evolve — adding new mandates or capabilities — through a bicameral proposal process where Founding Members initiate and Members ratify.

**Steps:**

| Step | Mandate type | Who can call | Conditions |
|------|-------------|--------------|------------|
| 1 | `StatementOfIntent` (Propose Reform) | Founding Members (role 1) | No vote; any single founder can propose |
| 2 | `StatementOfIntent` (Member Ratification) | Members (role 2) | `needFulfilled` = proposal; voting: 1-week period, 30% quorum, 51% threshold |
| 3 | `Adopt_Mandates` | Founding Members (role 1) | `needFulfilled` = ratification; 8-day timelock |

**Rationale:** Assigning proposal rights to Founding Members prevents the organisation from being steered by a temporary majority of Members. Requiring Member ratification prevents Founding Members from unilaterally rewriting governance. The 8-day timelock (longer than the 1-week voting window) ensures the community can observe an approved reform before it is committed. The 30% Member quorum reflects that Members are a distributed group with varying activity levels — a reasonable bar without being exclusionary.

---

### Flow F: Emergency Pause / Restart

**Purpose:** Allow any Founding Member to freeze or re-enable critical governance mandates in an emergency, without requiring a vote.

**Steps:**

| Step | Mandate type | Who can call | Conditions |
|------|-------------|--------------|------------|
| 1 | `PauseMandates` (`bool paused`) | Founding Members (role 1) | No vote; immediate |

**Targeted mandates:** Cast Vote (Flow A), Execute Results (Flow A), Add Slate (Flow B). Pausing these three freezes the election machinery entirely. Membership management and reform flows are not paused — the organisation can still admit members and propose structural fixes while elections are frozen.

**`paused = false` restarts** all targeted mandates from their original configuration — no parameter changes are possible during a pause cycle.

**Rationale:** Emergency powers without a restart mechanism create a governance trap. The `PauseMandates` mandate guarantees that whatever is frozen can be unfrozen, and the original configuration is preserved during the pause. Assigning this to Founding Members (not a single Admin) means any one of the five can act in an emergency without needing to reach consensus first — speed is the priority here.

---

## Checks and Balances

| Mechanism | How it works | Who holds it |
|-----------|-------------|--------------|
| Veto on election execution | Founding Members vote (3 of 5) within 3 days; blocks all winning slates | Founding Members (role 1) |
| 4-day execution timelock | Gap between propose and execute gives veto time to land | Automatic |
| 6-month throttle on elections | Minimum 6 months between Create Election calls | Automatic (throttleExecution) |
| Membership gate | Only past grantees can be Members; only Founding Members can admit | Founding Members (role 1) |
| Annual lapse sweep | Inactive Members can be swept by Founding Members majority vote | Founding Members (role 1) |
| Emergency pause | Any Founding Member can freeze election machinery instantly | Founding Members (role 1) |
| Reform bicameralism | Founders propose, Members ratify, 8-day timelock before adoption | Split between roles 1 and 2 |
| Mission statement control | URI changes require majority of Founding Members | Founding Members (role 1) |

**Security considerations:**
- If all 5 Founding Members lose their keys simultaneously, there is no recovery path — the organisation cannot reform itself. Consider off-chain key management procedures.
- The 6-month throttle is per-election, not per-calendar-interval. A new election can be opened as soon as the previous throttle expires, which may or may not align with a calendar cycle.
- The lapse sweep is manual and discretionary — Founding Members can choose not to run it. This is intentional (flexibility) but means inactive Members may accumulate if founders are inattentive.

---

## External Dependencies

| System | Purpose | Required? |
|--------|---------|----------|
| `SlateRegistry` helper contract | Manages elections, slate registration, vote tallying, and execution routing | Yes |
| `SlateRegistry_AddSlate` mandate contract | Deployed directly (not from registry) | Yes |
| `SlateRegistry_RemoveSlate` mandate contract | Deployed directly (not from registry) | Yes |
| `SlateRegistry_ExecuteResult` mandate contract | Deployed directly (not from registry) | Yes |

The treasury is internal — it lives inside the Powers contract itself. No Gnosis Safe, no external token contract.

---

## Design Rationale

The core tension in endowment governance is between **preservation** (the corpus must be protected, the mission must remain coherent over time) and **responsiveness** (the allocation of yield should reflect the evolving needs of the community it serves). This design resolves that tension by splitting authority rather than concentrating it.

Founding Members hold the levers that protect the institution: veto, emergency pause, mission statement, reform initiation. Members hold the levers that drive the institution: who submits slates, who votes, who gets funded. Neither group can act without the other on the most consequential decisions (reform requires both; elections require Members but can be vetoed).

The slate voting model (drawn from Ostrom's design principle of proportional rules for commons governance) is well-suited here because it shifts the unit of decision from "do you trust this person?" to "do you prefer this programme of action?" This makes the vote less personal and more outcome-oriented, which is appropriate for a funding organisation.

The permanent Founding Member structure is a deliberate trade-off against adaptive governance. It sacrifices long-term renewal in exchange for institutional stability during the endowment's formative years. If the founders wish to rotate membership in the future, they can propose a Governance Reform that adopts new electoral mandates for role 1.

---

## Limitations

- **No per-slate veto:** The founding member veto covers the entire election result. Individual winning slates cannot be selectively blocked.
- **No on-chain grant verification:** Membership admission relies on off-chain verification by Founding Members that an applicant received a grant. This is a social trust requirement, not a technical one.
- **No Founding Member rotation:** The five founding addresses are set at deployment and cannot be changed without a Governance Reform that adopts a new membership mandate for role 1.
- **Lapse sweep is approximate:** `RevokeInactiveAccounts` checks participation across the last N total contract actions, not calendar time. The 500-action window is a reasonable default but may need tuning.
- **Treasury is unguarded:** Funds held by the Powers contract can be disbursed via any winning slate. There is no Safe-level multisig as an additional layer. This is appropriate for the intended scale but should be reconsidered for large corpora.

---

## Metadata URI

**Status: TBD** — No URI was provided. A placeholder (`""`) is used in the deploy script. Before deploying, upload a JSON file to [Pinata](https://pinata.cloud) (free tier available) containing at minimum `name`, `description`, and optionally `image` fields, then paste the resulting gateway URL into the Powers constructor in `Deploy.s.sol`.

---

## Implementation Notes

- **Deploy script:** `solidity/governance/claude/yield-endowment/Deploy.s.sol`
- **Actions script:** `solidity/governance/claude/yield-endowment/Actions.s.sol`
- **Runners script:** `solidity/governance/claude/yield-endowment/Runners.s.sol`
- **Test file:** `solidity/governance/claude/yield-endowment/Test.t.sol`
- **Mandate version:** MAJOR=0, MINOR=1, PATCH = 9
- **Mandate nameDescription strings must match exactly across all four files.**
- **Founder addresses:** Replace `FOUNDER_1` through `FOUNDER_5` constants in `Deploy.s.sol` with the real addresses before deploying.
- **SlateRegistry timing:** Set `submitSlateDuration` and `voteDuration` to production values (2-week each) in `Deploy.s.sol`. Test files use accelerated timing (~30 min each).
