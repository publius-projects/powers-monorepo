-include ../../.env
-include .env.local

# forge reads TEST_ACCOUNT_KEY_* from the process env (vm.envUint in DeployHelpers).
# Make doesn't export -include'd vars to recipes by default, so export them explicitly.
export TEST_ACCOUNT_KEY_1
export TEST_ACCOUNT_KEY_2
export TEST_ACCOUNT_KEY_3

SCRIPT   = governance/powers-protocol-federation/Deploy.s.sol:Deploy
TEST     = PowersProtocolFederation_test
# forge's default test discovery only scans the `test/` dir; point it at this
# org folder so `forge test` finds Test.t.sol under governance/.
TEST_DIR = governance/powers-protocol-federation

# Wallet — set DEPLOYER_ACCOUNT and DEPLOYER_ADDRESS in .env.local
# (copy .env.example to .env.local and follow the instructions inside)

ANVIL_DEPLOY_ARGS       := --rpc-url http://localhost:8545 \
                            --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
                            --broadcast --ffi -vv

SEPOLIA_DEPLOY_ARGS     := --rpc-url $(SEPOLIA_RPC_URL) \
                            --account $(DEPLOYER_ACCOUNT) --sender $(DEPLOYER_ADDRESS) \
                            --broadcast --etherscan-api-key $(ETHERSCAN_API_KEY) \
                            --verifier etherscan --chain 11155111 --verify --ffi -vv \
                            --priority-gas-price 2gwei

ARB_SEPOLIA_DEPLOY_ARGS := --rpc-url $(ARB_SEPOLIA_RPC_URL) \
                            --account $(DEPLOYER_ACCOUNT) --sender $(DEPLOYER_ADDRESS) \
                            --broadcast --etherscan-api-key $(ETHERSCAN_API_KEY) \
                            --verifier etherscan --chain 421614 --verify --ffi -vv

OPT_SEPOLIA_DEPLOY_ARGS := --rpc-url $(OPT_SEPOLIA_RPC_URL) \
                            --account $(DEPLOYER_ACCOUNT) --sender $(DEPLOYER_ADDRESS) \
                            --broadcast --etherscan-api-key $(ETHERSCAN_API_KEY) \
                            --chain 11155420 --ffi -vv

.PHONY: help deploy-anvil deploy-sepolia deploy-sepolia-resume deploy-arb-sepolia deploy-opt-sepolia test test-nonce setup-wallet check-wallet

help:
	@echo "Available targets:"
	@echo "  deploy-anvil        Deploy to local Anvil (no wallet setup needed)"
	@echo "  deploy-sepolia      Deploy to Ethereum Sepolia (recommended — Aave v3 + canonical MandateRegistry live here)"
	@echo "  deploy-sepolia-resume  Continue an interrupted deploy-sepolia run (same contracts, no redeploy)"
	@echo "  deploy-arb-sepolia  Deploy to Arbitrum Sepolia (no canonical MandateRegistry — deploy one first)"
	@echo "  deploy-opt-sepolia  Deploy to Optimism Sepolia"
	@echo "  test                Run tests (Ethereum Sepolia fork)"
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
	@echo "   (at least 0.15 ETH plus gas, to seed the central paymaster)."
	@echo ""

check-wallet:
	@test -n "$(DEPLOYER_ACCOUNT)" || (echo "ERROR: DEPLOYER_ACCOUNT is not set. Run 'make setup-wallet' for instructions."; exit 1)
	@test -n "$(DEPLOYER_ADDRESS)" || (echo "ERROR: DEPLOYER_ADDRESS is not set. Run 'make setup-wallet' for instructions."; exit 1)
	@echo "Wallet OK: $(DEPLOYER_ADDRESS)  (keystore: $(DEPLOYER_ACCOUNT))"

deploy-anvil:
	cd ../.. && forge script $(SCRIPT) $(ANVIL_DEPLOY_ARGS)

deploy-sepolia: check-wallet
	cd ../.. && forge script $(SCRIPT) $(SEPOLIA_DEPLOY_ARGS)

# Continue an interrupted deploy-sepolia run on the SAME contracts (no redeploy).
deploy-sepolia-resume: check-wallet
	cd ../.. && forge script $(SCRIPT) $(SEPOLIA_DEPLOY_ARGS) --resume

deploy-arb-sepolia: check-wallet
	cd ../.. && forge script $(SCRIPT) $(ARB_SEPOLIA_DEPLOY_ARGS)

deploy-opt-sepolia: check-wallet
	cd ../.. && forge script $(SCRIPT) $(OPT_SEPOLIA_DEPLOY_ARGS)

test-nonce:
	@echo "latest : $$(cast nonce --rpc-url $(SEPOLIA_RPC_URL) $(DEPLOYER_ADDRESS))"
	@echo "pending: $$(cast nonce --rpc-url $(SEPOLIA_RPC_URL) --block pending $(DEPLOYER_ADDRESS))"


test:
	cd ../.. && FOUNDRY_TEST=$(TEST_DIR) forge test --match-contract $(TEST) -vvv
