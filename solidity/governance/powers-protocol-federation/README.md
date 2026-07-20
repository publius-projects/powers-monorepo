# Powers Protocol Federation

A federation of **three interlocking on-chain organisations** that together sustain the Powers Protocol and its mandate ecosystem. Each is an independent Powers contract with its own treasury and its own elected members, and they are bound together by who funds whom:

- **Core Governance** — holds the main treasury; funds core-protocol development and audits; whitelists audit firms; funds the Mandates organisation; an elected **Security Council** can instantly pause the funding flows and veto governance changes.
- **Mandates Governance** — pays mandate developers and auditors, and governs which mandates are listed in a `MandateRegistry` it owns (additions pass through a Security Council veto window). It also governs that registry's **paid-adoption tier** — the credit→wei exchange rate, the protocol fee, and sweeping accrued fees into its treasury. It requests its budget from Core.
- **Endowment Governance** — invests the endowment in **Aave v3 on Ethereum Sepolia** (real yield) and pays a **recurring income stream** up to Core. Core, as an organisation, holds a **veto over new investments** but not over divestment, so the endowment can always retreat to safety.

Every cross-organisation transfer needs **both** organisations to approve their own side of it — a genuine "nested enterprises" structure (Ostrom). See `Spec.md` for the full design and rationale, including the governance-theory sources cited.

> **Network:** built for **Ethereum Sepolia** (chain id 11155111), because that is the chain that carries both dependencies this federation needs: Aave v3 (the Endowment invests there) and a populated canonical `MandateRegistry` (every constitution mandate is adopted through it). All durations are in test-minutes (roughly one minute per governance "day").

---

## Prerequisites

Set these environment variables (copy `.env.example` to `.env.local` and fill them in):

- `SEPOLIA_RPC_URL` — **required** for both deploying and testing (Aave v3 and the canonical `MandateRegistry` both live on Ethereum Sepolia).
- `ARB_SEPOLIA_RPC_URL`, `OPT_SEPOLIA_RPC_URL` — optional, for other networks (note: those chains have no canonical `MandateRegistry` — see below).
- `ETHERSCAN_API_KEY` — for contract verification.
- A Foundry encrypted keystore: `DEPLOYER_ACCOUNT` and `DEPLOYER_ADDRESS`. Run `make setup-wallet` for step-by-step instructions.
- `TEST_ACCOUNT_KEY_1..3` — three throwaway private keys used **only for `forge script` deploys** (they seed the founding-member cohort). The Anvil defaults in `.env.example` are fine. The test suite does not need them.

The deployer wallet must hold at least **0.15 ETH plus gas** — the deploy seeds one central Core-owned `PowersPaymaster` with 0.15 ETH.

---

## Mandate registry model

Two distinct registries are in play. Keeping them straight matters because one gates the deploy itself:

- **The canonical `MandateRegistry`** (resolved from `Configurations.getMandateRegistry(chainId)`). Every mandate a Powers org adopts calls `onAdopt` on it at constitution time; adoption **reverts** unless that mandate is registered and active. All three federation organisations are constituted from this registry, so it **must already be deployed and populated on the target chain before you deploy the federation**. On Ethereum Sepolia this address is hardcoded in `Configurations`; populate it (if it is not already) with:
  ```bash
  cd ../.. && make registry-deploy   # runs DeployMandates against Sepolia
  ```
  The federation resolves each mandate to its **latest registered version** (via `getLatestVersion`), so there is no version constant to keep in sync.

- **The Mandates-governed `MandateRegistry`** — the registry the Mandates org curates (flows M3/M4) and whose **paid-adoption tier** it governs through flows **M8** (set exchange rate), **M9** (set protocol fee), and **M10** (sweep accrued protocol fees into the treasury). This is **the same canonical `MandateRegistry` from configuration** (`Configurations.getMandateRegistry`), *not* a fresh throwaway deployment. Because the deploy does not (and cannot) own that registry, all of these owner-only calls — the M3/M4/M8/M9/M10 flows, and the paid-tier seeding that used to run in the Mandates setup mandate — **will revert until you transfer the registry's ownership to the Mandates Powers contract out-of-band**. After the transfer, seed the credit→wei rate and protocol fee via the M8/M9 flows (or a one-off owner call). Any *priced* community mandate registered here would require the adopting org to pre-fund credits via `buyCredits` before adoption — the federation's own constitution uses only free (price-0) mandates, so it needs no such pre-funding.

---

## Deployment

1. Copy the env template and fill in your values:
   ```bash
   cp .env.example .env.local
   # edit .env.local
   ```
2. Create a deployer keystore:
   ```bash
   make setup-wallet   # prints the exact commands
   ```
3. Deploy all three organisations (they are co-deployed and interlocked in one script):
   ```bash
   make deploy-sepolia         # recommended
   # or: make deploy-anvil / make deploy-arb-sepolia
   ```

The script prints the deployed addresses for the three Powers contracts, the single central paymaster, and the Mandates-owned `MandateRegistry`.

### Metadata URI

The three Powers contracts are deployed with a **blank metadata URI** — look for the `// TODO: set metadata URI` marker in `Deploy.s.sol`. Before a live deploy, upload a JSON file (with `name`, `description`, and optionally `image`) for each organisation to [Pinata](https://pinata.cloud) (free tier available) and paste the resulting gateway URL into the corresponding `_newPowers(...)` call.

---

## Actions script

`Actions.s.sol` exposes one propose/execute helper per governance flow (e.g. paying an invoice, investing in Aave, adding a mandate to the registry). Use it to drive a single step of a flow manually. Example:

```bash
forge script governance/powers-protocol-federation/Actions.s.sol:PowersProtocolFederationActions \
  --sig "proposeCoreInvoice(address,address,uint256,uint256[],uint256)" \
  --rpc-url $SEPOLIA_RPC_URL --broadcast
```

The `nameDescription` strings in `Actions.s.sol` match `Deploy.s.sol` character-for-character — that is how the correct mandate is located on-chain.

---

## Runners script

`Runners.s.sol` is stateless: each `run*()` reads current on-chain state and advances a flow as far as conditions allow (proposing, voting, or executing), then stops at the first phase still blocked by a voting window or timelock. Use it for automated / bot-style execution. Example:

```bash
forge script governance/powers-protocol-federation/Runners.s.sol:PowersProtocolFederationRunners \
  --sig "runCoreInvoice(address,address,uint256,uint256[],uint256)" \
  --rpc-url $SEPOLIA_RPC_URL --broadcast
```

Call `runInitialSetup(address,uint256[],uint256)` once per organisation immediately after deployment to execute each setup mandate.

---

## Account Abstraction / Paymaster

A **single central `PowersPaymaster`** (ERC-4337) serves all three organisations. It is owned and funded by **Core Governance** and pre-funded with **0.15 ETH**. Members of any organisation can interact without paying gas from their own wallets — the paymaster sponsors every user operation whose target is one of the three Powers contracts (all registered in its `sponsoredTargets` list; Core's setup mandate adds the two affiliate orgs).

- Check the paymaster's balance:
  ```bash
  cast call <CENTRAL_PAYMASTER_ADDRESS> "getDeposit()(uint256)" --rpc-url $SEPOLIA_RPC_URL
  ```
- Top it up via Core's "Fund Paymaster" flow (Core Members propose and execute a deposit). `deposit()` is public, so the affiliate orgs *could* also top up the shared pool voluntarily.
- Withdraw via Core's "Withdraw Paymaster" flow. Only Core (the owner) can withdraw or change the sponsored-target list.

The deployer wallet must hold at least 0.15 ETH plus gas at deploy time to seed the paymaster.

---

## Testing

```bash
make test
# or, run forge directly (the FOUNDRY_TEST override lets forge discover a test
# that lives under governance/ rather than the default test/ directory):
# FOUNDRY_TEST=governance/powers-protocol-federation \
#   forge test --match-contract PowersProtocolFederation_test -vvv
```

Only `SEPOLIA_RPC_URL` is required — the tests fork Ethereum Sepolia (so the Aave integration and the canonical on-chain `MandateRegistry` are real) and use synthetic accounts internally. Because the fork uses the live canonical registry, its whitelist must contain every mandate the constitution adopts; if a run fails at `constitute()` with a not-registered error, populate the registry first (`make registry-deploy`). No private-key env vars are needed to run the tests.

The suite covers the deployed structure (role labels, cross-organisation seats, founding cohort, the Core investment-veto wiring), a full end-to-end Core invoice payment in USDC, and a negative test proving a Security Council veto blocks a governance reform.
