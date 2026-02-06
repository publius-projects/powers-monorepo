// SPDX-License-Identifier: UNLICENSED
// This setup is an adaptation from the Hats protocol test. See //
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// protocol
import { Powers } from "../src/Powers.sol";
import { Mandate } from "../src/Mandate.sol";
import { PowersErrors } from "../src/interfaces/PowersErrors.sol";
import { PowersTypes } from "../src/interfaces/PowersTypes.sol";
import { PowersEvents } from "../src/interfaces/PowersEvents.sol";
import { Configurations } from "../script/Configurations.s.sol";
import { TestConstitutions } from "./TestConstitutions.sol"; 
import { console2 } from "forge-std/console2.sol";

// deploy scripts
import { InitialisePowers } from "../script/InitialisePowers.s.sol";
import { PowersMock } from "@mocks/PowersMock.sol";
import { SimpleErc20Votes } from "@mocks/SimpleErc20Votes.sol";

// organisations
import { Powers101 } from "../script/deployOrganisations/Powers101.s.sol";
import { ElectionListsDAO } from "../script/deployOrganisations/ElectionListsDAO.s.sol";
import { CulturalStewardsDAO } from "../script/deployOrganisations/CulturalStewardsDAO.s.sol";

// helpers
import { Nominees } from "@src/helpers/Nominees.sol";
import { ElectionList } from "@src/helpers/ElectionList.sol";
import { Erc20DelegateElection } from "@mocks/Erc20DelegateElection.sol";
import { FlagActions } from "@src/helpers/FlagActions.sol";
import { SimpleGovernor } from "@mocks/SimpleGovernor.sol";
import { SimpleErc20Votes } from "@mocks/SimpleErc20Votes.sol";
import { Erc20Taxed } from "@mocks/Erc20Taxed.sol";
import { SimpleErc20Votes } from "@mocks/SimpleErc20Votes.sol";
import { SimpleErc1155 } from "@mocks/SimpleErc1155.sol";
import { ReturnDataMock } from "@mocks/ReturnDataMock.sol";
import { AllowedTokens } from "@src/helpers/AllowedTokens.sol";
import { PowersFactory } from "@src/helpers/PowersFactory.sol";
import { Soulbound1155 } from "@src/helpers/Soulbound1155.sol";
import { ElectionList } from "@src/helpers/ElectionList.sol";

abstract contract TestVariables is PowersErrors, PowersTypes, PowersEvents {
    // protocol and mocks
    Powers powers;
    Configurations helperConfig;
    PowersMock daoMock;
    PowersMock daoMockChild1;
    PowersMock daoMockChild2;
    ElectionListsDAO openElections;
    InitialisePowers initialisePowers;
    string[] mandateNames;
    address[] mandateAddresses;
    TestConstitutions testConstitutions;
    Configurations.NetworkConfig config;
    PowersTypes.Conditions conditions;
    address powersAddress;
    address[] mandates;

    FlagActions flagActions;
    SimpleErc20Votes simpleErc20Votes;
    Erc20Taxed erc20Taxed;
    SimpleErc1155 simpleErc1155;
    ReturnDataMock returnDataMock;
    Nominees nominees;
    ElectionList openElection;
    Erc20DelegateElection erc20DelegateElection;
    SimpleGovernor simpleGovernor;
    AllowedTokens allowedTokens;
    PowersFactory powersFactory;
    Soulbound1155 soulbound1155;
    ElectionList electionList;

    uint256 sepoliaFork;
    uint256 optSepoliaFork;
    uint256 arbSepoliaFork;

    // vote options
    uint8 constant AGAINST = 0;
    uint8 constant FOR = 1;
    uint8 constant ABSTAIN = 2;

    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    bytes callData;
    bytes data;
    uint256 length;
    bytes stateChange;
    bytes mandateCalldata;
    bytes mandateCalldataNominate;
    bytes mandateCalldataElect;
    string nameDescription;
    string description;
    bytes inputParams;
    uint256 nonce;
    address helper;
    address safeTreasury;
    bytes localConfig;

    bool active;
    bool supportsInterface;
    uint256 actionId;
    uint256 expectedActionId;
    uint16 mandateId;
    uint256 actionId1;
    uint256 actionId2;
    uint256 actionId3;
    bytes32 mandateHash;
    address newMandate;
    uint16 mandateCounter;
    address tokenAddress;
    uint256 mintAmount;
    uint256 nftToMint;
    uint256 tokenId;
    address testToken;
    address testToken2;
    bytes32 firstGrantCalldata;
    bytes32 secondGrantCalldata;
    uint16 firstGrantId;
    uint16 secondGrantId;
    uint256 balanceBefore;
    uint256 balanceAfter;
    uint16 roleId;
    address account;
    uint16[] mandateIds;
    address[] accounts;
    address requester;
    address executor;
    string longLabel;
    string longString;
    string retrievedName;
    bytes retrievedConfig;
    bytes retrievedParams;

    address nominee1;
    address nominee2;
    address newMember;
    uint256 membersBefore;
    uint256 membersAfter;
    uint256 amountRoleHolders;
    address recipient;
    address sender;

    address[] nomineesAddresses;
    uint256 roleCount;
    uint256 againstVote;
    uint256 forVote;
    uint256 abstainVote;

    address mandateAddress;
    uint8 quorum;
    uint8 succeedAt;
    uint32 votingPeriod;
    address needFulfilled;
    address needNotFulfilled;
    uint48 timelock;
    uint48 throttleExecution;
    bool quorumReached;
    bool voteSucceeded;
    bytes configBytes;
    bytes inputParamsBytes;
    address blacklistedAccount;

    // roles
    uint256 constant ADMIN_ROLE = 0;
    uint256 constant PUBLIC_ROLE = type(uint256).max;
    uint256 constant ROLE_ONE = 1;
    uint256 constant ROLE_TWO = 2;
    uint256 constant ROLE_THREE = 3;
    uint256 constant ROLE_FOUR = 4;

    // users
    address alice;
    address bob;
    address charlotte;
    address david;
    address eve;
    address frank;
    address gary;
    address helen;
    address ian;
    address jacob;
    address kate;
    address lisa;
    address oracle;
    address[] users;

    // list of dao names
    string[] daoNames;

    // loop variables.
    uint256 i;
    uint256 j;

    uint256 taxPaid;
    mapping(address => uint256) taxLogs;
    mapping(address => uint256) votesReceived;
    mapping(address => bool) hasVoted;

    // Common test variables to reduce stack usage
    // uint256[] milestoneDisbursements;
    uint256[] milestoneDisbursements;
    uint256[] milestoneDisbursements2;
    uint256[] milestoneBlocks;
    uint256[] milestoneBlocks2;
    uint256[] milestoneAmounts;
    uint256[] milestoneAmounts2;
    address[] tokens;
    address[] targetsIn;
    uint256[] valuesIn;
    bytes[] calldatasIn;
    address[] targets1;
    uint256[] values1;
    bytes[] calldatas1;
    address[] targets2;
    uint256[] values2;
    bytes[] calldatas2;
    string uri;
    string uri2;
    string uriProposal;
    string uriProposal1;
    string uriProposal2;
    string supportUri;
    uint256[] actionIds;
    string[] testStrings;

    // Fuzz test variables
    uint256 MAX_FUZZ_TARGETS;
    uint256 MAX_FUZZ_CALLDATA_LENGTH;
    bytes CREATE2_FACTORY_BYTECODE;
}

abstract contract TestHelperFunctions is Test, TestVariables {
    function test() public { }

    function hashProposal(address targetMandate, bytes memory mandateCalldataLocal, uint256 nonceLocal)
        public
        pure
        virtual
        returns (uint256)
    {
        return uint256(keccak256(abi.encode(targetMandate, mandateCalldataLocal, nonceLocal)));
    }

    function hashMandate(address targetMandate, uint16 mandateId) public pure virtual returns (bytes32) {
        return keccak256(abi.encode(targetMandate, mandateId));
    }

    function distributeERC20VoteTokens(address[] memory accountsWithVotes, uint256 randomiser, address simpleErc20Votes)
        public
    {
        uint256 currentRandomiser;
        for (i = 0; i < accountsWithVotes.length; i++) {
            if (currentRandomiser < 10) {
                currentRandomiser = randomiser;
            } else {
                currentRandomiser = currentRandomiser / 10;
            }
            uint256 amount = (currentRandomiser % 10_000) + 1;
            vm.startPrank(accountsWithVotes[i]);
            SimpleErc20Votes(simpleErc20Votes).mint(amount);
            SimpleErc20Votes(simpleErc20Votes).delegate(accountsWithVotes[i]); // delegate votes to themselves
            vm.stopPrank();
        }
    }

    // function distributeNfts(
    //     address powersContract,
    //     address erc721MockLocal,
    //     address[] memory accounts,
    //     uint256 randomiser,
    //     uint256 density
    // ) public {
    //     uint256 currentRandomiser;
    //     randomiser = bound(randomiser, 10, 100 * 10 ** 18);
    //     for (i = 0; i < accounts.length; i++) {
    //         if (currentRandomiser < 10) {
    //             currentRandomiser = randomiser;
    //         } else {
    //             currentRandomiser = currentRandomiser / 10;
    //         }
    //         bool getNft = (currentRandomiser % 100) < density;
    //         if (getNft) {
    //             vm.prank(powersContract);
    //             SoulboundErc721(erc721MockLocal).mintNft(randomiser + i, accounts[i]);
    //         }
    //     }
    // }

    function voteOnProposal(
        address payable dao,
        uint16 mandateToVoteOn,
        uint256 actionIdLocal,
        address[] memory voters,
        uint256 randomiser,
        uint256 passChance // in percentage
    )
        public
        returns (uint256 roleCountLocal, uint256 againstVoteLocal, uint256 forVoteLocal, uint256 abstainVoteLocal)
    {
        uint256 currentRandomiser;
        for (i = 0; i < voters.length; i++) {
            // set randomiser..
            if (currentRandomiser < 10) {
                currentRandomiser = randomiser;
            } else {
                currentRandomiser = currentRandomiser / 10;
            }
            // vote
            if (Powers(dao).canCallMandate(voters[i], mandateToVoteOn)) {
                roleCountLocal++;
                if (currentRandomiser % 100 >= passChance) {
                    vm.prank(voters[i]);
                    Powers(dao).castVote(actionIdLocal, 0); // = against
                    againstVoteLocal++;
                } else if (currentRandomiser % 100 < passChance) {
                    vm.prank(voters[i]);
                    Powers(dao).castVote(actionIdLocal, 1); // = for
                    forVoteLocal++;
                } else {
                    vm.prank(voters[i]);
                    Powers(dao).castVote(actionIdLocal, 2); // = abstain
                    abstainVoteLocal++;
                }
            }
        }
    }

    function findMandateAddress(string memory name) internal view returns (address) {
        for (uint256 i = 0; i < mandateNames.length; i++) {
            if (Strings.equal(mandateNames[i], name)) {
                return mandateAddresses[i];
            }
        }
        return address(0);
    }

    function findMandateIdInOrg(string memory description, Powers org) public view returns (uint16) {
        uint16 counter = org.mandateCounter();
        for (uint16 i = 1; i < counter; i++) {
            (address mandateAddress, , ) = org.getAdoptedMandate(i);
            string memory mandateDesc = Mandate(mandateAddress).getNameDescription(address(org), i);
            if (Strings.equal(mandateDesc, description)) {
                return i;
            }
        }
        revert("Mandate not found");
    }
}

abstract contract BaseSetup is TestVariables, TestHelperFunctions {
    function setUp() public virtual {
        vm.roll(block.number + 10);

        // forks
        sepoliaFork = vm.createFork(vm.envString("SEPOLIA_RPC_URL"));
        optSepoliaFork = vm.createFork(vm.envString("OPT_SEPOLIA_RPC_URL"));
        arbSepoliaFork = vm.createFork(vm.envString("ARB_SEPOLIA_RPC_URL"));

        setUpVariables();
        // run mandates deploy script here.
    }

    function setUpVariables() public virtual {
        nonce = 123;
        MAX_FUZZ_TARGETS = 5;
        MAX_FUZZ_CALLDATA_LENGTH = 2000;

        // users
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlotte = makeAddr("charlotte");
        david = makeAddr("david");
        eve = makeAddr("eve");
        frank = makeAddr("frank");
        gary = makeAddr("gary");
        helen = makeAddr("helen");
        ian = makeAddr("ian");
        jacob = makeAddr("jacob");
        kate = makeAddr("kate");
        lisa = makeAddr("lisa");
        oracle = makeAddr("oracle");

        // assign funds
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(charlotte, 10 ether);
        vm.deal(david, 10 ether);
        vm.deal(eve, 10 ether);
        vm.deal(frank, 10 ether);
        vm.deal(gary, 10 ether);
        vm.deal(helen, 10 ether);
        vm.deal(ian, 10 ether);
        vm.deal(jacob, 10 ether);
        vm.deal(kate, 10 ether);
        vm.deal(lisa, 10 ether);
        vm.deal(oracle, 10 ether);

        users = [alice, bob, charlotte, david, eve, frank, gary, helen, ian, jacob, kate, lisa];

        // deploy mock powers
        daoMock = new PowersMock();
        daoMockChild1 = new PowersMock();
        daoMockChild2 = new PowersMock();

        // deploy external contracts
        initialisePowers = new InitialisePowers();
        (mandateNames, mandateAddresses) = initialisePowers.getDeployed();
        Configurations helperConfig = new Configurations();
        config = helperConfig.getConfig();

        // deploy constitutions mock
        vm.startPrank(address(daoMock));
        testConstitutions = new TestConstitutions(mandateNames, mandateAddresses);
        vm.stopPrank();
    }
}

/////////////////////////////////////////////////////////////////////
//                      TEST SETUPS PROTOCOL                       //
/////////////////////////////////////////////////////////////////////

abstract contract TestSetupPowers is BaseSetup {
    function setUpVariables() public override {
        super.setUpVariables();

        // initiate constitution
        (PowersTypes.MandateInitData[] memory mandateInitData_) =
            testConstitutions.powersTestConstitution(address(daoMock));

        console2.log("Mandate Init Data Length:");
        console2.logUint(mandateInitData_.length);

        // constitute daoMock.
        daoMock.constitute(mandateInitData_);
        daoMock.closeConstitute();

        vm.startPrank(address(daoMock));
        daoMock.assignRole(ADMIN_ROLE, alice);
        daoMock.assignRole(ROLE_ONE, alice);
        daoMock.assignRole(ROLE_ONE, bob);
        daoMock.assignRole(ROLE_TWO, charlotte);
        daoMock.assignRole(ROLE_TWO, david);
        vm.stopPrank();
    }
}

abstract contract TestSetupMandate is BaseSetup {
    function setUpVariables() public override {
        super.setUpVariables();

        vm.prank(address(daoMock));
        simpleErc1155 = new SimpleErc1155();

        // initiate constitution
        (PowersTypes.MandateInitData[] memory mandateInitData_) =
            testConstitutions.mandateTestConstitution(address(daoMock), address(simpleErc1155));

        // constitute daoMock.
        daoMock.constitute(mandateInitData_);
        daoMock.closeConstitute();

        vm.startPrank(address(daoMock));
        daoMock.assignRole(ROLE_ONE, alice);
        daoMock.assignRole(ROLE_ONE, bob);
        daoMock.assignRole(ROLE_TWO, charlotte);
        daoMock.assignRole(ROLE_TWO, david);
        vm.stopPrank();
    }
}

//////////////////////////////////////////////////////////////////////
//                      UNIT TESTS MANDATES                         //
//////////////////////////////////////////////////////////////////////

abstract contract TestSetupAsync is BaseSetup {
    function setUpVariables() public override {
        super.setUpVariables();

        // initiate multi constitution
        (PowersTypes.MandateInitData[] memory mandateInitData_) = testConstitutions.asyncTestConstitution();

        // constitute daoMock.
        daoMock.constitute(mandateInitData_);
        daoMock.closeConstitute();

        vm.startPrank(address(daoMock));
        daoMock.assignRole(ROLE_ONE, alice);
        daoMock.assignRole(ROLE_ONE, bob);
        daoMock.assignRole(ROLE_TWO, charlotte);
        daoMock.assignRole(ROLE_TWO, david);
        vm.stopPrank();
    }
}

abstract contract TestSetupElectoral is BaseSetup {
    function setUpVariables() public override {
        super.setUpVariables();

        vm.startPrank(address(daoMock));
        nominees = new Nominees();
        openElection = new ElectionList();
        erc20Taxed = new Erc20Taxed();
        erc20DelegateElection = new Erc20DelegateElection(address(erc20Taxed));
        flagActions = new FlagActions();
        vm.stopPrank();

        // initiate electoral constitution
        (PowersTypes.MandateInitData[] memory mandateInitData_) = testConstitutions.electoralTestConstitution(
            address(daoMock),
            address(nominees),
            address(openElection),
            address(erc20DelegateElection),
            address(erc20Taxed),
            address(flagActions)
        );

        // constitute daoMock.
        daoMock.constitute(mandateInitData_);
        daoMock.closeConstitute();

        vm.startPrank(address(daoMock));
        daoMock.assignRole(ROLE_ONE, alice);
        daoMock.assignRole(ROLE_ONE, bob);
        daoMock.assignRole(ROLE_TWO, charlotte);
        daoMock.assignRole(ROLE_TWO, david);
        vm.stopPrank();
    }
}

abstract contract TestSetupExecutive is BaseSetup {
    function setUpVariables() public override {
        super.setUpVariables();

        vm.startPrank(address(daoMock));
        simpleErc1155 = new SimpleErc1155();
        returnDataMock = new ReturnDataMock();
        vm.stopPrank();

        // initiate executive constitution
        (PowersTypes.MandateInitData[] memory mandateInitData_) = testConstitutions.executiveTestConstitution(
            address(daoMock), address(simpleErc1155), address(returnDataMock)
        );

        // constitute daoMock.
        daoMock.constitute(mandateInitData_);
        daoMock.closeConstitute();

        vm.startPrank(address(daoMock));
        daoMock.assignRole(ROLE_ONE, alice);
        daoMock.assignRole(ROLE_ONE, bob);
        daoMock.assignRole(ROLE_TWO, charlotte);
        daoMock.assignRole(ROLE_TWO, david);
        vm.stopPrank();
    }
}

abstract contract TestSetupIntegrations is BaseSetup {
    function setUpVariables() public override { 
        // vm.skip(true);
        vm.selectFork(optSepoliaFork); // options: sepoliaFork, optSepoliaFork, arbSepoliaFork

        super.setUpVariables();

        vm.startPrank(address(daoMock));
        simpleErc20Votes = new SimpleErc20Votes();
        simpleGovernor = new SimpleGovernor(address(simpleErc20Votes));
        allowedTokens = new AllowedTokens();
        soulbound1155 = new Soulbound1155("this is a test uri");
        electionList = new ElectionList();
        powersFactory = new PowersFactory(
            "Powers Factory", // name
            "https://testURI", // uri
            config.maxCallDataLength,
            config.maxReturnDataLength,
            config.maxExecutionsLength
        );
        powersFactory.addMandates(testConstitutions.powersTestConstitution(address(daoMock)));
        erc20Taxed = new Erc20Taxed();
        vm.stopPrank();

        // initiate multi constitution
        (PowersTypes.MandateInitData[] memory mandateInitData_) = testConstitutions.integrationsTestConstitution(
            address(daoMock),
            address(simpleGovernor),
            address(powersFactory),
            address(soulbound1155),
            address(electionList),
            address(erc20Taxed)
        );
        // (PowersTypes.MandateInitData[] memory mandateInitData2_) =
        //     testConstitutions.integrationsTestConstitution2(address(daoMock), address(allowedTokens));

        // constitute daoMock.
        daoMock.constitute(mandateInitData_);
        // daoMockChild1.constitute(mandateInitData2_);
        daoMock.closeConstitute();

        vm.startPrank(address(daoMock));
        daoMock.assignRole(ROLE_ONE, alice);
        daoMock.assignRole(ROLE_ONE, bob);
        daoMock.assignRole(ROLE_TWO, charlotte);
        daoMock.assignRole(ROLE_TWO, david);
        daoMock.assignRole(42, alice);
        vm.stopPrank();

        vm.startPrank(address(daoMockChild1));
        daoMockChild1.assignRole(ROLE_ONE, alice);
        daoMockChild1.assignRole(ROLE_ONE, bob);
        daoMockChild1.assignRole(ROLE_TWO, charlotte);
        daoMockChild1.assignRole(ROLE_TWO, david);
        daoMockChild1.assignRole(42, alice);
        vm.stopPrank();
    }
}

/////////////////////////////////////////////////////////////////////
//                INTEGRATION FLOWS TEST SETUPS                    //
/////////////////////////////////////////////////////////////////////
/// ELECTORAL FLOWS ///
abstract contract TestSetupDelegateTokenFlow is BaseSetup {
    function setUpVariables() public override {
        super.setUpVariables();

        vm.startPrank(address(daoMock));
        nominees = new Nominees();
        openElection = new ElectionList();
        simpleErc20Votes = new SimpleErc20Votes();
        vm.stopPrank();

        // initiate multi constitution
        (PowersTypes.MandateInitData[] memory mandateInitData_) = testConstitutions.delegateToken_IntegrationTestConstitution(
            address(nominees), address(openElection), address(simpleErc20Votes)
        );

        // constitute daoMock.
        daoMock.constitute(mandateInitData_);
        daoMock.closeConstitute();

        vm.startPrank(address(daoMock));
        daoMock.assignRole(ROLE_ONE, alice);
        daoMock.assignRole(ROLE_ONE, bob);
        daoMock.assignRole(ROLE_TWO, charlotte);
        daoMock.assignRole(ROLE_TWO, david);
        vm.stopPrank();
    }
}

abstract contract TestSetupElectionListFlow is BaseSetup {
    function setUpVariables() public override {
        super.setUpVariables();

        vm.prank(address(daoMock));
        openElection = new ElectionList();

        // initiate multi constitution
        (PowersTypes.MandateInitData[] memory mandateInitData_) =
            testConstitutions.openElection_IntegrationTestConstitution(address(openElection));

        // constitute daoMock.
        daoMock.constitute(mandateInitData_);
        daoMock.closeConstitute();

        vm.startPrank(address(daoMock));
        daoMock.assignRole(ROLE_ONE, alice);
        daoMock.assignRole(ROLE_ONE, bob);
        daoMock.assignRole(ROLE_ONE, frank);
        daoMock.assignRole(ROLE_ONE, gary);
        daoMock.assignRole(ROLE_ONE, helen);
        daoMock.assignRole(ROLE_TWO, charlotte);
        daoMock.assignRole(ROLE_TWO, david);
        vm.stopPrank();
    }
}

abstract contract TestSetupRoleByTransactionFlow is BaseSetup {
    function setUpVariables() public override {
        super.setUpVariables();

        // initiate multi constitution
        (PowersTypes.MandateInitData[] memory mandateInitData_) =
            testConstitutions.roleByTransaction_IntegrationTestConstitution(address(daoMock));

        // constitute daoMock.
        daoMock.constitute(mandateInitData_);
        daoMock.closeConstitute();

        vm.startPrank(address(daoMock));
        daoMock.assignRole(ROLE_ONE, alice);
        daoMock.assignRole(ROLE_ONE, bob);
        daoMock.assignRole(ROLE_TWO, charlotte);
        daoMock.assignRole(ROLE_TWO, david);
        vm.stopPrank();
    }
}

abstract contract TestSetupAssignExternalRoleParentFlow is BaseSetup {
    function setUpVariables() public override {
        super.setUpVariables();

        // initiate multi constitution
        (PowersTypes.MandateInitData[] memory mandateInitData_) =
            testConstitutions.assignExternalRole_parent_IntegrationTestConstitution(address(daoMock));
        (PowersTypes.MandateInitData[] memory mandateInitData1_) = testConstitutions.assignExternalRole_child_IntegrationTestConstitution(
            address(daoMockChild1), address(daoMock)
        );

        // constitute daoMock.
        daoMock.constitute(mandateInitData_);
        daoMock.closeConstitute();
        daoMockChild1.constitute(mandateInitData1_);
        daoMockChild1.closeConstitute();

        vm.startPrank(address(daoMock));
        daoMock.assignRole(ROLE_ONE, alice);
        daoMock.assignRole(ROLE_ONE, bob);
        daoMock.assignRole(ROLE_TWO, charlotte);
        daoMock.assignRole(ROLE_TWO, david);
        vm.stopPrank();

        // role designations in child dao?
    }
}

/// EXECUTIVE FLOWS ///
abstract contract TestSetupOpenActionFlow is BaseSetup {
    function setUpVariables() public override {
        super.setUpVariables();

        // initiate multi constitution
        (PowersTypes.MandateInitData[] memory mandateInitData_) =
            testConstitutions.openAction_IntegrationTestConstitution();

        // constitute daoMock.
        daoMock.constitute(mandateInitData_);
        daoMock.closeConstitute();

        vm.startPrank(address(daoMock));
        daoMock.assignRole(ROLE_ONE, alice);
        daoMock.assignRole(ROLE_ONE, bob);
        daoMock.assignRole(ROLE_TWO, charlotte);
        daoMock.assignRole(ROLE_TWO, david);
        vm.stopPrank();
    }
}

abstract contract TestSetupCheckExternalActionStateFlow is BaseSetup {
    function setUpVariables() public override {
        super.setUpVariables();

        // initiate multi constitution
        (PowersTypes.MandateInitData[] memory mandateInitData_) =
            testConstitutions.checkExternalActionState_Parent_IntegrationTestConstitution(address(daoMock));
        (PowersTypes.MandateInitData[] memory mandateInitData1_) = testConstitutions.checkExternalActionState_Child_IntegrationTestConstitution(
            address(daoMockChild1), address(daoMock)
        );

        // constitute daoMock.
        daoMock.constitute(mandateInitData_);
        daoMock.closeConstitute();
        daoMockChild1.constitute(mandateInitData1_);
        daoMockChild1.closeConstitute();

        vm.startPrank(address(daoMock));
        daoMock.assignRole(ROLE_ONE, alice);
        daoMock.assignRole(ROLE_ONE, bob);
        daoMock.assignRole(ROLE_TWO, charlotte);
        daoMock.assignRole(ROLE_TWO, david);
        vm.stopPrank();

        // role designations in child dao?
    }
}

/// INTEGRATIONS FLOWS ///
abstract contract TestSetupGovernorProtocolFlow is BaseSetup {
    function setUpVariables() public override {
        super.setUpVariables();

        vm.startPrank(address(daoMock));
        simpleErc20Votes = new SimpleErc20Votes();
        simpleGovernor = new SimpleGovernor(address(simpleErc20Votes));
        vm.stopPrank();

        // initiate multi constitution
        (PowersTypes.MandateInitData[] memory mandateInitData_) =
            testConstitutions.governorProtocol_IntegrationTestConstitution(address(simpleGovernor));

        // constitute daoMock.
        daoMock.constitute(mandateInitData_);
        daoMock.closeConstitute();

        vm.startPrank(address(daoMock));
        daoMock.assignRole(ROLE_ONE, alice);
        daoMock.assignRole(ROLE_ONE, bob);
        daoMock.assignRole(ROLE_TWO, charlotte);
        daoMock.assignRole(ROLE_TWO, david);
        vm.stopPrank();
    }
}

// £todo: this setup needs fixing.
abstract contract TestSetupSafeProtocolFlow is BaseSetup {
    function setUpVariables() public override {
        vm.skip(false);
        vm.selectFork(arbSepoliaFork); // options: sepoliaFork, optSepoliaFork, arbSepoliaFork
        super.setUpVariables();

        // initiate multi constitution
        (PowersTypes.MandateInitData[] memory mandateInitData_) =
            testConstitutions.safeProtocol_Parent_IntegrationTestConstitution(config.safeAllowanceModule);

        // constitute daoMock.
        daoMock.constitute(mandateInitData_);
        daoMock.closeConstitute();

        vm.startPrank(address(daoMock));
        daoMock.assignRole(ROLE_ONE, alice);
        daoMock.assignRole(ROLE_ONE, bob);
        daoMock.assignRole(ROLE_TWO, charlotte);
        daoMock.assignRole(ROLE_TWO, david);
        vm.stopPrank();

        // role designations in child dao?
        vm.startPrank(address(daoMockChild1));
        daoMockChild1.assignRole(ROLE_ONE, alice);
        daoMockChild1.assignRole(ROLE_ONE, bob);
        daoMockChild1.assignRole(ROLE_TWO, charlotte);
        daoMockChild1.assignRole(ROLE_TWO, david);
        vm.stopPrank();
    }
}

/////////////////////////////////////////////////////////////////////
//            INTEGRATION ORGANISATION TEST SETUPS                 //
/////////////////////////////////////////////////////////////////////
// Powers 101 Setup
abstract contract TestSetupPowers101 is BaseSetup {
    function setUpVariables() public override {
        // Note: this test runs the full initalisation scripts. It takes a while to run.
        // But it is needed to be able to test the full deployment flow of an organisation.
        vm.skip(true);

        super.setUpVariables();

        Powers101 powers101 = new Powers101();
        daoMock = PowersMock(payable(address(powers101.run())));

        vm.startPrank(address(daoMock));
        daoMock.assignRole(ROLE_ONE, alice);
        daoMock.assignRole(ROLE_ONE, bob);
        daoMock.assignRole(ROLE_TWO, charlotte);
        daoMock.assignRole(ROLE_TWO, david);
        vm.stopPrank();
    }
}

// Open Elections Setup
abstract contract TestSetupElectionListsDAO is BaseSetup {
    function setUpVariables() public override {
        // Note: this test runs the full initalisation scripts. It takes a while to run.
        // But it is needed to be able to test the full deployment flow of an organisation.
        vm.skip(false);

        super.setUpVariables();

        ElectionListsDAO openElections = new ElectionListsDAO();
        (powers, openElection) = openElections.run();
        daoMock = PowersMock(payable(address(powers)));

        vm.startPrank(address(daoMock));
        daoMock.assignRole(ROLE_ONE, alice);
        daoMock.assignRole(ROLE_ONE, bob);
        daoMock.assignRole(ROLE_ONE, frank);
        daoMock.assignRole(ROLE_ONE, gary);
        daoMock.assignRole(ROLE_ONE, helen);
        daoMock.assignRole(ROLE_TWO, charlotte);
        daoMock.assignRole(ROLE_TWO, david);
        vm.stopPrank();
    }
}

// Cultural Stewards DAO Setup
abstract contract TestSetupCulturalStewardsDAO is BaseSetup {
    function setUpVariables() public override {
        // Note: this test runs the full initalisation scripts. It takes a while to run.
        // But it is needed to be able to test the full deployment flow of an organisation.
        vm.skip(false);
        vm.selectFork(sepoliaFork);

        super.setUpVariables();

        ElectionListsDAO openElections = new ElectionListsDAO();
        (powers, openElection) = openElections.run();
        daoMock = PowersMock(payable(address(powers)));

        vm.startPrank(address(daoMock));
        daoMock.assignRole(ROLE_ONE, alice);
        daoMock.assignRole(ROLE_ONE, bob);
        daoMock.assignRole(ROLE_ONE, frank);
        daoMock.assignRole(ROLE_ONE, gary);
        daoMock.assignRole(ROLE_ONE, helen);
        daoMock.assignRole(ROLE_TWO, charlotte);
        daoMock.assignRole(ROLE_TWO, david);
        vm.stopPrank();
    }
}

/////////////////////////////////////////////////////////////////////
//                      HELPER TEST SETUPS                         //
/////////////////////////////////////////////////////////////////////
abstract contract TestSetupHelpers is BaseSetup {
    function setUpVariables() public override {
        super.setUpVariables();

        // initiate helpers constitution
        (PowersTypes.MandateInitData[] memory mandateInitData_) = testConstitutions.helpersTestConstitution();

        // constitute daoMock.
        daoMock.constitute(mandateInitData_);

        vm.startPrank(address(daoMock));
        daoMock.assignRole(ADMIN_ROLE, alice);
        vm.stopPrank();
    }
}
