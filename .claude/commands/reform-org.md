# Powers Protocol — Governance Reform Skill

You help people change an on-chain organisation that already exists. Where `/design-org` builds a new organisation, this skill reads a deployed one, works out whether it can be changed at all, agrees what should change, and produces the files to enact that change through the organisation's own governance.

The user has invoked this skill with: **$ARGUMENTS** (expected: a chain and an address, e.g. `421614 0xAbC…`)

Work through the phases below in order. Never skip a phase. Speak in plain language — your counterpart is a governance designer, not a software developer. Avoid the term "DAO"; use "organisation" instead.

---

## Phase -1 — Introduction (do this first, before anything else — no tool calls yet)

Greet the user and explain in your own words what is about to happen:

- You will read their organisation directly from the blockchain — its mandates, flows and roles — and check whether it is capable of being reformed at all.
- Not every organisation can be. An organisation can only change itself if it was given a **reform flow** when it was created. If it wasn't, nothing can be added or removed, by anyone, ever. You will tell them straight away if that is the case.
- Reform can only use building blocks that are **already registered** in the protocol. Purpose-built contracts cannot be adopted — the protocol rejects them. So some changes may simply not be possible, and you will say so rather than approximate.
- If reform is possible: a conversation about what they want to change, a written specification they approve, and then generated scripts that walk the change through their organisation's normal governance — proposal, vote, execution.
- Nothing this skill produces changes anything on its own. Every change still has to pass their organisation's own rules.

Only after this introduction, proceed to Phase 0.

---

## Phase 0 — Environment Check (do this silently)

Resolve path variables exactly as `/design-org` does — read that skill's Phase 0 and follow it verbatim for context detection (`FOUNDRY_ROOT`, `REF_ROOT`), the dependency check, the output folder, remappings, and compiler settings. Do not restate those rules here; they are identical.

Additionally:

1. **Resolve an RPC endpoint for the target chain.** Map the chainId to the environment variable convention used across this project:

   | chainId | Network | Variable |
   |---|---|---|
   | 11155111 | Ethereum Sepolia | `SEPOLIA_RPC_URL` |
   | 421614 | Arbitrum Sepolia | `ARB_SEPOLIA_RPC_URL` |
   | 11155420 | Optimism Sepolia | `OPT_SEPOLIA_RPC_URL` |
   | 31337 | Local Anvil | `http://localhost:8545` |

   If the variable is unset, stop and tell the user:

   > I need an RPC endpoint for chain `<chainId>` to read your organisation. Set `<VAR>` in your environment (free endpoints from [Alchemy](https://alchemy.com) or [Infura](https://infura.io)), then re-run `/reform-org`.

   Do not proceed without it — every check in Phase 1 depends on it.

2. **Confirm `cast` is available** (`cast --version`). It ships with Foundry; if missing, the environment is broken and `forge` will not work either.

---

## Phase 1 — Read the organisation

Set `$ADDR` and `$RPC`. Work through these in order, stopping at the first failure.

### 1a. Is it a Powers organisation?

There is **no ERC165 interface id for `IPowers`** — `supportsInterface` matches only the ERC721/1155 receiver interfaces, so any NFT-holding vault would pass it. Detection is therefore a layered heuristic, not a proof. Present the conclusion as evidence, never as certainty.

```bash
cast code $ADDR --rpc-url $RPC                          # must be non-empty
cast call $ADDR "getMandateCounter()(uint16)" --rpc-url $RPC   # must be >= 1
cast call $ADDR "PUBLIC_ROLE()(uint256)" --rpc-url $RPC        # must be 2^256-1
cast call $ADDR "DENOMINATOR()(uint256)" --rpc-url $RPC         # must be 100
cast call $ADDR "version()(string)" --rpc-url $RPC              # expect v0.6.x
cast call $ADDR "name()(string)" --rpc-url $RPC
```

- **`cast code` must come first.** A `cast call` to an address with no code returns empty rather than reverting, so a call-only probe reads success where there is no contract.
- `getMandateCounter()` alone is what the dApp uses (`frontend/hooks/useAddressType.ts`), but a contract with a permissive fallback returns decodable garbage and would pass. The `PUBLIC_ROLE` and `DENOMINATOR` checks are the cheap false-positive killers: a fallback returning empty data decodes both to `0`.
- Report an unexpected `version()` but do not hard-fail on it — older organisations exist.

If detection fails, stop and tell the user which check failed and what the address appears to be instead.

### 1b. Is it live?

`request()` and `propose()` are disabled while an organisation is still in its constitute phase, and `_constituteClosed` is private with no getter. Infer it:

```bash
cast call $ADDR "onERC721Received(address,address,uint256,bytes)(bytes4)" \
  0x0000000000000000000000000000000000000000 0x0000000000000000000000000000000000000000 0 0x --rpc-url $RPC
```

Returning `0x150b7a02` means constitute is closed and the organisation is live. A revert means it is still in setup — report that reform cannot proceed because no action can be executed yet.

### 1c. Enumerate mandates

Mandate ids start at **1**, and `getMandateCounter()` returns the *next* id, so iterate `1 .. counter-1`. Revocation is a soft delete, so the counter overstates the live set — sometimes badly for organisations running elections, which adopt and revoke a vote mandate each cycle.

```bash
cast call $ADDR "getAdoptedMandate(uint16)(address,bytes32,bool)" $ID --rpc-url $RPC
cast call $ADDR "getConditions(uint16)((uint256,uint32,uint32,uint32,uint16,uint16,uint8,uint8,uint32))" $ID --rpc-url $RPC
```

Skip any entry whose address is zero or whose `active` flag is false. `getAdoptedMandate` does **not** revert for out-of-range ids — it returns zeros — so the counter is the only loop bound.

The `Conditions` tuple fields, in return order:

| # | type | field |
|---|---|---|
| 0 | `uint256` | `allowedRole` |
| 1 | `uint32` | `votingPeriod` |
| 2 | `uint32` | `timelock` |
| 3 | `uint32` | `throttleExecution` |
| 4 | `uint16` | `needFulfilled` |
| 5 | `uint16` | `needNotFulfilled` |
| 6 | `uint8` | `quorum` |
| 7 | `uint8` | `succeedAt` |
| 8 | `uint32` | `maxExecutionDelay` |

The human-readable name lives on the **mandate contract**, not on Powers:

```bash
cast call $TARGET_MANDATE "getNameDescription(address,uint16)(string)" $ADDR $ID --rpc-url $RPC
cast call $TARGET_MANDATE "getConfig(address,uint16)(bytes)" $ADDR $ID --rpc-url $RPC
```

### 1d. Identify what each mandate *is*

**Never identify a mandate by its `nameDescription`.** That string is free text chosen by whoever adopted it and is never validated against behaviour. Use the registry:

```bash
REG=$(cast call $ADDR "MANDATE_REGISTRY()(address)" --rpc-url $RPC)
cast call $REG "addressKey(address)(bytes32,uint48)" $TARGET_MANDATE --rpc-url $RPC
```

This returns `nameHash = keccak256(name)` and a packed version (`major<<32 | minor<<16 | patch`). The hash is not invertible, so build a lookup table by hashing the known names with `cast keccak` — the canonical list is the `names.push(...)` calls in `<REF_ROOT>/script/DeployMandates.s.sol`. Read that file for the current list rather than relying on a list written here.

Two situations to report honestly rather than paper over:

- **`MANDATE_REGISTRY` is `address(0)`.** Legal, and used by the public deploy demo. Such an organisation enforces no registry membership, so address→name resolution is impossible. Say that identification is unreliable and hedge the verdict.
- **A name hash that matches nothing** in the local list. The list is versioned with this repo, not with the chain, so a mandate registered on-chain but unknown here resolves to `<unknown>`. Report unknowns as unknown.

### 1e. Flows and roles

```bash
cast call $ADDR "getFlowCount()(uint256)" --rpc-url $RPC
cast call $ADDR "getFlowMandatesAtIndex(uint8)(uint16[])" $I --rpc-url $RPC
cast call $ADDR "getFlowDescriptionAtIndex(uint8)(string)" $I --rpc-url $RPC
```

Removed flows leave zeroed holes rather than shrinking the array — skip empty ones. Flow indices are `uint8`.

There is **no role enumeration on-chain**. Recover the role set by harvesting `allowedRole` from every active mandate's conditions, union with `ADMIN_ROLE = 0` and `PUBLIC_ROLE = 2^256-1`, then for each:

```bash
cast call $ADDR "getRoleLabel(uint256)(string)" $ROLE --rpc-url $RPC
cast call $ADDR "getAmountRoleHolders(uint256)(uint256)" $ROLE --rpc-url $RPC
```

Roles that gate no mandate are invisible this way — note that limitation. `getAmountRoleHolders(PUBLIC_ROLE)` is `0` by design; treat `PUBLIC_ROLE` as "everyone", never as "nobody".

### 1f. Local design context (optional)

If a `<FOUNDRY_ROOT>/governance/*/Spec.md` describes this address, read it for design intent — role meanings, why flows are shaped as they are. **The chain is authoritative.** Where they disagree, trust the chain and mention the discrepancy; a stale spec usually means the organisation was reformed already.

Present a plain-language summary of the organisation before moving on.

---

## Phase 2 — Can this organisation be reformed?

Reform requires an **active, reachable `Adopt_Mandates`**. Report exactly one of these verdicts.

**Not a Powers organisation** — Phase 1a failed. Say which check and stop.

**Still in setup** — Phase 1b failed. Nothing executes yet; stop.

**Reform not possible** — no active `Adopt_Mandates`, or one that cannot be reached. Reachable means all of:
- its `allowedRole` has at least one holder, or is `PUBLIC_ROLE`;
- its `needFulfilled` / `needNotFulfilled` dependencies point at mandates that are themselves active.

Explain plainly: the organisation cannot adopt new mandates through governance, so nothing this skill generates would execute. This is permanent — mandates can only be adopted through governance, so there is no path in. The organisation would have to be redeployed with a reform flow (`/design-org`), and any assets and roles migrated by hand. Stop here.

**Reform possible, but limited** — `Adopt_Mandates` is present at **version 0.1.9**. That version hardcodes an empty config, zeroed conditions and the name "Reform mandate" for everything it adopts. It can therefore only adopt mandates that need no configuration and no vote — which excludes almost everything useful. Tell the user the good news: **v0.1.9 can adopt v0.2.0**, because the new version itself needs no config. Offer to generate exactly that one-step migration first; afterwards the organisation has full reform capability. Do not attempt a substantive reform through v0.1.9.

**Reform possible** — v0.2.0 present and reachable. Report the complete reform path: which flow it sits in, every step in order, and for each step the role that must act, the quorum, the voting period and the timelock. The user needs to know what they will have to pass.

---

## Phase 3 — What should change?

Ask what they want to change, and probe for specifics — "make it harder to spend money" needs to become a quorum, a role, and a timelock.

Map every request onto registered mandates, using `/design-org`'s Appendix A.3 catalogue as the reference for what exists and how each is configured. Two rules:

- **If a request cannot be met with registered building blocks, say so.** Do not silently substitute something weaker. Explain what is missing and what the closest reachable alternative gives up.
- **Additive and subtractive changes travel together.** Adopting a replacement flow usually means revoking the old one; adding a role-gated flow usually means labelling the role. All of it goes in one bundle.

Structural changes beyond adopting mandates — revoking, relabelling roles, adding or repointing flows — are done by adopting a **configured `PresetActions_OnOwnPowers`** whose `bytes[]` config is a list of calls the organisation makes on itself. See `/design-org` Appendix A.2, "Governance Self-Modification". Do not propose `OpenAction` for this.

---

## Phase 4 — Reform specification

Write to `<FOUNDRY_ROOT>/governance/<org-name>/reforms/<reform-name>/Spec.md`.

`<org-name>` is the existing local folder for this organisation if one matches; otherwise derive a kebab-case name from the on-chain `name()`. `<reform-name>` is a short kebab-case description (`add-treasury-veto`, `migrate-adopt-mandates`).

The spec must cover:

- **Organisation** — name, chain, address, and **the block number at which you read it**. Everything below is a snapshot; record it.
- **Current structure** — roles, flows, mandates, as read from chain.
- **What changes and why** — in plain language first, then the technical detail.
- **Mandates to adopt** — for each: which registered mandate, at which version, its `config`, and its full `Conditions`.
- **What is revoked or repointed** — and the consequences. Flag explicitly if a mandate being revoked is the target of another mandate's `needFulfilled` or `needNotFulfilled`: that reference will dangle.
- **Resulting structure** — the roles and flows after the reform.
- **Governance path** — which flow carries the reform, who must propose, who votes, quorum, and the total elapsed time including timelocks.
- **What could not be done** — anything from Phase 3 that no registered mandate supports.
- **Cost** — if any mandate being adopted is paid, apply `/design-org`'s Appendix A.8 disclosure rules in full, including consent. The charge fires **at reform time**, so the organisation must hold the credits then, not at deployment.
- **Mandate counter at time of writing** — see the hazard in Phase 5.

Present it in plain language and ask:

> "Does this reform do what you intended? Which parts would you like to change?"

Iterate until the user confirms. Do not generate code before they do.

---

## Phase 5 — Generate

All files go in the same folder. **There is no `Deploy.s.sol`** — a reform deploys nothing. Every mandate it adopts must already be registered, which is exactly why nothing needs deploying.

### 5a. `Actions.s.sol`
Contract `<OrgName>Reform<N>Actions`. One propose/execute function per step of the organisation's reform flow. Follow `/design-org`'s section 4b for conventions, including the `ActionHelpers` import rules for each context.

- Build the `MandateInitData[]` payload once, in a single internal function, and reuse it for every step. **The calldata must be byte-identical across propose and execute** or `needFulfilled` will not match, and the action will not be recognised as the same one.
- If the reform includes self-modification, encode the `bytes[]` for the `PresetActions_OnOwnPowers` adoption in the same place.
- Resolve `Adopt_Mandates` with `registry.getLatestVersion("Adopt_Mandates")`, never the `(0,1,9)` pin.

### 5b. `Runners.s.sol`
Contract `<OrgName>Reform<N>Runners`. Stateless: reads on-chain state and advances the reform as far as current conditions allow, logging what it did and what it is waiting for.

**It must guard the mandate-counter hazard.** Before executing the adoption step, re-read `getMandateCounter()` and compare against the value recorded when the payload was built. If it has moved, abort with a clear message rather than executing:

```solidity
uint16 counterNow = IPowers(powers).getMandateCounter();
require(
    counterNow == EXPECTED_MANDATE_COUNTER,
    "Mandate counter moved since this reform was prepared - needFulfilled/flow wiring would be wrong. Regenerate the reform."
);
```

Explain in a comment why: adoptions land at `mandateCounter + index`, so any adoption in between silently mis-wires every predicted id.

### 5c. `Makefile`
Use `/design-org`'s section 4f template, with `propose-*` and `run-*` targets in place of the deploy targets. Keep the `check-wallet` guard and the network argument blocks.

### 5d. `README.md`
Plain English, for a non-technical operator: what the reform changes, who has to act and in what order, how long it takes, how to run each step, and how to confirm afterwards that it landed — re-read `getMandateCounter()` and check the new mandates' conditions. Include the counter-drift warning and what to do if the runner aborts on it.

### 5e. `.env.example`
`/design-org`'s section 4g template, unchanged.

---

## Phase 6 — Verify

1. Run `forge build` and report the result honestly. Fix errors before continuing.
2. Remind the user that nothing has changed on-chain yet — the scripts still have to pass governance.
3. List what remains: who must propose, who must vote, how long the timelock is, and — if any adopted mandate is paid — that the organisation must hold enough credits when the reform executes.
4. Recommend rehearsing on a fork or on Anvil before running against the live organisation. A mis-wired reform is hard to undo, and the organisation's own rules will not catch a wiring mistake.

Close by listing the generated files.

---

## Things that will bite you

- **The mandate-counter hazard is the sharpest.** Predicted ids silently go wrong; nothing reverts. Guard it in the runner, and say so in the spec and README.
- **The registry ceiling is absolute.** `Mandate.initializeMandate` calls `registry.onAdopt`, which reverts `NotRegistered` unless the mandate's exact address was registered by the registry owner. A bespoke contract cannot be adopted, no matter how it is deployed. When a user wants behaviour nothing registered provides, the honest answer is that it needs a new mandate registered by the protocol — a separate and slower process.
- **Bundles are all-or-nothing.** Any failed call reverts the whole reform. In particular, `revokeMandate` on an already-inactive mandate reverts — so a stale read can fail everything. Re-read state immediately before executing.
- **Size caps.** A single execution is capped at `MAX_EXECUTIONS_LENGTH` (25 calls) and each call at `MAX_CALLDATA_LENGTH` (10,000 bytes); both are per-organisation immutables, readable from the contract. A `MandateInitData[]` with several large configs can approach the calldata limit. Detect this and split the reform across multiple actions rather than generating something that reverts.
- **Revoked mandates leave dangling references.** Ids are never reused, so another mandate's `needFulfilled` pointing at a revoked id stays pointing at a dead mandate. Warn before revoking anything referenced elsewhere.
- **Re-adopting is not restoring.** A re-adopted mandate gets a *new* id, so conditions elsewhere that referenced the old id are not repaired by re-adoption. This is why `PauseMandates` repoints flows explicitly.
