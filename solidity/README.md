<p align="center">

<br />
<div align="center">
  <a href="https://github.com/7Cedars/powers"> 
    <img src="../powers_icon_notext.svg" alt="Logo" width="300" height="300">
  </a>

<h2 align="center"> Powers protocol </h2>
  <p align="center">
    Institutional governance for on-chain organisations. 
    <br />
    <br />
    <a href="#whats-included">What's included</a> ·
    <a href="#how-it-works">How it works</a> ·
    <a href="#prerequisites">Prerequisites</a> ·
    <a href="#getting-started">Getting Started</a>
  </p>
  <br />
  <br />
</div>

## What's included
- A fully functional proof-of-concept of the Powers governance protocol (v0.4). It allows for the creation of modular and flexible rule based governance in on-chain organisations.  
- Electoral mandates that enable different ways to assign roles to accounts. 
- Executive mandates that enable different ways to role restrict and call external functions.
- Example constitutions and founders documents needed to initialize organisations.
- Example implementations of organisations building on the Powers protocol.
- Comprehensive unit, integration, fuzz and invariant tests.

## How it works
In Powers actions need to be executed through role restricted contracts, called mandates. These mandates give role holders the power to transform pre-defined input into executable calldata. Aside from being role restricted, execution can also be conditional on the execution of another mandate. This allows for the creation of checks and balances between roles, and the creation of any type of rule based governance structure.       

As such, there are several key differences between {Powers.sol} and the often used {Governor.sol}:  
- Any action needs to be encoded in role-restricted external contracts, or mandates, that follow the {IMandate.sol} interface.
- Proposing, voting, cancelling and executing actions are role-restricted along the target mandate that is called.
- All actions need to run through the governance protocol. Calls to mandates that do not need a proposal vote to be executed still need to be executed through {Powers::execute}.
- The core protocol uses a non-weighted voting mechanism: one account has one vote.
- The core protocol is minimalistic. Any complexity (timelock, delayed execution, guardian roles, weighted votes, staking, etc.) has to be integrated through mandates.

Mandates are role-restricted contracts that provide the following functionalities:
- Transforming a mandateCalldata input into an output of targets[], values[], calldatas[] to be executed by the Powers protocol
- Adding conditions to the execution of the mandate. Any conditional logic can be added to a mandate, but the standard implementation supports the following:   
  - A vote quorum, threshold and period in case the mandate needs a proposal vote to pass before being executed  
  - A parent mandate that needs to be completed before the mandate can be executed
  - A parent mandate that needs to NOT be completed before the mandate can be executed
  - A vote delay: an amount of time in blocks that needs to have passed since the proposal vote ended before the mandate can be executed 
  - A minimum amount of blocks that need to have passed since the previous execution before the mandate can be executed again 

The combination of checks and execution logics allows for creating almost any type of governance infrastructure with a minimum number of mandates. For example implementations, see the `/test/TestConstitutions.sol` file.

## Directory Structure

```
solidity/
├── .github/                                   # GitHub configuration
├── audits/                                    # Security audit reports
├── broadcast/                                 # Deployment broadcast files
├── cache/                                     # Foundry cache
├── lib/                                       # Installed dependencies
│    ├── forge-std/                            # Forge standard library
│    └── openzeppelin-contracts/               # OpenZeppelin contracts
│
├── out/                                       # Compilation output
├── powered/                                   # Chain specific deployment addresses of protocol contracts
├── script/                                    # Deployment scripts
│    ├── InitialiseHelpers.s.sol                     # Deploys mock contracts
│    ├── DeployTestOrgs.s.sol                  # Deploys a test organisation
│    ├── FundTreasury.s.sol                    # Funds a treasury
│    ├── Configuration.s.sol                    # Helper configuration
│    └── InitialisePowers.s.sol                # Initialises the Powers protocol
│
├── src/                                       # Protocol resources
│    ├── helpers/                              # Helper contracts
│    ├── interfaces/                           # Protocol interfaces
│    ├── mandates/                                 # Mandate implementations
│    │    ├── async/                           # Asynchronous mandates
│    │    ├── electoral/                       # Electoral mandates
│    │    ├── executive/                       # Executive mandates
│    │    ├── integrations/                    # Integration mandates
│    │    └── metadata/                        # Metadata for mandates
│    ├── libraries/                            # Solidity libraries
│    ├── Mandate.sol                               # Core Mandate contract
│    └── Powers.sol                            # Core protocol contract
│
├── test/                                      # Tests
│    ├── fuzz/                                 # Fuzz tests
│    ├── integration/                          # Integration tests
│    ├── mocks/                                # Mock contracts for testing
│    ├── unit/                                 # Unit tests
│    ├── TestConstitutions.sol                 # Constitution tests
│    └── TestSetup.t.sol                       # Test environment setup
│
├── .env.example                               # Environment variables template
├── .gitignore                                 # Git ignore rules
├── .gitmodules                                # Git submodules
├── foundry.toml                               # Foundry configuration
├── lcov.info                                  # Test coverage information
├── Makefile                                   # Build and test commands
└── README.md                                  # Project documentation

```

## Prerequisites

Foundry<br>

## Getting Started

1. Clone this repo locally and move to the solidity folder:

```sh
git clone https://github.com/7Cedars/powers
cd powers/solidity 
```

2. Copy `.env.example` to `.env` and update the variables.

```sh
cp .env.example .env
```

3. Run make. This will install all dependencies and run the tests. 

```sh
make
```

4. Run the tests without installing packages: 

```sh
forge test 
```

## Security and Liability
All contracts are WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. They have NOT been fully audited. THESE CONTRACTS ARE ONLY MEANT FOR DEMO PURPOSES. DO NOT USE IN PRODUCTION CODE.  

## Acknowledgements 
Code is derived from OpenZeppelin's Governor.sol and AccessManager contracts, in addition to Haberdasher Labs Hats protocol. The Powers protocol (v0.4) represents a significant evolution in role-based governance systems for on-chain organ.
