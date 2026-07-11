-include ../../.env
-include .env.local

SCRIPT   = governance/staking-pool-governance/Deploy.s.sol:Deploy
TEST     = StakingPoolGovernance_test
TEST_DIR = governance/staking-pool-governance

# Wallet — set DEPLOYER_ACCOUNT and DEPLOYER_ADDRESS in .env.local
# (copy .env.example to .env.local and follow the instructions inside)

ANVIL_DEPLOY_ARGS       := --rpc-url http://localhost:8545 \
                            --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
                            --broadcast --ffi -vv

SEPOLIA_DEPLOY_ARGS     := --rpc-url $(SEPOLIA_RPC_URL) \
                            --account $(DEPLOYER_ACCOUNT) --sender $(DEPLOYER_ADDRESS) \
                            --broadcast -vv

ARB_SEPOLIA_DEPLOY_ARGS := --rpc-url $(ARB_SEPOLIA_RPC_URL) \
                            --account $(DEPLOYER_ACCOUNT) --sender $(DEPLOYER_ADDRESS) \
                            --broadcast --etherscan-api-key $(ETHERSCAN_API_KEY) \
                            --verifier etherscan --chain 421614 --verify --ffi -vv

OPT_SEPOLIA_DEPLOY_ARGS := --rpc-url $(OPT_SEPOLIA_RPC_URL) \
                            --account $(DEPLOYER_ACCOUNT) --sender $(DEPLOYER_ADDRESS) \
                            --broadcast --chain 11155420 --ffi -vv

.PHONY: help deploy-anvil deploy-sepolia deploy-arb-sepolia deploy-opt-sepolia test setup-wallet check-wallet

help:
	@echo "Available targets:"
	@echo "  deploy-anvil        Deploy to local Anvil (no wallet setup needed)"
	@echo "  deploy-sepolia      Deploy to Ethereum Sepolia"
	@echo "  deploy-arb-sepolia  Deploy to Arbitrum Sepolia"
	@echo "  deploy-opt-sepolia  Deploy to Optimism Sepolia"
	@echo "  test                Run tests (Sepolia fork; needs SEPOLIA_RPC_URL)"
	@echo "  setup-wallet        Print wallet setup instructions"
	@echo "  check-wallet        Verify wallet variables are configured"

setup-wallet:
	@echo ""
	@echo "=== Wallet setup for live network deployments ==="
	@echo ""
	@echo "1. Create an encrypted keystore (you will be prompted for a password):"
	@echo "      cast wallet import my-wallet --interactive"
	@echo ""
	@echo "2. Get the Ethereum address of that keystore:"
	@echo "      cast wallet address --account my-wallet"
	@echo ""
	@echo "3. Copy .env.example to .env.local and fill in the values:"
	@echo "      cp .env.example .env.local"
	@echo "      # then edit .env.local"
	@echo ""
	@echo "4. Fund the deployer address on the target network with ETH for gas"
	@echo "   (plus at least 0.05 ETH to seed the paymaster)."
	@echo ""

check-wallet:
	@test -n "$(DEPLOYER_ACCOUNT)" || (echo "ERROR: DEPLOYER_ACCOUNT is not set. Run 'make setup-wallet' for instructions."; exit 1)
	@test -n "$(DEPLOYER_ADDRESS)" || (echo "ERROR: DEPLOYER_ADDRESS is not set. Run 'make setup-wallet' for instructions."; exit 1)
	@echo "Wallet OK: $(DEPLOYER_ADDRESS)  (keystore: $(DEPLOYER_ACCOUNT))"

deploy-anvil:
	cd ../.. && forge script $(SCRIPT) $(ANVIL_DEPLOY_ARGS)

deploy-sepolia: check-wallet
	cd ../.. && forge script $(SCRIPT) $(SEPOLIA_DEPLOY_ARGS)

deploy-arb-sepolia: check-wallet
	cd ../.. && forge script $(SCRIPT) $(ARB_SEPOLIA_DEPLOY_ARGS)

deploy-opt-sepolia: check-wallet
	cd ../.. && forge script $(SCRIPT) $(OPT_SEPOLIA_DEPLOY_ARGS)

# This org's files live under governance/, which is outside Foundry's default `test`
# directory, so FOUNDRY_TEST points discovery at this folder for the run.
test:
	cd ../.. && FOUNDRY_TEST=$(TEST_DIR) forge test --match-contract $(TEST) -vvv
