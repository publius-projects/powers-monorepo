---
title: "Project Orange — Governance Specification"
description: "Governance design specification for Project Orange"
---

# Project Orange — Governance Specification

> **Status:** Draft  
> **Network:** Arbitrum Sepolia (primary); Ethereum Sepolia / Optimism Sepolia also supported  
> **Design date:** 2026-06-12

---

## Purpose

Project Orange is an on-chain organisation devoted to all things orange — the colour, the fruit, the vibe. It holds a treasury in ETH and funds proposals that spread the gospel of orange while generating returns. Anyone from the public may submit a funding proposal; a group of three devoted members votes unanimously to approve or reject it. Approved funds are transferred directly from the Powers contract treasury to the project's nominated recipient.

---

## Roles

| Role ID | Name | Description | How to join | Members |
|---------|------|-------------|-------------|---------|
| 0 | Admin | Emergency authority; can veto any approved proposal before execution | Assigned to deployer at deploy time | 1 (deployer) |
| 1 | Member | Votes on funding proposals; must unanimously agree | Pre-assigned at deployment | 3 (fixed addresses) |
| max | Public | Anyone; no application needed | Automatic | Unlimited |

**Pre-assigned Member addresses:**
- `0x3F46F636F78929a4336de0a435E3930092900f06`
- `0xa221eB405d87B624be08fAbf949F05D19C765f68`
- `0x3cc18745C907979BdF19e6F2B5f243416eeaBba1`

There is no membership management flow; the three Member accounts are fixed at deployment and can only be changed through the Governance Reform flow.

---

## Governance Flows

### Flow 1: Fund a Project

**Purpose:** The core governance process. Anyone from the public submits a funding request encoding a recipient address and ETH amount. All three Members must unanimously vote to approve it. The Admin has a window after approval to veto before funds move.

**Steps:**

| Step | Mandate type | Who can call | Voting? | Conditions |
|------|-------------|--------------|---------|------------|
| 1 | StatementOfIntent | Public (anyone) | No | — |
| 2 | StatementOfIntent | Members (role 1) | Yes — 100% quorum, 100% must agree; **5 min demo / 3 days production** | Must follow Step 1 (same proposal + nonce) |
| 3 | StatementOfIntent (admin veto) | Admin (role 0) | No | Must follow Step 2; blocks execution |
| 4 | OpenAction | Members (role 1) | No | Must follow Step 2; must NOT have Step 3; **10 min demo / 4-day timelock** |

**Technical note — input parameters:** All four steps share the same calldata schema: `address[] Targets, uint256[] Values, bytes[] Calldatas, string ProposalDescription`. This allows the public to attach a human-readable description to their funding request that is carried through every step and is part of the on-chain record. For a simple ETH transfer from the treasury to a recipient:
- `Targets = [recipientAddress]`
- `Values = [amountInWei]`
- `Calldatas = [0x]` (empty — triggers the recipient's receive function)
- `ProposeDescription = "We're building an orange juice stand at Zuccotti Park..."`

The frontend presents this as a plain form (recipient, amount, description); the ABI encoding happens automatically. The execution mandate (Step 4, OpenAction) decodes only the first three fields at runtime; the trailing `string ProposalDescription` is part of the calldata but not used for execution — it exists solely as the on-chain proposal record.

**Rationale:** Unanimity (100% quorum, 100% succeedAt) means any single Member can block a proposal simply by voting against — satisfying the design requirement that one dissenter is sufficient to reject. The Admin veto adds a last-resort safety layer during the timelock window, catching errors or suspicious activity that the Members may have missed. Separating the public proposal step from the member vote step preserves the optimistic structure: proposals are cheap to submit, expensive to approve.

The veto pattern follows Ostrom's design principle of graduated sanctions — the Admin veto is a high-trust, high-accountability intervention available only after the membership has already agreed, not as a first-line filter.

---

### Flow 2: Governance Reform

**Purpose:** Allows Members to adopt new mandates, evolving the organisation's governance capabilities over time.

**Steps:**

| Step | Mandate type | Who can call | Voting? | Conditions |
|------|-------------|--------------|---------|------------|
| 1 | StatementOfIntent | Members (role 1) | Yes — 100% quorum, 100% agree; **5 min demo / 3 days production** | — |
| 2 | Adopt_Mandates | Members (role 1) | No | Must follow Step 1; **10 min demo / 4-day timelock** |

**Rationale:** Governance changes require the same unanimous threshold as funding decisions. This prevents any two Members from altering the constitutional rules over the objection of the third. The timelock gives Admin a window to intervene if reform is used inappropriately.

---

### Flow 3: Fund Paymaster *(Account Abstraction)*

**Purpose:** Allows Admin to top up the `PowersPaymaster` contract so Members and the public can continue to interact without paying gas.

**Steps:**

| Step | Mandate type | Who can call | Voting? | Conditions |
|------|-------------|--------------|---------|------------|
| 1 | StatementOfIntent | Admin (role 0) | No | — |
| 2 | PresetActions | Admin (role 0) | No | Must follow Step 1 |

Step 2 sends a fixed `0.05 ETH` deposit to the paymaster. Amount is pre-configured; repeat the two-step flow to top up again.

---

### Flow 4: Withdraw from Paymaster *(Account Abstraction)*

**Purpose:** Allows Admin to recover ETH from the paymaster if needed.

**Steps:**

| Step | Mandate type | Who can call | Voting? | Conditions |
|------|-------------|--------------|---------|------------|
| 1 | StatementOfIntent | Admin (role 0) | No | Input: `address WithdrawAddress, uint256 Amount` |
| 2 | BespokeAction_Simple | Admin (role 0) | No | Must follow Step 1; calls `powersPaymaster.withdrawTo(address,uint256)` |

---

## Checks and Balances

| Mechanism | How it works | Who holds it |
|-----------|-------------|--------------|
| Unanimity rule | All three Members must vote FOR; a single AGAINST or absent vote kills the proposal | Members (role 1) |
| Admin emergency veto | Admin casts a veto signal after member approval; blocks execution indefinitely | Admin (role 0) |
| Timelock on execution | Execution cannot happen until 10 min (demo) / 4 days (production) after member approval | Automatic |
| Calldata integrity | The exact recipient and amount proposed by the public is what gets executed — no substitution at execution time | Protocol-enforced |

**Security considerations:**
- The `OpenAction` mandate (Step 4) allows Members to execute arbitrary on-chain calls from the Powers treasury. Its scope is constrained by `needFulfilled = Step 2`: Members can only execute calls that were first submitted via the public proposal step (Step 1) and approved by unanimous member vote (Step 2). Callers must provide the identical calldata and nonce across all four steps.
- Admin is a single key. If the deployer key is lost or compromised, the emergency veto power is gone or at risk. For production deployment, consider a Safe multisig as the Admin address.
- The three Member addresses are fixed at deployment. Replacing them requires a Governance Reform action (Flow 2), which itself requires unanimous Member agreement.

---

## External Dependencies

| System | Purpose | Required? |
|--------|---------|----------|
| PowersPaymaster | ERC-4337 paymaster for gasless transactions | Yes (AA enabled) |
| ERC-4337 EntryPoint | `0x0000000071727De22E5E9d8BAf0edAc6f37da032` | Yes (AA enabled) |

No Gnosis Safe, token contracts, or external oracles are required.

---

## Design Rationale

Project Orange is a minimal viable governance structure for a high-trust, small group. The three-member unanimity rule reflects the IAD framework's principle of collective-choice arrangements: every affected party has a direct vote and veto. This is appropriate for a small, mission-driven group where consensus is both achievable and desirable.

The separation between public proposal (Step 1) and member approval (Step 2–4) creates an open submission model without open execution — anyone can put something on the table, but only the inner circle can act on it. This is an asymmetric but legitimate structure: legitimacy flows from the mission-alignment of the members, not from electoral representation.

The Admin veto sits outside the normal governance flow, deliberately. It is not a veto over the proposal per se, but a final check on the execution. This mirrors the design principle in Podger, Chan & Wanna (2020) of separating deliberative authority from executive authority — Members deliberate and decide; Admin provides an executive check before funds actually move.

Gasless transactions (Account Abstraction) lower the participation barrier for both the public (submitting proposals) and Members (voting), which is important for an organisation that may onboard non-crypto-native orange enthusiasts.

---

## Limitations

- **No membership rotation**: There is no built-in mechanism to add, remove, or rotate Members without a governance reform. For this demo, this is intentional.
- **Fixed execution amount**: The paymaster top-up flow (Flow 3) sends a fixed 0.05 ETH each time. A more flexible version would allow the amount to be specified at runtime.
- **No proposal expiry**: A public proposal (Step 1) never expires. It remains valid until a member vote (Step 2) is initiated with the same nonce. The organisation relies on Members to ignore stale or rejected proposals.
- **OpenAction scope**: Step 4 can execute arbitrary transactions, not just ETH transfers. While constrained by the `needFulfilled` check, Members could in principle craft a proposal (Step 1) that calls a smart contract function rather than a plain ETH transfer. For this demo this is acceptable given the small, trusted membership.

---

## Account Abstraction

A `PowersPaymaster` (ERC-4337) is deployed alongside the organisation and seeded with **0.05 ETH** at deployment time. Members and the public can interact with Project Orange without holding ETH for gas. When the paymaster balance runs low, the Admin can top it up using Flow 3 (Fund Paymaster). To recover funds, the Admin uses Flow 4 (Withdraw from Paymaster).

The deployer wallet must hold at least **0.05 ETH plus gas** at deploy time.

---

## Metadata URI

`https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafkreidsrfntlufrkdbfgiwnutjhzo6e4a4qf4faba4zjfajrcn6rpbpvm`

This URI will be used as the second argument to the `Powers` constructor in the deploy script.

---

## Implementation Notes

- **Mandate version:** MAJOR=0, MINOR=1, PATCH = 9
- **Mandate nameDescription strings must match exactly across Deploy, Actions, Runners, and Test files.**
- **Demo timing:** All voting periods and timelocks use 5-minute blocks for quick iteration. A `minutesToBlocks()` helper converts to chain-specific block counts.
- **Production timing:** Replace 5-min periods with 3 days, and 10-min timelocks with 4 days, before deploying to mainnet.
