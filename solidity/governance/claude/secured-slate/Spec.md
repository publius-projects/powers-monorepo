---
title: "Secured Slate Governance — Governance Specification"
description: "Governance design specification for Secured Slate Governance"
---

# Secured Slate Governance — Governance Specification

> **Status:** Draft
> **Network:** Sepolia / Arb Sepolia / Opt Sepolia / Anvil
> **Design date:** 2026-06-08

---

## Purpose

Secured Slate Governance is a treasury management organisation that governs how a sizeable ETH
treasury and protocol income are spent. All governance decisions are packaged as competitive
*slates* — bundles of on-chain calls — that any account can propose. A Security Council vets
slates before voting opens. Members then vote, and winning slates execute automatically.

---

## Roles

| Role ID | Name | Description | How to join | Max members |
|---------|------|-------------|-------------|-------------|
| 0 | Admin | Deployment administrator; inactive after setup | Assigned at deployment | 1 |
| type(uint256).max | Public | Everyone; no application needed | Automatic | Unlimited |
| 1 | Members | Vote on slate elections; onboard new members | Peer vote (2% quorum, 51% majority) | Unlimited (~50–200 expected) |
| 2 | Security Council | Vet slates; manage blacklist; pause emergency controls | Pre-assigned at deployment | 3 |
| 3 | SlateRegistry | Internal role for the SlateRegistry contract | Pre-assigned at deployment | 1 |
| 4 | Blacklisted | Accounts marked for misconduct | Security Council action | Unlimited |

**Bootstrap note:** The deployer is assigned as the first Member during initial setup, so the
member-vote flow works immediately. The deployer can renounce the role after seeding additional
members.

**Security Council addresses (pre-assigned):**
- `0x3F46F636F78929a4336de0a435E3930092900f06`
- `0xa221eB405d87B624be08fAbf949F05D19C765f68`
- `0x7507F9F06103D7D462DaE11C0A6f4A415c69DcF9`

---

## Governance Flows

### Flow A: Slate Elections

**Purpose:** The primary decision mechanism. Members open grant elections; members cast votes for
competing slates; winning slates execute automatically.

| Step | Mandate type | Who can call | Voting? | Conditions |
|------|-------------|--------------|---------|------------|
| 1 | BespokeAction_Simple → slateRegistry.createElection | Members (role 1) | No | Throttled: one election per 30 min |
| 2 | BespokeAction_Simple → slateRegistry.vote | Members (role 1) | No | Timing enforced by SlateRegistry |
| 3 | SlateRegistry_ExecuteResult | Public | No | Only callable after voting window closes |

**Rationale:** Timing enforcement (submission window, voting window) is handled entirely inside the
SlateRegistry contract rather than via Powers voting parameters. This keeps the slate submission
and voting periods cleanly separated and prevents double-voting at the contract level.

---

### Flow B: Slate Submission

**Purpose:** Anyone can propose a slate of actions; the Security Council can remove unsuitable
slates before the voting window opens.

| Step | Mandate type | Who can call | Voting? | Conditions |
|------|-------------|--------------|---------|------------|
| 1 | SlateRegistry_AddSlate | Public | No | Only during submission window |
| 2 | SlateRegistry_RemoveSlate | Security Council (role 2) | No | Requires same calldata/nonce as step 1 |

**Rationale:** The "optimistic vetting" model — submit freely, let the Security Council remove
problems — keeps the proposal process open while maintaining an integrity check. The
`needFulfilled` link between Add and Remove ensures the Security Council's removal action
uniquely identifies the original submission (same calldata + nonce), preventing them from
removing slates they did not track.

**Slates can include any on-chain call**, including calls to `Powers.adoptMandate` or
`Powers.revokeMandate`, making governance reform possible through the standard slate process
without a dedicated reform flow. The Security Council's slate veto is the safety check on this.

---

### Flow C: Member Management

**Purpose:** Members vote to onboard new members. Members can also voluntarily renounce their role.

| Step | Mandate type | Who can call | Voting? | Conditions |
|------|-------------|--------------|---------|------------|
| 1 | StatementOfIntent | Members (role 1) | Yes — 2% quorum, 51% majority, 30 min | — |
| 2 | BespokeAction_Simple → assignRole(1, account) | Members (role 1) | No | Must have step 1 for same account |
| — | RenounceRole | Members (role 1) | No | Caller only (exit right) |

**Rationale:** The 2% quorum deliberately keeps the membership bar low — even a handful of active
members can onboard someone. The `needFulfilled` link in step 2 ensures execution can only happen
after the vote has passed and been recorded. Renounce is an unconditional exit right, consistent
with Ostrom's Design Principle 1 (clear user boundaries, including exit).

---

### Flow D: Blacklist Management

**Purpose:** The Security Council can mark accounts for misconduct, separately revoke their voting
rights, and lift the blacklist.

| Step | Mandate type | Who can call | Voting? | Conditions |
|------|-------------|--------------|---------|------------|
| 1 | BespokeAction_Advanced → assignRole(4, account) | Security Council (role 2) | No | — |
| 2 | BespokeAction_Advanced → revokeRole(1, account) | Security Council (role 2) | No | Step 1 must exist for same account |
| 3 | BespokeAction_Advanced → revokeRole(4, account) | Security Council (role 2) | No | — |

**Two-step design:** Blacklisting (step 1) and revoking membership (step 2) are separate actions.
This prevents a blacklisted account from having a "dead vote" while the Security Council decides
what to do, and also means the Security Council must explicitly revoke membership — they cannot
accidentally remove a non-blacklisted member.

**De-blacklisting (step 3)** removes only the Blacklisted mark. To restore membership, the account
must go through the normal member onboarding vote (Flow C).

---

### Flow E: Emergency Controls

**Purpose:** The Security Council can pause or restart three critical mandates in an emergency.

| Step | Mandate type | Who can call | Conditions |
|------|-------------|--------------|------------|
| 1 | PauseMandates | Security Council (role 2) | `paused=true` to pause; `paused=false` to restart |

**Mandates that can be paused:**
- Cast Vote (Flow A, position 1)
- Execute Results (Flow A, position 2)
- Add Slate (Flow B, position 0)

Pausing these freezes the election machinery without touching member management or the blacklist
flows. `PauseMandates` also provides a guaranteed restart path — restarting re-adopts mandates
with their original configs, so the Security Council cannot quietly modify governance parameters
during a pause.

---

## Checks and Balances

| Mechanism | How it works | Who holds it |
|-----------|-------------|--------------|
| Slate veto | Security Council removes slates before voting opens | Security Council (role 2) |
| No council vote | Security Council has no voting role on slates | Automatic (role not Members) |
| Election throttle | One election every 30 minutes | Automatic (throttleExecution) |
| Two-step blacklist | Blacklisting and membership revocation are separate actions | Security Council (role 2) |
| Emergency pause | Security Council can freeze Cast Vote, Execute Results, Add Slate | Security Council (role 2) |
| Low-barrier membership | 2% quorum and simple majority for member onboarding | Members (role 1) |
| Voluntary exit | Members can renounce their own role | Members (role 1) |
| Reform via slates | Governance changes go through the same slate process | Subject to Security Council veto |

**Security considerations:**
- If all three Security Council members are compromised simultaneously, they could veto all slates
  and pause the election machinery. Reform in that case would require a contract upgrade.
- The Security Council cannot unilaterally execute any treasury action — they can only block others.
- A blacklisted member retains voting rights until the Security Council explicitly calls step 2 of
  Flow D. This is by design (two-step accountability; see Podger Ch 7).

---

## External Dependencies

| System | Purpose | Required? |
|--------|---------|----------|
| SlateRegistry helper contract | Manages election state, vote tallying, slate registration | Yes |
| SlateRegistry_AddSlate mandate | Adopts PresetActions per slate | Yes |
| SlateRegistry_RemoveSlate mandate | Removes/revokes a slate | Yes |
| SlateRegistry_ExecuteResult mandate | Triggers winning slate execution after voting closes | Yes |

No Gnosis Safe or external token is required. ETH is held directly in the Powers contract.

---

## Design Rationale

This structure implements what Carlisle & Gruby (2019) call a *polycentric* governance system with
genuine functional separation: Members decide (vote on slates); the Security Council provides
integrity oversight (vetting, emergency controls, blacklisting); the SlateRegistry contract
provides mechanical fairness (timing, anti-double-vote).

The optimistic vetting model (submit freely, Security Council removes bad actors) draws from
Podger et al. (2020) on the balance between *conformity* (integrity gate) and *flexibility*
(open proposal right). The Security Council's scope is deliberately narrow — they can block and
pause, but cannot spend or reform unilaterally.

The two-step blacklist design follows the "graduated sanctions" principle (Ostrom, Design Principle
5) — marking an account and removing their voting rights are distinct enforcement steps, which
reduces the risk of accidental or hasty exclusion.

Governance reform is routed through the same slate process rather than a dedicated admin mandate,
because restricting reform to admin-only roles violates Ostrom's Design Principle 3 (collective
choice arrangements must include affected roles). The Security Council's veto over slates is
sufficient to block malicious reforms without requiring admin supremacy.

---

## Limitations

- **No token-weighted governance.** Powers uses flat one-account-one-vote. If weighted influence
  is needed in future, member selection can be changed to `DelegateTokenSelect` via a governance
  reform slate.
- **No on-chain blocklist for non-members.** The Blacklisted role (4) only affects accounts that
  hold the Member role. Public (non-member) accounts submitting slates cannot be blocked at the
  Powers protocol level — the Security Council's slate removal is the only check on Public
  submissions.
- **Election timing is non-adjustable after deployment.** The SlateRegistry's `submitSlateDuration`
  and `voteDuration` are immutable after construction. Changing them requires deploying a new
  SlateRegistry and adopting new election mandates via a governance reform slate.
- **Test deployment timing.** The deployed parameters use 20-minute submission and 30-minute voting
  windows (≈ 10× speed-up for testing). Replace with `minutesToBlocks(2 * 24 * 60, ...)` and
  `minutesToBlocks(3 * 24 * 60, ...)` for production.

---

## Implementation Notes

- **Deploy script:** `solidity/governance/examples/SecuredSlate/SecuredSlate.s.sol`
- **Actions script:** `solidity/governance/examples/SecuredSlate/actions/SecuredSlateActions.s.sol`
- **Runners script:** `solidity/governance/examples/SecuredSlate/actions/SecuredSlateRunners.s.sol`
- **Test file:** `solidity/test/governance/SecuredSlate.t.sol`
- **Mandate version:** MAJOR=0, MINOR=1, PATCH = 9
- **nameDescription strings must match exactly across all four files.**
- **PauseMandates targets:** Flow 0 positions 1 and 2 (Cast Vote, Execute Results); Flow 1 position 0 (Add Slate).
