# Staking Pool Governance

A Powers governance organisation that owns and governs a `SimpleStakingPool` — an on-chain
staking pool where users stake one token and earn another. Powers becomes the pool's owner
and drives its four privileged knobs (reward rate, emergency pause, token sweep, reward
funding) through mandates, distributing power across **five roles** with checks and balances.

> ## ⚠️ Demonstration / reference design — NOT a UK-compliant production system
>
> Nothing here is legal advice. Regulatory compliance for a staking product attaches to
> the **activity and entity** (FCA cryptoasset regime, s21 FSMA financial-promotions
> restriction, Money Laundering Regulations, etc.), **not** to how these mandates are
> wired — a governance layer cannot make an otherwise-regulated product lawful. The target
> `SimpleStakingPool` is a self-described **demo/mock**, and because its
> `stake()`/`unstake()`/`claim()` are permissionless, governance **cannot KYC/geo-gate
> stakers**. The Compliance Monitor role is a *risk-reducing* measure only. **Obtain
> qualified UK financial-services / crypto counsel before any real-money use.** See
> `Spec.md` for detail.

## Roles

| Role | Powers |
|------|--------|
| **Admin** | Bootstraps the system; appoints Guardian & Compliance Monitor; backstop |
| **Stakers** | Elected community; hold the veto, vote to un-pause, govern reform |
| **Rate Committee** | Elected stewards; propose & execute rate changes and sweeps |
| **Guardian** | Instant emergency pause (only) |
| **Compliance Monitor** | Records compliance findings (signal-only); shares the pause trip |

## Governance flows

Staker membership · Elect Rate Committee · Admin role administration · **Set reward rate**
(propose → Staker veto → 48h timelock → execute) · **Emergency pause / un-pause** (instant
pause, deliberate un-pause) · **Compliance monitoring** · **Sweep** (propose → veto → 7-day
timelock) · **Reform** (Staker supermajority) · **Fund / withdraw paymaster** (gasless).

## Prerequisites

Environment variables (see `.env.example`):

- `SEPOLIA_RPC_URL`, `ARB_SEPOLIA_RPC_URL`, `OPT_SEPOLIA_RPC_URL`
- `ETHERSCAN_API_KEY`
- A Foundry encrypted keystore: `DEPLOYER_ACCOUNT` and `DEPLOYER_ADDRESS`

Run `make setup-wallet` for keystore creation steps. The deployer must hold at least
**0.05 ETH** (to seed the paymaster) plus gas.

## Deployment

1. `cp .env.example .env.local` and fill in the values.
2. `make setup-wallet` → create an encrypted keystore.
3. Deploy: `make deploy-arb-sepolia` (or `make deploy-sepolia` / `make deploy-anvil`).

### Metadata URI

The `Deploy.s.sol` constructor currently passes an empty metadata URI (see the
`// TODO: set metadata URI` comment). Before a live deploy, upload a JSON file with `name`,
`description`, and optionally `image` to [Pinata](https://pinata.cloud) and paste the
resulting gateway URL into the `Powers(...)` constructor call.

## Actions script

`Actions.s.sol` (`StakingPoolGovernanceActions`) contains one helper per governance step —
propose, veto, fulfil, execute — used to drive a flow manually. Example (propose a reward
rate change):

```bash
forge script governance/staking-pool-governance/Actions.s.sol:StakingPoolGovernanceActions \
  --sig "proposeRewardRate(address,uint256,uint256[],uint256)" \
  <POWERS_ADDRESS> 3170000000 "[<committee_key>]" <nonce> \
  --rpc-url $SEPOLIA_RPC_URL --broadcast
```

## Runners script

`Runners.s.sol` (`StakingPoolGovernanceRunners`) is **stateless**: each `run*()` reads
on-chain state and advances the flow as far as current conditions allow, then stops at the
first phase blocked by a voting window or timelock. Ideal for automated/bot execution — call
it repeatedly with the same parameters + nonce. Example:

```bash
forge script governance/staking-pool-governance/Runners.s.sol:StakingPoolGovernanceRunners \
  --sig "runRewardRateFlow(address,uint256,uint256[],uint256)" \
  <POWERS_ADDRESS> 3170000000 "[<committee_key>]" <nonce> \
  --rpc-url $SEPOLIA_RPC_URL --broadcast
```

## Account Abstraction / Paymaster

A `PowersPaymaster` (ERC-4337) is deployed alongside the organisation and pre-funded with
**0.05 ETH**, so members can interact without paying gas themselves. When the balance runs
low, the Rate Committee tops it up via the **Fund Paymaster** flow. Check the balance:

```bash
cast call <PAYMASTER_ADDRESS> "getDeposit()(uint256)" --rpc-url $SEPOLIA_RPC_URL
```

The deployer wallet must hold at least 0.05 ETH plus gas at deploy time.

## Reward funding (note)

`fundRewards` is intentionally **not** exposed as a governance flow. Because
`rewardReserve()` reads `REWARD_TOKEN.balanceOf(pool)`, the reserve is topped up simply by
transferring reward tokens **directly to the pool address** — no mandate required.

## Testing

```bash
make test
```

Runs the fork-based suite (`StakingPoolGovernance_test`). Only `SEPOLIA_RPC_URL` is
required — no private-key env vars (the tests use synthetic accounts). The suite covers the
reward-rate flow (happy path + veto-blocks negative), Guardian instant pause, compliance
flag + Monitor pause, the Committee election (PeerSelect), and a sweep end-to-end.

> **Note on test discovery:** this org lives under `governance/`, outside Foundry's default
> `test/` directory. `make test` sets `FOUNDRY_TEST=governance/staking-pool-governance` so
> `forge` discovers the suite; a bare `forge test --match-contract StakingPoolGovernance_test`
> from the `solidity/` root will report "No tests found" without that override.

## Troubleshooting

**"contract size limit" error at deploy** — the project's `foundry.toml` must have optimizer
settings. Confirm `optimizer = true`, `optimizer_runs = 600`, `evm_version = "cancun"`, and
`solc_version = "0.8.30"` under `[profile.default]`, then `forge clean && forge build --sizes`.
(Inside this monorepo these are already set.)
