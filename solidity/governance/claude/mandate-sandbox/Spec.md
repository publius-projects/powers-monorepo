---
title: "Mandate Sandbox — Governance Specification"
description: "Governance design specification for Mandate Sandbox"
---

# Mandate Sandbox — Governance Specification

> **Status:** Draft
> **Network:** Arbitrum Sepolia (421614)
> **Design date:** 2026-06-24

---

## Purpose

Mandate Sandbox is not a real-world organisation — it exists purely to exercise every `Conditions` field (`allowedRole`, `votingPeriod`, `quorum`, `succeedAt`, `timelock`, `throttleExecution`, `needFulfilled`, `needNotFulfilled`) against real on-chain state on Arbitrum Sepolia, using a small, familiar set of mandate types rather than the full mandate catalogue. The goal is condition coverage, not mandate-type coverage. Voting periods and timelocks are deliberately short so a single person can walk through every flow in one sitting.

---

## Roles

| Role ID | Name | Description | How to join | Max members |
|---------|------|-------------|-------------|-------------|
| 0 | Admin | Founding administrator, highest trust; vetoes proposed actions | Assigned at deployment | 1 |
| max | Public | Everyone; no application needed | Automatic | Unlimited |
| 1 | Member | Base membership; proposes actions | SelfSelect (open) | Unlimited |
| 2 | Council | Trusted executor; assigned directly at deployment | Assigned at deployment | 1 |

---

## Governance Flows

### Flow 1: Membership

**Purpose:** The simplest possible mandate — a single condition (`allowedRole = Public`) and nothing else. The baseline every other flow is compared against.

| Step | Mandate type | Who can call | Voting? | Conditions exercised |
|------|-------------|--------------|---------|----------------------|
| 1 | SelfSelect | Public | No | `allowedRole` only |

**Rationale:** Establishes the control case: no vote, no timelock, no dependency — just role-gating.

---

### Flow 2: Optimistic Execution

**Purpose:** One propose → veto-window → execute chain that exercises `votingPeriod`, `quorum`, `succeedAt`, `needFulfilled`, `needNotFulfilled`, and `timelock` — six of the eight condition fields — in a single, easy-to-follow sequence.

| Step | Mandate type | Who can call | Voting? | Conditions exercised |
|------|-------------|--------------|---------|----------------------|
| 1 | StatementOfIntent (propose) | Member (role 1) | Yes — 20% quorum, 51% succeedAt, 10 min voting period | `allowedRole`, `votingPeriod`, `quorum`, `succeedAt` (isolated — no dependency on any other mandate) |
| 2 | StatementOfIntent (veto) | Admin (role 0) | No | `needFulfilled` = step 1 (isolated — this is the only condition set on this mandate) |
| 3 | OpenAction (execute) | Council (role 2) | No | `needFulfilled` = step 1, `needNotFulfilled` = step 2, `timelock` = 20 min (> step 1's 10 min voting period) |

**Rationale:** Each step isolates a different combination of fields so it's easy to tell, when something doesn't behave as expected in the frontend, which condition is responsible. The timelock-exceeds-voting-period rule from the mandate catalogue's veto pattern is demonstrated directly.

---

### Flow 3: Throttled Action

**Purpose:** Exercise `throttleExecution` on its own, with no vote and no dependency, so its cooldown behaviour is visible in isolation.

| Step | Mandate type | Who can call | Voting? | Conditions exercised |
|------|-------------|--------------|---------|----------------------|
| 1 | BespokeAction_Simple → `ReturnDataMock.consume(uint256)` | Public | No | `allowedRole`, `throttleExecution` = 50 blocks (~10 min on Arb Sepolia) |

**Rationale:** `ReturnDataMock` is a trivial, already-existing test contract (`getValue()` returns `42`, `consume(uint256)` just emits an event) — it adds no conceptual weight of its own, so the only thing being tested is the throttle's cooldown timer. Calling it repeatedly in the frontend within the cooldown window should visibly fail; waiting past it should succeed.

---

### Flow 4: Account Abstraction

**Purpose:** Gasless transaction support via `PowersPaymaster`. Reuses only mandate types already introduced above (`StatementOfIntent`, `PresetActions`, `BespokeAction_Simple`) — no new condition types, just a real-world use of the propose/execute pattern from Flow 2.

| Step | Mandate type | Who can call | Voting? | Conditions exercised |
|------|-------------|--------------|---------|----------------------|
| 1 | StatementOfIntent (propose fund) | Admin (role 0) | Yes — 20% quorum, 51% succeedAt, 5 min | `votingPeriod`, `quorum`, `succeedAt` |
| 2 | PresetActions (execute fund) | Admin (role 0) | No | `needFulfilled` = step 1; sends 0.05 ETH to `powersPaymaster.deposit()` |
| 3 | StatementOfIntent (propose withdraw) | Admin (role 0) | Yes — 20% quorum, 51% succeedAt, 5 min | Caller supplies `address withdrawAddress, uint256 amount` |
| 4 | BespokeAction_Simple (execute withdraw) | Admin (role 0) | No | `needFulfilled` = step 3; calls `powersPaymaster.withdrawTo(address,uint256)` |

**Rationale:** Included because gasless UX is a distinct frontend concern worth testing in person, but it deliberately doesn't introduce any mandate type or condition field not already covered above.

---

## Checks and Balances

| Mechanism | How it works | Who holds it |
|-----------|-------------|--------------|
| Veto on Optimistic Execution | Admin can block within step 1's 10-minute voting window; executor's timelock is 20 minutes, exceeding it | Admin (role 0) |
| Quorum + succeedAt | 20% quorum / 51% succeedAt on every voted mandate | Member / Admin per flow |
| Cooldown | `throttleExecution` (50 blocks) prevents rapid repeat calls to Flow 3 | Automatic |

**Security considerations:**
- This is a test sandbox, not a production governance design. `OpenAction` (Flow 2, step 3) gives Council the ability to call *anything* once conditions are met — intentionally permissive so the timelock/veto mechanics are easy to observe, not something a real organisation should do without much stronger guarantees.

---

## External Dependencies

| System | Purpose | Required? |
|--------|---------|----------|
| `ReturnDataMock` (deployed fresh) | Throttle-only demo target for Flow 3 | Yes |
| `PowersPaymaster` (deployed fresh) | Account abstraction (Flow 4) | Yes |

---

## Design Rationale

The original draft of this spec tried to exercise every mandate *type* in the catalogue (electoral, executive, reform, every integration) and ballooned to 15 flows and 11 roles. That was the wrong axis: most mandate types just relabel the same eight `Conditions` fields with different execution targets. This revision instead picks the smallest set of mandate types (`SelfSelect`, `StatementOfIntent`, `OpenAction`, `BespokeAction_Simple`, `PresetActions`) that can express every condition field, and isolates each field (or the smallest meaningful combination) in its own mandate so behaviour is easy to attribute when testing in the frontend.

## Limitations

- This spec does **not** attempt to cover the mandate catalogue's electoral, reform, or integration mandates (`PeerSelect`, `DelegateTokenSelect`, `Adopt_Mandates`, `Safe_*`, `Governor_*`, `ElectionRegistry_*`, `SlateRegistry_*`, etc.). If you later want to test a *specific* mandate type's UI/UX in the frontend, it can be added as an additional flow via this same deploy script without disturbing the condition-coverage flows above.
- `OpenAction` (Flow 2) is unrestricted in what it can call — fine for a sandbox, not a pattern to copy into a real organisation without much stronger safeguards.

## Metadata URI

`TBD` — no metadata URI was supplied. The deploy script will use an empty string with a `// TODO: set metadata URI before deploying` comment.

## Account Abstraction

A `PowersPaymaster` will be deployed alongside Mandate Sandbox and seeded with **0.05 ETH** at deployment. The deployer wallet must hold at least 0.05 ETH plus gas on Arbitrum Sepolia at deploy time. Admin (role 0) governs the Fund Paymaster and Withdraw from Paymaster flows (Flow 4).

---

## Implementation Notes

> This section is for the developer implementing the deploy script.

- **Deploy script:** `solidity/governance/mandate-sandbox/Deploy.s.sol`
- **Actions script:** `solidity/governance/mandate-sandbox/Actions.s.sol`
- **Runners script:** `solidity/governance/mandate-sandbox/Runners.s.sol`
- **Test file:** `solidity/governance/mandate-sandbox/Test.t.sol`
- **Mandate version:** MAJOR=0, MINOR=1, PATCH = 9
- **Network:** Arbitrum Sepolia (chainId 421614)
- Mandate `nameDescription` strings must match exactly across Deploy/Actions/Runners.
