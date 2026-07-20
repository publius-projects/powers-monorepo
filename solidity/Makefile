# Makefile for Mantle Hackathon Solidity Project
# Standard commands for Foundry-based development

# 
-include .env

.PHONY: help build test test-verbose test-fuzz test-invariant coverage lint clean deploy-anvil deploy-sepolia deploy-mantle verify update-deps install-deps reset-deps

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
	forge install foundry-rs/forge-std || exit 1
	forge install openzeppelin/openzeppelin-contracts@v5.6.1  || exit 1
	forge install smartcontractkit/chainlink-evm@contracts-v1.4.0  || exit 1
	forge install smartcontractkit/chainlink-ccip@contracts-ccip-v1.6.0  || exit 1
	forge install safe-fndn/safe-smart-account@v1.4.1 || exit 1
	forge install safe-fndn/safe-modules || exit 1
	forge install zkpassport/zkpassport-packages || exit 1
	forge install eth-infinitism/account-abstraction@v0.7.0 || exit 1
	@echo "Dependencies installed as git submodules (see .gitmodules / foundry.lock)."


reset-deps:
	@echo "Resetting dependencies (submodule teardown + reinstall)..."
	@ROOT=$$(git rev-parse --show-toplevel); \
	for d in forge-std openzeppelin-contracts chainlink-evm chainlink-ccip \
	         safe-smart-account safe-modules account-abstraction zkpassport-packages; do \
		echo "  removing lib/$$d"; \
		git submodule deinit -f "solidity/lib/$$d" 2>/dev/null || true; \
		git rm -f "solidity/lib/$$d" 2>/dev/null || true; \
		rm -rf "solidity/lib/$$d"; \
		rm -rf "$$ROOT/.git/modules/solidity/lib/$$d"; \
	done; \
	rm -rf lib foundry.lock; \
	mkdir -p lib
	@echo "Reinstalling dependencies (pinned = @tag, unpinned = latest)..."
	@forge install foundry-rs/forge-std || exit 1
	@forge install openzeppelin/openzeppelin-contracts@v5.6.1 || exit 1
	@forge install smartcontractkit/chainlink-evm@contracts-v1.4.0 || exit 1
	@forge install smartcontractkit/chainlink-ccip@contracts-ccip-v1.6.0 || exit 1
	@forge install safe-fndn/safe-smart-account@v1.4.1 || exit 1
	@forge install safe-fndn/safe-modules || exit 1
	@forge install zkpassport/zkpassport-packages || exit 1
	@forge install eth-infinitism/account-abstraction@v0.7.0 || exit 1
	@echo "reset-deps complete. Review 'git status' + foundry.lock, then commit."

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
	for contract in ERC20 Erc20Taxed SimpleErc20Votes Erc20DelegateElection Mandate Nominees Ownable Powers ZKPassport_Check ZKPassport_PowersRegistry; do cp out/$${contract}.sol/$${contract}.json ../frontend/context/builds/$${contract}.json; done
	
###############################
# 		Deploy Commands  	  # 
###############################

# Deployment arguments for different networks
 
ANVIL_DEPLOY_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY_0) --broadcast --ffi -vv
# NB: turned off verify --verify NB: I now verify the contracts seperately. See below. 
# --etherscan-api-key $(ETHERSCAN_API_KEY) --verifier etherscan --chain 11155111 --verify 
SEPOLIA_DEPLOY_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --account dev_3 --sender ${DEV2_ADDRESS}  --broadcast --etherscan-api-key $(ETHERSCAN_API_KEY) --verifier etherscan --chain 11155111 --verify -vv

ARB_SEPOLIA_DEPLOY_ARGS := --rpc-url $(ARB_SEPOLIA_RPC_URL) --account dev_3 --sender ${DEV2_ADDRESS} --broadcast --etherscan-api-key $(ETHERSCAN_API_KEY) --verifier etherscan --chain 421614 --verify --ffi -vv 
OPT_SEPOLIA_DEPLOY_ARGS := --rpc-url $(OPT_SEPOLIA_RPC_URL) --account dev_3 --sender ${DEV2_ADDRESS} --broadcast --etherscan-api-key $(ETHERSCAN_API_KEY) --chain 11155420 --ffi -vv

# fund dev address on local chain.  
fund-dev :
	cast send --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY_0) ${DEV2_ADDRESS} --value 1ether 

# create forked anvil chain. 
# included in .env are SEPOLIA_RPC_URL, ARB_SEPOLIA_RPC_URL, OPT_SEPOLIA_RPC_URL
fork-anvil : 
	anvil --fork-url $(SEPOLIA_RPC_URL) --block-time 12 --chain-id 31337   

# Deploy an organisation to a single chain. 
# Adjust the ANVIL_DEPLOY_ARGS, SEPOLIA_DEPLOY_ARGS, OPT_SEPOLIA_DEPLOY_ARGS, ARB_SEPOLIA_DEPLOY_ARGS variables above to change network and deployment settings.
# Adjust the script path and contract name below to change which organisation is deployed.
# NOTE: all mandates and helper contracts will be deployed as part of the organisation deployment script. 
registry-deploy : 
	@echo "Deploying mandate registry..."
	forge script script/DeployMandates.s.sol:DeployMandates $(SEPOLIA_DEPLOY_ARGS)

mandates-deploy : 
	@echo "Deploying mandates..."
	forge script script/DeployMandates.s.sol:DeployMandates $(ARB_SEPOLIA_DEPLOY_ARGS)

examples-deploy : 
	@echo "Deploying example contracts..."
	@echo "Account Abstraction:"
	forge script governance/examples/AccountAbstraction.s.sol:Deploy $(ARB_SEPOLIA_DEPLOY_ARGS) 
	@echo "Bicameralism:"
	forge script governance/examples/Bicameralism.s.sol:Deploy $(ARB_SEPOLIA_DEPLOY_ARGS) 
	@echo "Election List:"
	forge script governance/examples/ElectionListsDao.s.sol:Deploy $(ARB_SEPOLIA_DEPLOY_ARGS) 
	@echo "Governed 721:"
	forge script governance/examples/Governed721.s.sol:Deploy $(ARB_SEPOLIA_DEPLOY_ARGS) 
	@echo "Nested Safe Governance:"
	forge script governance/examples/NestedSafeGovernance.s.sol:Deploy $(ARB_SEPOLIA_DEPLOY_ARGS) 
	@echo "Optimistic Execution:"
	forge script governance/examples/OptimisticExecution.s.sol:Deploy $(ARB_SEPOLIA_DEPLOY_ARGS) 
	@echo "Powers 101:"
	forge script governance/examples/Powers101.s.sol:Deploy $(ARB_SEPOLIA_DEPLOY_ARGS)
	@echo "Token Delegates:"
	forge script governance/examples/TokenDelegates.s.sol:Deploy $(ARB_SEPOLIA_DEPLOY_ARGS)
	@echo "All example contracts deployed."

claude-org-deploy : 
	@echo "Deploying organisation..."
	forge script governance/claude/mandate-sandbox/Deploy.s.sol:Deploy $(ARB_SEPOLIA_DEPLOY_ARGS) 

organisation-deploy : 
	@echo "Deploying organisation..."
	forge script governance/publius-registry/Deploy.s.sol:Deploy $(SEPOLIA_DEPLOY_ARGS) 

governed721-deploy : 
	@echo "Deploying convergence layer contracts..."
	./governance/examples/bash/deploy_governed721.sh "" "" "" $(SEPOLIA_DEPLOY_ARGS)

zkpassport-registry-deploy : 
	@echo "Deploying ZKPassport Registry..."
	forge script script/DeployZKPassportPowersRegistry.s.sol:DeployZKPassportPowersRegistry $(SEPOLIA_DEPLOY_ARGS)

# deploy-zkregistry : 
# 	@echo "Deploying ZKPassport Registry..."
# 	forge script script/DeployZKPassportRegistry.s.sol:DeployZKPassportRegistry $(SEPOLIA_DEPLOY_ARGS)

# deploy allowance module to Sepolia. Only needs to be done once.
deploy-allowance-module :; forge script script/DeployAllowanceModule.s.sol:DeployAllowanceModule $(OPT_SEPOLIA_DEPLOY_ARGS) 

# Verify Contracts
# Powers 
# Mandates 
# AsyncMandates
# PowersPaymaster
# Soulbound1155
# Governed721
# ElectionRegistry
# ZKPassportPowersRegistry
sepoliaVerifyContract :
#	forge verify-contract --etherscan-api-key $(ETHERSCAN_API_KEY) --chain 11155111 --verifier etherscan 0xfF28EE3bc457bf8389E71929057a53b3f9b1c98c src/addons/helpers/PowersPaymaster.sol:PowersPaymaster --watch
	forge verify-contract --etherscan-api-key $(ETHERSCAN_API_KEY) --chain 11155111 --verifier etherscan 0x78f9De1Fad256FA3B06ED60AF6F3aeF349155AdF src/Powers.sol:Powers --watch
# 	forge verify-contract --etherscan-api-key $(ETHERSCAN_API_KEY) --chain 11155111 --verifier etherscan 0x461744992a27B746cCC27969F571Fe0db037c6fE src/Mandate.sol:Mandate --watch
# 	forge verify-contract --etherscan-api-key $(ETHERSCAN_API_KEY) --chain 11155111 --verifier etherscan 0x1Aa34502237AD69D699A8eDcF6eab7DB454F1373 src/AsyncMandate.sol:AsyncMandate --watch 
 	
# 	forge verify-contract --etherscan-api-key $(ETHERSCAN_API_KEY) --chain 11155111 --verifier etherscan 0x461744992a27B746cCC27969F571Fe0db037c6fE src/helpers/Soulbound1155.sol:Soulbound1155 --watch
# 	forge verify-contract --etherscan-api-key $(ETHERSCAN_API_KEY) --chain 11155111 --verifier etherscan 0x05A9d9FaAE1fc11C6Aa3993e55c38dB4F2B28a19 src/addons/helpers/Governed721.sol:Governed721 --watch 
# 	forge verify-contract --etherscan-api-key $(ETHERSCAN_API_KEY) --chain 11155111 --verifier etherscan 0xdE4188f007f4FfbD26E6dCE2cC108354a5995ed9 src/core/helpers/ElectionRegistry.sol:ElectionRegistry --watch
# 	forge verify-contract --etherscan-api-key $(ETHERSCAN_API_KEY) --chain 11155111 --verifier etherscan 0xc554958CE7559eCcD08AEdbB8b72B1BE54Fde9ed src/addons/helpers/ZKPassport_PowersRegistry.sol:ZKPassport_PowersRegistry --watch


optSepoliaVerifyContract :; forge verify-contract --etherscan-api-key $(ETHERSCAN_API_KEY) --chain 11155420 --compiler-version 0.8.26 --num-of-optimizations 600 --verifier etherscan 0x6f8c6ac58a467836D85548Bf2Fef473D5efcFeA4 src/helpers/TreasuryPools.sol:TreasuryPools --watch
arbSepoliaVerifyContract :; forge verify-contract --etherscan-api-key $(ETHERSCAN_API_KEY) --chain 421614 --compiler-version 0.8.26 --num-of-optimizations 600 --verifier etherscan 0xb1fe867eE7919887EB381c4626bdbAe003969683 src/helpers/TreasuryPools.sol:TreasuryPools --watch

deploy-mandatePackages-sepolia :; forge script script/DeployMandatePackages.s.sol:DeployMandatePackages $(SEPOLIA_DEPLOY_ARGS)
deploy-mandatePackages-op-sepolia :; forge script script/DeployMandatePackages.s.sol:DeployMandatePackages $(OPT_SEPOLIA_DEPLOY_ARGS)
deploy-mandatePackages-arb-sepolia :; forge script script/DeployMandatePackages.s.sol:DeployMandatePackages $(ARB_SEPOLIA_DEPLOY_ARGS)