# Staking Pool Governance — Governance Specification

> **Status:** Approved
> **Network:** Sepolia / Arbitrum Sepolia / Optimism Sepolia (testnets)
> **Design date:** 2026-07-11

---

## ⚠️ Regulatory status — READ FIRST

**This is a demonstration / reference governance design. It is NOT a UK-compliant
production system, and nothing here is legal advice.**

Regulatory compliance for a staking product attaches to the **activity and the entity** —
not to how these governance mandates are wired. Offering staking and rewards to UK
persons may engage the FCA cryptoasset regime, the s21 FSMA financial-promotions
restriction, the Money Laundering Regulations, and related rules; this area is evolving.
A governance layer **cannot** make an otherwise-regulated product lawful. Obtain
qualified UK financial-services / crypto counsel before any real-money use.

Specific limitations of what this design can achieve:

- The target `SimpleStakingPool` is a self-described **demo/mock** ("not audited for
  production use").
- The pool's `stake()` / `unstake()` / `claim()` are **permissionless**, so governance
  **cannot KYC- or geo-gate stakers**. Eligibility control of stakers would require
  changes to the pool contract itself, not the governance layer.
- The **Compliance Monitor** role below is a *risk-reducing* measure only — a substitute
  neither for an authorised compliance function nor for legal advice.

---

## Purpose

This organisation governs a `SimpleStakingPool` — an on-chain staking pool where users
stake one ERC-20 and earn another at a governance-settable reward rate. Powers becomes
the pool's owner and drives its four privileged (`onlyOwner`) knobs — the reward rate,
emergency pause, token sweep, and reward funding — through mandates, distributing those
powers across five roles with deliberate checks and balances so no single party can
unilaterally move funds or change economic policy.

---

## Roles

| Role ID | Name | Description | How to join | Max members |
|---------|------|-------------|-------------|-------------|
| 0 | Admin | Founding administrator; bootstraps the system, appoints Guardian & Monitor, acts as backstop | Assigned at deployment | 1 (small) |
| max | Public | Everyone; may nominate to become a Staker | Automatic | Unlimited |
| 1 | Stakers | The community. Deliberate on economic policy, hold the veto, vote to un-pause, govern reform | Peer election (+ Admin bootstrap at genesis) | Unlimited |
| 2 | Rate Committee | Economic stewards. Propose and execute rate changes and sweeps (never without surviving veto + timelock) | Elected by Stakers | ~3 |
| 3 | Guardian | Emergency circuit-breaker. Can instantly pause (only) | Appointed by Admin | Small |
| 4 | Compliance Monitor | Records on-chain compliance findings (signal-only); shares the instant-pause trip | Appointed by Admin | Small |

Helper contracts: two `Nominees` registries (Staker and Committee elections) and a
`PowersPaymaster` (gasless participation). All are owned by Powers after deployment.

---

## Governance Flows

### Flow 1: Staker Membership

**Purpose:** admit and remove voting members.

| Step | Mandate | Who | Voting? | Conditions |
|------|---------|-----|---------|------------|
| 1 | Nominate | Public | No | Self-nominate into the Staker nominee pool |
| 2 | PeerSelect → role 1 | Stakers | Yes — 30% quorum, 51%, 1 week | Elects up to 5; one-time, self-revoking; `maxExecutionDelay` = 1 week |
| 3 | RenounceRole | Stakers | No | Credible exit |

**Rationale:** peer election gives members accountability to the community that elected
them (Ostrom polycentricity). Elected-only membership can stall, so genesis Stakers are
seeded by the Admin (Flow 3) — the anti-stall bootstrap from Carlisle & Gruby (2019). A
free exit path preserves the credible-exit property (Ostrom 2009).

### Flow 2: Elect Rate Committee

| Step | Mandate | Who | Voting? | Conditions |
|------|---------|-----|---------|------------|
| 1 | Nominate | Stakers | No | Self-nominate for the Committee |
| 2 | PeerSelect → role 2 | Stakers | Yes — 30%/51%/1 week | Elects up to 3; `maxExecutionDelay` = 1 week |

**Rationale:** the economic stewards answer to the Stakers who elect them.

### Flow 3: Admin Role Administration

| Step | Mandate | Who | Voting? | Conditions |
|------|---------|-----|---------|------------|
| 1 | BespokeAction → assignRole | Admin | No | Assign Guardian(3), Monitor(4), or genesis Staker(1) |
| 2 | BespokeAction → revokeRole | Admin | No | `needFulfilled` = step 1 |

### Flow 4: Set Reward Rate

| Step | Mandate | Who | Voting? | Conditions |
|------|---------|-----|---------|------------|
| 1 | StatementOfIntent (propose) | Rate Committee | Yes — 30%/51%/1 week | — |
| 2 | StatementOfIntent (veto) | Stakers | Yes — 30%/51%/**24h** | `needFulfilled` = step 1 |
| 3 | BespokeAction → `pool.setRewardRate` | Rate Committee | No | `needFulfilled`=1, `needNotFulfilled`=2, **timelock 48h** |

**Rationale:** the Committee proposes, but the Stakers hold a fast veto (short window for
rapid access — Carlisle & Gruby), and a 48h timelock (> the 24h veto window) guarantees
the community has time to block before the change lands.

### Flow 5: Emergency Pause / Un-pause

| Step | Mandate | Who | Voting? | Conditions |
|------|---------|-----|---------|------------|
| 1 | BespokeAction_Advanced → `setPaused(true)` | Guardian | No | Instant; can *only* pause |
| 2 | BespokeAction_Advanced → `setPaused(true)` | Compliance Monitor | No | Instant; shared trip on a finding |
| 3 | BespokeAction_Advanced → `setPaused(false)` | Stakers | Yes — 30%/51%/48h | Deliberate un-pause |

**Rationale:** a fast, one-directional pause with a deliberate un-pause — off-cycle
emergency power should be hard to make permanent (Delaware DGCL reasoning). Unstaking and
claiming stay open while paused, so user funds are never trapped.

### Flow 6: Compliance Monitoring

| Step | Mandate | Who | Voting? | Conditions |
|------|---------|-----|---------|------------|
| 1 | StatementOfIntent (flag) | Compliance Monitor | No | Records a finding on-chain; **no execution** |

**Rationale:** continuous, narrow monitoring that feeds the periodic Staker votes and can
justify a Monitor pause — the two-cadence accountability pattern from the UK CIC / Swiss
AG sources.

### Flow 7: Sweep Stray Tokens

| Step | Mandate | Who | Voting? | Conditions |
|------|---------|-----|---------|------------|
| 1 | StatementOfIntent (propose) | Rate Committee | Yes — 30%/51%/1 week | — |
| 2 | StatementOfIntent (veto) | Stakers | Yes — 30%/51%/48h | `needFulfilled` = 1 |
| 3 | BespokeAction → `pool.sweep` | Rate Committee | No | `needFulfilled`=1, `needNotFulfilled`=2, **timelock 7 days** |

**Rationale:** the highest-risk action (moving tokens out) gets the same veto structure
as rate changes plus a much longer timelock. `sweep` cannot touch staked principal (the
pool enforces this).

### Flow 8: Governance Reform

| Step | Mandate | Who | Voting? | Conditions |
|------|---------|-----|---------|------------|
| 1 | StatementOfIntent (propose) | Stakers | Yes — **50%/66%**/2 weeks | Supermajority |
| 2 | Adopt_Mandates | Stakers | No | `needFulfilled`=1, timelock 15 days |

**Rationale:** the people governed by the rules control the rules (Ostrom Design
Principle 3), at the highest bar in the constitution.

### Flows 9–10: Paymaster (gasless)

Fund and withdraw ETH to/from the `PowersPaymaster`, gated to the Rate Committee, so
members can participate without holding ETH.

---

## Checks and Balances

| Mechanism | How it works | Who holds it |
|-----------|-------------|--------------|
| Rate/sweep veto | Stakers block a Committee proposal within the veto window | Stakers (role 1) |
| Timelock | 48h (rate) / 7 days (sweep) before execution | Automatic |
| Fast pause / deliberate un-pause | Guardian & Monitor pause instantly; only a Staker vote un-pauses | Guardian(3), Monitor(4) / Stakers(1) |
| Reform supermajority | 50% quorum, 66% threshold, 15-day timelock | Stakers (role 1) |
| Stale-state bound | Quorum-gated elections set `maxExecutionDelay` ≈ voting period | Automatic |

**Security considerations:** Governance cannot gate who stakes (permissionless pool). The
Compliance Monitor is signal-only plus a pause trip; it holds no treasury power.

---

## External Dependencies

| System | Purpose | Required? |
|--------|---------|----------|
| SimpleStakingPool | The governed protocol (Powers is its owner) | Yes |
| Two mock ERC-20 tokens | Staking + reward tokens (demo) | Yes (demo) |
| Nominees × 2 | Candidate registries for the two elections | Yes |
| PowersPaymaster | Gasless (ERC-4337) participation | Yes |

---

## Design Rationale

The design distributes the pool's four privileged knobs by risk and tempo: economic
policy is deliberate (propose → veto → timelock), emergencies are fast but one-directional
(pause), and the most dangerous action (sweep) carries the strongest brake. Membership and
the Committee are elected for accountability, reform sits with the affected role, and a
signal-only Compliance Monitor provides continuous oversight. Grounded in Ostrom (2009),
Carlisle & Gruby (2019), Delaware DGCL, and the UK CIC guidance.

---

## Limitations

- **`fundRewards` is not a governed flow.** It pulls tokens from the owner (Powers) via
  `transferFrom`, which would require Powers to self-approve. Because `rewardReserve()`
  reads `REWARD_TOKEN.balanceOf(pool)`, the reserve is instead funded by transferring
  reward tokens **directly to the pool** — simpler and permissionless.
- **Membership is not stake-weighted** — no mandate reads the pool's `stakedBalance`.
- **Not UK-compliant / demo pool** — see § Regulatory status. Sweep allow-list, wind-down
  successor path, and extended legibility docs were considered but not included; they
  remain available as future measures.

---

## Implementation Notes

- Deploy: `Deploy.s.sol` · Actions: `Actions.s.sol` · Runners: `Runners.s.sol` · Test: `Test.t.sol`
- Mandate version: MAJOR=0, MINOR=1, PATCH=8
- Mandate `nameDescription` strings must match exactly across all four files.
- Tests run against a Sepolia fork; discovery requires pointing Foundry at this folder
  (`FOUNDRY_TEST=governance/staking-pool-governance`) — the Makefile does this for you.
