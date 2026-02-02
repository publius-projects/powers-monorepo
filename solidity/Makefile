# Makefile for Mantle Hackathon Solidity Project
# Standard commands for Foundry-based development

# 
-include .env

.PHONY: help build test test-verbose test-fuzz test-invariant coverage lint clean deploy-anvil deploy-sepolia deploy-mantle verify update-deps install-deps

# Default target
help:
	@echo "Available commands:"
	@echo "  build          - Compile contracts"
	@echo "  test           - Run all tests"
	@echo "  test-verbose   - Run tests with verbose output"
	@echo "  test-fuzz      - Run fuzz tests"
	@echo "  test-invariant - Run invariant tests"
	@echo "  coverage       - Generate coverage report"
	@echo "  lint           - Run linter"
	@echo "  clean          - Clean build artifacts"
	@echo "  deploy-anvil   - Deploy to local Anvil chain"
	@echo "  deploy-sepolia - Deploy to Sepolia testnet"
	@echo "  deploy-mantle  - Deploy to Mantle testnet"
	@echo "  verify         - Verify contracts on Etherscan"
	@echo "  update-deps    - Update dependencies"
	@echo "  install-deps   - Install dependencies"
	@echo "  reset-deps     - Reset dependencies"

# Build commands
build:
	@echo "Building contracts..."
	forge build

build-verbose:
	@echo "Building contracts with verbose output..."
	forge build -vvv

# Test commands
test:
	@echo "Running tests..."
	forge test

test-verbose:
	@echo "Running tests with verbose output..."
	forge test -vvv

test-fuzz:
	@echo "Running fuzz tests..."
	forge test --match-test testFuzz_ -vvv

test-invariant:
	@echo "Running invariant tests..."
	forge test --match-test invariant_ -vvv

test-specific:
	@echo "Running specific test: $(TEST)"
	forge test --match-test $(TEST) -vvv

test-contract:
	@echo "Running tests for contract: $(CONTRACT)"
	forge test --match-contract $(CONTRACT) -vvv

# Coverage
coverage:
	@echo "Generating coverage report..."
	forge coverage --report lcov
	@echo "Coverage report generated in lcov.info"

coverage-html:
	@echo "Generating HTML coverage report..."
	forge coverage --report html
	@echo "HTML coverage report generated in coverage/"

# Linting
lint:
	@echo "Running linter..."
	forge lint

lint-high:
	@echo "Running linter with high severity only..."
	forge lint --severity high

# Clean
clean:
	@echo "Cleaning build artifacts..."
	forge clean
	rm -rf out/
	rm -rf cache/

# Anvil commands
anvil:
	@echo "Starting Anvil local chain..."
	anvil

# Deployment commands
deploy-anvil:
	@echo "Deploying to local Anvil chain..."
	forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast -vvvv

deploy-sepolia:
	@echo "Deploying to Sepolia testnet..."
	forge script script/Deploy.s.sol --rpc-url sepolia --broadcast --verify -vvvv --interactives 1

deploy-mantle:
	@echo "Deploying to Mantle testnet..."
	forge script script/Deploy.s.sol --rpc-url mantle_testnet --broadcast --verify -vvvv --interactives 1

deploy-resume:
	@echo "Resuming deployment..."
	forge script script/Deploy.s.sol --rpc-url $(RPC_URL) --resume

# Verification
verify:
	@echo "Verifying contracts..."
	forge verify-contract $(CONTRACT_ADDRESS) $(CONTRACT_NAME) --chain-id $(CHAIN_ID) --etherscan-api-key $(ETHERSCAN_API_KEY)

# Dependency management
update-deps:
	@echo "Updating dependencies..."
	forge update

install-deps:
	@echo "Installing dependencies..."
	forge install foundry-rs/forge-std --no-commit --no-git || exit 1
	forge install openzeppelin/openzeppelin-contracts@v5.0.2 --no-commit --no-git || exit 1
	forge install smartcontractkit/chainlink-evm@contracts-v1.4.0 --no-commit --no-git || exit 1
	forge install smartcontractkit/chainlink-ccip@contracts-ccip-v1.6.0 --no-commit --no-git || exit 1
	forge install safe-fndn/safe-smart-account@v1.4.1 --no-commit --no-git || exit 1

reset-deps:
	@echo "Resetting dependencies..."
	@rm -rf lib/
	@mkdir -p lib
	@forge install foundry-rs/forge-std --no-git || exit 1
	@forge install openzeppelin/openzeppelin-contracts@v5.0.2 --no-git || exit 1
	@forge install smartcontractkit/chainlink-evm@contracts-v1.4.0 --no-git || exit 1
	@forge install smartcontractkit/chainlink-ccip@contracts-ccip-v1.6.0 --no-git || exit 1
	@forge install safe-fndn/safe-smart-account@v1.4.1 --no-git || exit 1
	@forge install safe-fndn/safe-modules --no-git || exit 1
	@echo "Dependencies reset complete. All libs installed without git metadata."

# Documentation
doc:
	@echo "Generating documentation..."
	forge doc

doc-serve:
	@echo "Serving documentation..."
	forge doc --serve

# Gas reporting
gas-report:
	@echo "Generating gas report..."
	forge test --gas-report

# Snapshot
snapshot:
	@echo "Creating gas snapshot..."
	forge snapshot

# Size analysis
size:
	@echo "Analyzing contract sizes..."
	forge build --sizes

# Security analysis
security:
	@echo "Running security analysis..."
	forge build
	forge inspect $(CONTRACT) methods
	forge inspect $(CONTRACT) abi

# Environment setup
setup-env:
	@echo "Setting up environment..."
	@if [ ! -f .env ]; then \
		echo "Creating .env file from template..."; \
		cp .env.example .env; \
		echo "Please update .env with your configuration"; \
	else \
		echo ".env file already exists"; \
	fi

# Quick development workflow
dev: clean build test lint
	@echo "Development workflow completed"

# Full CI/CD workflow
ci: clean build test-verbose coverage lint
	@echo "CI/CD workflow completed"

# Helpers for specific networks
deploy-sepolia-dry:
	@echo "Simulating deployment to Sepolia..."
	forge script script/Deploy.s.sol --rpc-url sepolia -vvvv

deploy-mantle-dry:
	@echo "Simulating deployment to Mantle..."
	forge script script/Deploy.s.sol --rpc-url mantle_testnet -vvvv

# Contract interaction helpers
call:
	@echo "Making contract call..."
	cast call $(CONTRACT_ADDRESS) $(FUNCTION_SIG) $(ARGS) --rpc-url $(RPC_URL)

send:
	@echo "Sending transaction..."
	cast send $(CONTRACT_ADDRESS) $(FUNCTION_SIG) $(ARGS) --rpc-url $(RPC_URL) --private-key $(PRIVATE_KEY)

# Debug helpers
debug-test:
	@echo "Debugging test: $(TEST)"
	forge test --match-test $(TEST) -vvvv

trace:
	@echo "Tracing transaction: $(TX_HASH)"
	cast run $(TX_HASH) --rpc-url $(RPC_URL) -vvvv

# Network info
block-info:
	@echo "Getting block information..."
	cast block latest --rpc-url $(RPC_URL)

gas-price:
	@echo "Getting current gas price..."
	cast gas-price --rpc-url $(RPC_URL)

# Contract verification helpers
flatten:
	@echo "Flattening contract: $(CONTRACT)"
	forge flatten src/$(CONTRACT).sol

# Advanced testing
test-fork:
	@echo "Running fork tests..."
	forge test --match-test testFork_ -vvv

test-gas:
	@echo "Running gas tests..."
	forge test --gas-report --match-test testGas_

# Development shortcuts
watch:
	@echo "Watching for changes and running tests..."
	while inotifywait -r -e modify src/ test/; do \
		forge test; \
	done

# Project initialization
init-project:
	@echo "Initializing project structure..."
	mkdir -p src/interfaces
	mkdir -p src/libraries
	mkdir -p src/abstracts
	mkdir -p test/unit
	mkdir -p test/integration
	mkdir -p test/fuzz
	mkdir -p test/invariant
	mkdir -p test/fork
	mkdir -p test/utils
	mkdir -p script
	mkdir -p docs
	@echo "Project structure created"

# Show project info
info:
	@echo "Project Information:"
	@echo "===================="
	@echo "Foundry version: $(shell forge --version)"
	@echo "Solidity version: $(shell grep 'solc_version' foundry.toml | cut -d'=' -f2 | tr -d ' "')"
	@echo "Dependencies:"
	@ls lib/
	@echo ""
	@echo "Available contracts:"
	@find src/ -name "*.sol" -type f 2>/dev/null || echo "No contracts found in src/"
	@echo ""
	@echo "Available tests:"
	@find test/ -name "*.t.sol" -type f 2>/dev/null || echo "No tests found in test/" 

update-builds:
	@echo "Updating builds..."
	for contract in ERC20 Erc20Taxed SimpleErc20Votes Mandate Nominees Ownable OpenElection Powers TreasuryPoolGovernance TreasuryPools TreasuryPoolTransfer TreasuryRoleWithTransfer TreasurySimple; do cp out/$${contract}.sol/$${contract}.json ../frontend/context/builds/$${contract}.json; done
	
###############################
# 		Deploy Commands  	  # 
###############################

# Deployment arguments for different networks
ANVIL_DEPLOY_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY_0) --broadcast --ffi -vv
SEPOLIA_DEPLOY_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --account dev_3 --sender ${DEV2_ADDRESS} --broadcast --etherscan-api-key $(ETHERSCAN_API_KEY) --verifier etherscan --chain 11155111 --verify --ffi -vv
ARB_SEPOLIA_DEPLOY_ARGS := --rpc-url $(ARB_SEPOLIA_RPC_URL) --account dev_3 --sender ${DEV2_ADDRESS} --broadcast --etherscan-api-key $(ETHERSCAN_API_KEY) --verifier etherscan --chain 421614 --verify --ffi -vv 
OPT_SEPOLIA_DEPLOY_ARGS := --rpc-url $(OPT_SEPOLIA_RPC_URL) --account dev_3 --sender ${DEV2_ADDRESS} --broadcast --etherscan-api-key $(ETHERSCAN_API_KEY) --verifier etherscan --chain 11155420 --verify --ffi -vv

# create forked anvil chain. 
# included in .env are SEPOLIA_RPC_URL, ARB_SEPOLIA_RPC_URL, OPT_SEPOLIA_RPC_URL
fork-anvil :
	anvil --fork-url $(OPT_SEPOLIA_RPC_URL) --block-time 1 --chain-id 31337   

deploy-allowance-module :; forge script script/DeployAllowanceModule.s.sol:DeployAllowanceModule $(OPT_SEPOLIA_DEPLOY_ARGS) 

# Deploy an organisation to a single chain. 
# Adjust the ANVIL_DEPLOY_ARGS, SEPOLIA_DEPLOY_ARGS, OPT_SEPOLIA_DEPLOY_ARGS, ARB_SEPOLIA_DEPLOY_ARGS variables above to change network and deployment settings.
# Adjust the script path and contract name below to change which organisation is deployed.
# NOTE: all mandates and helper contracts will be deployed as part of the organisation deployment script. 
deploy-organisation : 
	@echo "Deploying organisation..."
	forge script script/deployOrganisations/TestRig.s.sol:TestRig $(ANVIL_DEPLOY_ARGS)

initialise-powers :
	@echo "Initialising Powers contract..."
	forge script script/InitialisePowers.s.sol:InitialisePowers $(SEPOLIA_DEPLOY_ARGS)

# Verify Contracts
# sepoliaVerifyContract :; forge verify-contract --etherscan-api-key $(ETHERSCAN_API_KEY) --chain 11155111 --verifier etherscan 0x05c0379565ef0ebb1bD21C0Ab463ca5CE5211D3A src/Powers.sol:Powers --watch
optSepoliaVerifyContract :; forge verify-contract --etherscan-api-key $(ETHERSCAN_API_KEY) --chain 11155420 --compiler-version 0.8.26 --num-of-optimizations 600 --verifier etherscan 0x6f8c6ac58a467836D85548Bf2Fef473D5efcFeA4 src/helpers/TreasuryPools.sol:TreasuryPools --watch
arbSepoliaVerifyContract :; forge verify-contract --etherscan-api-key $(ETHERSCAN_API_KEY) --chain 421614 --compiler-version 0.8.26 --num-of-optimizations 600 --verifier etherscan 0xb1fe867eE7919887EB381c4626bdbAe003969683 src/helpers/TreasuryPools.sol:TreasuryPools --watch

deploy-mandatePackages-sepolia :; forge script script/DeployMandatePackages.s.sol:DeployMandatePackages $(SEPOLIA_DEPLOY_ARGS)
deploy-mandatePackages-op-sepolia :; forge script script/DeployMandatePackages.s.sol:DeployMandatePackages $(OPT_SEPOLIA_DEPLOY_ARGS)
deploy-mandatePackages-arb-sepolia :; forge script script/DeployMandatePackages.s.sol:DeployMandatePackages $(ARB_SEPOLIA_DEPLOY_ARGS)