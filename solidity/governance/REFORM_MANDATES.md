# Reform Mandates — Design

> Status: **implemented**. This document is the design-of-record for making runtime governance
> reform actually work.
>
> Two findings drive it. First, the registry gate means an organisation can **only ever adopt
> mandates that are already registered** — so the two "package" mandates, which exist to be
> deployed bespoke, can never be used and are removed. Second, `Adopt_Mandates` — the only
> registered mandate that can install new mandates — hardcodes the name, config and conditions
> of everything it adopts, which makes it unable to install any mandate that needs
> configuration or a vote. In practice that means **runtime reform does not currently work**.

## Goals

1. Make it possible for a live organisation to adopt a **fully configured** mandate — with its
   own config, conditions, and name — through its own governance.
2. Do so **without** requiring bespoke contract deployment, which the registry forbids.
3. Do so **without** relying on `OpenAction`, which grants its role unlimited power.
4. Break no existing organisation.
5. Remove code that cannot work, so it stops appearing in designs.

## Key architectural findings

**1. The registry gate is absolute, and it is checked twice.**

On the mandate side, `Mandate.initializeMandate` calls the registry as its first act
(`src/Mandate.sol:67`):

```solidity
IMandateRegistry(MANDATE_REGISTRY).onAdopt(msg.sender);
```

which reverts unless the adopting mandate's **address** is registered
(`src/core/helpers/MandateRegistry.sol:510`, gate at `:430-434`):

```solidity
if (!_isMandateAddressActive(mandate)) revert NotRegistered(mandate);
```

On the Powers side, `PowersUtilities.storeMandate:56-62` independently re-checks
`isMandateAddressActive`. `registerMandate` is `onlyOwner` of the registry, and the mandate's
own `MANDATE_REGISTRY` is `immutable` (`src/Mandate.sol:48-54`), so a mandate cannot be pointed
at a friendlier registry after the fact.

**Consequence:** a governance reform can only ever *compose mandates that the protocol has
already registered*. No amount of tooling changes this.

**2. The two package mandates cannot be adopted by anyone.**

`MandatePackage` and `MandatePackage_Static` (whose contract is confusingly named
`ReformMandate_Static`) exist solely to be deployed bespoke, with a bundle of adoptions baked
into their constructor or source. Neither appears in `script/DeployMandates.s.sol`'s
registration list, so neither is registered — and per finding 1, neither can ever be adopted by
an organisation using a real registry.

The existing tests pass only because they own the registry and self-register the package
(`test/TestConstitutions.sol:66-70`). `governance/DeployHelpers.s.sol:103-158`
(`packageInitData`) CREATE2-deploys these packages and would revert on adoption against any live
chain; nothing calls it.

This is worse than dead code — it is dead code that *looks* like the intended reform mechanism,
and it leads designers toward structures that cannot be built.

**3. `Adopt_Mandates` discards almost everything about what it adopts.**

`src/core/mandates/reform/Adopt_Mandates.sol:52-63`:

```solidity
PowersTypes.Conditions memory conditions;      // all fields zero
for (uint256 i; i < length; i++) {
    conditions.allowedRole = roleIds_[i];      // the only field ever set
    PowersTypes.MandateInitData memory mandateInitData = PowersTypes.MandateInitData({
        nameDescription: "Reform mandate",     // hardcoded, identical for every mandate
        targetMandate: mandates_[i],
        config: abi.encode(),                  // empty — nothing can be configured
        conditions: conditions
    });
```

Runtime calldata is only `(address[] mandates, uint256[] roleIds)`
(`Adopt_Mandates.sol:24-26, 47`). So a reform today can adopt only a mandate that:

- needs **no config** — which excludes `SelfSelect` (needs a roleId), `BespokeAction_Simple`
  (needs target + selector), `PresetActions` (needs the call list), and nearly everything else;
- needs **no voting period, quorum, timelock, or `needFulfilled` chaining** — so it can never
  install a multi-step or deliberated flow, only a single mandate that executes instantly;
- is content to be called **"Reform mandate"** in every frontend, indistinguishably from every
  other mandate ever adopted this way.

Note also that `conditions` is declared outside the loop and only `allowedRole` is reassigned.
Harmless today because nothing else is ever written, but it is a latent aliasing bug the moment
another field is set.

**Consequence:** runtime reform is effectively non-functional. This is the defect to fix.

## The core move: give `Adopt_Mandates` the whole struct

`Powers.adoptMandate` already takes a complete `MandateInitData`
(`src/interfaces/PowersTypes.sol:46-51`):

```solidity
struct MandateInitData {
    string nameDescription;
    address targetMandate;
    bytes config;
    Conditions conditions;
}
```

`Adopt_Mandates` should accept exactly that array as its runtime calldata and pass each entry
through **unmodified**, rather than synthesising a degraded one. The mandate stops being a
policy about what may be adopted and becomes what it should always have been: a transport.

Everything governance needs to constrain a reform already exists upstream — who may propose,
who may veto, quorum, timelock — expressed in the *reform flow's* own conditions. Degrading the
payload adds no safety; it only removes capability.

## Design decisions

| Decision | Choice | Rationale |
|---|---|---|
| **Calldata shape** | `MandateInitData[]` | The full struct, unmodified. Anything less leaves some mandate un-installable, and the boundary of "less" is arbitrary. |
| **Versioning** | Ship as **v0.2.0**, leave v0.1.9 registered | Existing organisations hold the old address and have `StatementOfIntent` propose steps wired to the old two-array calldata. Deactivating v0.1.9 would break the very mechanism they would need to fix themselves. |
| **Self-modification vehicle** | Configured `PresetActions_OnOwnPowers` | Already registered; all calls target the org itself. Bounded to a call list fixed at adoption. |
| **`OpenAction`** | Explicitly **not** the reform route | Grants its role unrestricted power over the organisation. Acceptable only as a deliberate, understood choice — never as infrastructure. |
| **Package mandates** | Delete | Cannot be adopted; mislead designers. |

## Design

### 1. `Adopt_Mandates` v0.2.0

`src/core/mandates/reform/Adopt_Mandates.sol` — same file, same contract name, so the on-chain
v0.1.9 registration (registry state) is untouched.

- `initializeMandate` declares a single input param, the `MandateInitData[]`, replacing the
  two-element `["address[] mandates", "uint256[] roleIds"]`.
- `handleRequest` decodes `(PowersTypes.MandateInitData[])` and emits one
  `IPowers.adoptMandate` call per entry, passing the struct straight through. The hardcoded
  name, the empty config and the zeroed conditions all disappear — as does the aliased
  `conditions` variable.
- Override `version()` to return `(0, 2, 0)`. The base returns `(0,1,9)`
  (`src/Mandate.sol:143-145`), and `script/DeployMandates.s.sol:161` reads the version off the
  deployed contract, so this one override is all that is needed for the new version to register
  alongside the old.
- Reject an empty array, and cap length against `MAX_EXECUTIONS_LENGTH` (25) with a named
  revert rather than letting `Powers.fulfill` fail opaquely (`src/Powers.sol:378`).

### 2. Full self-modification without `OpenAction`

Once a configured mandate can be adopted, `PresetActions_OnOwnPowers` becomes reachable. Its
config is `abi.encode(bytes[] callDatas)` and every call is forced to target the organisation
itself (`src/addons/mandates/executive/PresetActions_OnOwnPowers.sol:49-56`). Because
`Powers.fulfill` calls into itself, `msg.sender == address(powers)` and the `onlyPowers` gate
passes — so a single adopted instance can reach `adoptMandate`, `revokeMandate`, `addFlow`,
`removeFlow`, `editFlowByIndex`, `labelRole`, `assignRole`, `revokeRole`, `setUri`,
`setTreasury`, `setPaymaster`.

That is complete self-modification, bounded to a call list fixed at adoption time and reviewable
before the vote — the property `OpenAction` lacks.

### 3. Removals

| File | Action |
|---|---|
| `src/core/mandates/reform/MandatePackage.sol` | delete |
| `src/core/mandates/reform/MandatePackage_Static.sol` | delete |
| `governance/DeployHelpers.s.sol` | delete the `ReformMandate_Static` import (`:12`) and `packageInitData()` (`:103-158`) |
| `test/unit/mandates/Reform.t.sol` | delete the `MandatePackage*` test contracts (26 refs) |
| `test/TestConstitutions.sol` | delete the package constitution (~`:1860-1945`) and `_registerPkgMandate` (`:66-70`) |
| `test/TestSetup.t.sol` | delete `TestSetupMandatePackageStatic` (~`:801-818`) |

Neither contract is in `script/DeployMandates.s.sol`, so registration needs no change.

### 4. Migration for existing organisations

An organisation holding v0.1.9 can adopt v0.2.0 with its existing reform flow: the new
`Adopt_Mandates` takes no config, which is precisely what the old one is able to install. So the
standard migration is a single ordinary reform:

1. Propose through the existing reform flow, passing `mandates = [<v0.2.0 address>]` and
   `roleIds = [<reform executor role>]`.
2. Once adopted, the organisation has both. Subsequent reforms use the new one.
3. Optionally revoke the v0.1.9 instance afterwards.

Until then, such an organisation's reform capability is limited to config-less, condition-less
adoptions.

### 4a. Paired propose/veto steps must be migrated too

A reform flow is normally `StatementOfIntent` (propose) → optional `StatementOfIntent` (veto) →
`Adopt_Mandates` (execute). `Checks.sol:51-57` matches the steps by recomputing
`computeActionId(needFulfilled, mandateCalldata, nonce)` — **the same `mandateCalldata` at every
step**. So when the executor moves to `MandateInitData[]`, the propose and veto steps must
declare that shape too.

`StatementOfIntent` never decodes its calldata (it only hashes it), so its `inputParams` string
is pure frontend metadata and nothing reverts on-chain if it is stale. That is what makes this
dangerous rather than obvious: a UI rendering the old two-array form produces a proposal that
passes its vote and then **cannot be executed**, because the executor cannot decode the payload
the proposal was hashed with. The vote is wasted and the flow has to be restarted.

Every reform flow in `governance/` has been migrated accordingly.

## The mandate-ID prediction hazard

Adoptions in one bundle land at `mandateCounter, mandateCounter + 1, …` in order, but the
payload is fixed when the proposal is made. Any adoption between proposal and execution shifts
every prediction — and an election cycle adopting a vote mandate is enough to cause it
(`src/core/mandates/integrations/ElectionRegistry/ElectionRegistry_CreateVoteMandate.sol:97`).

This matters because `needFulfilled`, `needNotFulfilled` and `editFlowByIndex` all reference
mandates **by id**. A shifted prediction does not revert; it wires the flow to the wrong
mandate. The organisation ends up with a governance structure that looks correct and is not.

Mitigations, in order of strength:

1. Record `mandateCounter` at proposal time; re-read it immediately before execution and abort
   on any change. This belongs in the generated runner scripts.
2. Prefer bundles that do not self-reference by predicted id where the reform allows it.
3. Note that `editFlowByIndex` deliberately permits `mandateId == mandateCounter` to allow
   same-transaction wiring (`src/Powers.sol:541`) — the allowance is intentional, the
   prediction risk is the cost.

There is no on-chain fix short of making `Adopt_Mandates` resolve ids at execution time, which
would require the payload to express "the mandate I am about to adopt" symbolically. That is
worth considering later; it is out of scope here.

## Critical files

- **Changed:** `src/core/mandates/reform/Adopt_Mandates.sol`
- **Deleted:** `src/core/mandates/reform/MandatePackage.sol`,
  `src/core/mandates/reform/MandatePackage_Static.sol`
- **Updated for removals:** `governance/DeployHelpers.s.sol`,
  `test/unit/mandates/Reform.t.sol`, `test/TestConstitutions.sol`, `test/TestSetup.t.sol`
- **Unchanged:** `src/Powers.sol`, `src/libraries/PowersUtilities.sol`,
  `src/core/helpers/MandateRegistry.sol`, `script/DeployMandates.s.sol`

## What is deliberately NOT changed

- **The registry gate.** Requiring registration is the trust model — "registered" means
  "vetted". This design works within it rather than around it.
- **`Powers.adoptMandate`.** It already accepts the full struct; the defect was entirely in the
  caller.
- **`Revoke_Mandates` and `PauseMandates`.** Both work as intended.
- **`OpenAction`.** Stays in the codebase for advanced hand-written use.

## Verification

1. `forge build`, then `forge test --match-contract Reform -vvv`.
2. New `Adopt_Mandates` coverage: adopting a mandate **with** a config; adopting with non-zero
   conditions (voting period + timelock); `needFulfilled` chaining between two mandates adopted
   in the same call; empty-array and over-cap reverts.
3. `grep -rn "MandatePackage\|ReformMandate_Static" --include=*.sol --include=*.md .` returns
   nothing outside this document.
4. Full `forge test` to catch fallout in the shared test constitutions.
5. Anvil rehearsal: deploy an org, run a reform that adopts a configured multi-step flow, and
   confirm the resulting conditions and flow wiring match intent.

## Open design points

- **Symbolic id references.** Letting a bundle say "chain this to the mandate I adopt next"
  instead of a predicted integer would remove the prediction hazard entirely. Larger change;
  deferred.
- **`CORE_MANDATES.md` is referenced by `CLAUDE.md` but does not exist.** Either write it or
  drop the reference.
- **Latent encoding bug found while verifying this doc**, unrelated to the changes proposed
  here but in adjacent code. `IPowers.adoptMandate` takes exactly one argument
  (`src/interfaces/IPowers.sol:107`), but
  `src/core/mandates/integrations/ElectionRegistry/ElectionRegistry_CreateVoteMandate.sol:95-97`
  encodes three:
  ```solidity
  abi.encodeWithSelector(IPowers.adoptMandate.selector, initData, nonce, "Creating vote mandate for election.")
  ```
  The two extra values are appended as trailing calldata. It currently works — the decoder
  reads the dynamic struct at its offset and ignores the tail — but it is silently wrong and
  will break under any stricter calldata validation. Worth a separate fix.
- **Filename/contract mismatch** as a general hazard: `MandatePackage_Static.sol` declaring
  `ReformMandate_Static` is being deleted here, but the repo should probably assert
  file-name-equals-contract-name somewhere, since artifact resolution by filename silently
  breaks on it.
