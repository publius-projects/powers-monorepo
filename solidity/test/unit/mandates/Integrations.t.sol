// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { console2 } from "forge-std/console2.sol";
import { TestSetupIntegrations, TestSetupExecutive } from "../../TestSetup.t.sol";
import { PowersMock } from "@mocks/PowersMock.sol";
import { Governor_CreateProposal } from "@src/mandates/integrations/Governor_CreateProposal.sol";
import { Governor_ExecuteProposal } from "@src/mandates/integrations/Governor_ExecuteProposal.sol";

import { SafeAllowance_Transfer } from "@src/mandates/integrations/SafeAllowance_Transfer.sol";
import { Safe_ExecTransaction } from "@src/mandates/integrations/Safe_ExecTransaction.sol"; 
import { Soulbound1155_GatedAccess } from "@src/mandates/integrations/Soulbound1155_GatedAccess.sol";
import { Mandate } from "@src/Mandate.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";

import { SimpleGovernor } from "@mocks/SimpleGovernor.sol";
import { SimpleErc20Votes } from "@mocks/SimpleErc20Votes.sol";
import { PresetActions_Single } from "@src/mandates/executive/PresetActions_Single.sol";
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { MandateUtilities } from "@src/libraries/MandateUtilities.sol";
import { Governor } from "@openzeppelin/contracts/governance/Governor.sol";
import { ElectionList } from "@src/helpers/ElectionList.sol";

/// @notice Comprehensive unit tests for all executive mandates
/// @dev Tests all functionality of executive mandates including initialization, execution, and edge cases

//////////////////////////////////////////////////
//          GOVERNOR INTEGRATION TESTS          //
//////////////////////////////////////////////////
contract GovernorIntegrationTest is TestSetupIntegrations {
    Governor_CreateProposal public createProposalMandate;
    Governor_ExecuteProposal public executeProposalMandate;

    uint16 public createProposalId;
    uint16 public executeProposalId;

    function setUp() public override {
        super.setUp();

        // 1. Identify Mandate IDs from TestSetupIntegrations -> integrationsTestConstitution
        createProposalId = findMandateIdInOrg(
            "Governor_CreateProposal: A mandate to create governance proposals on a Governor contract.", daoMock
        );
        executeProposalId = findMandateIdInOrg(
            "Governor_ExecuteProposal: A mandate to execute governance proposals on a Governor contract.", daoMock
        );

        // 2. Get Mandate Instances
        createProposalMandate = Governor_CreateProposal(findMandateAddress("Governor_CreateProposal"));
        executeProposalMandate = Governor_ExecuteProposal(findMandateAddress("Governor_ExecuteProposal"));

        // 3. Setup Alice with votes for the Governor
        simpleErc20Votes.mint(10e18);
        simpleErc20Votes.transfer(alice, 10e18);
        vm.prank(alice);
        simpleErc20Votes.delegate(alice);
    }

    function test_Governor_CreateProposal_Success() public {
        // Setup proposal parameters
        address[] memory targets = new address[](1);
        targets[0] = address(simpleErc20Votes);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("transfer(address,uint256)", bob, 1e18);
        string memory description = "Test Proposal";

        // mint tokens to daoMock to have tokens to transfer.
        simpleErc20Votes.mint(address(daoMock), 5e18);

        // Encode mandate calldata
        bytes memory mandateCalldata = abi.encode(targets, values, calldatas, description);

        // Execute via DAO
        vm.prank(alice);
        daoMock.request(createProposalId, mandateCalldata, 0, "Create Proposal Request");

        // Verify proposal exists on Governor
        uint256 proposalId = simpleGovernor.hashProposal(targets, values, calldatas, keccak256(bytes(description)));
        assertGt(simpleGovernor.proposalSnapshot(proposalId), 0);
    }

    function test_Governor_CreateProposal_Revert_NotConfigured() public {
        // Create a fresh mandate that is NOT configured
        Governor_CreateProposal unconfiguredMandate = new Governor_CreateProposal();
        // Don't initialize it, or initialize with 0 address

        uint16 unconfiguredId = 999;
        bytes memory mandateCalldata = abi.encode(new address[](0), new uint256[](0), new bytes[](0), "");

        vm.expectRevert();
        unconfiguredMandate.handleRequest(alice, address(daoMock), unconfiguredId, mandateCalldata, 0);
    }

    function test_Governor_CreateProposal_Revert_InvalidParams() public {
        // Empty targets
        address[] memory targets = new address[](0);
        uint256[] memory values = new uint256[](0);
        bytes[] memory calldatas = new bytes[](0);
        string memory description = "Test";

        bytes memory mandateCalldata = abi.encode(targets, values, calldatas, description);

        vm.prank(alice);
        vm.expectRevert("Governor_CreateProposal: No targets provided");
        daoMock.request(createProposalId, mandateCalldata, 0, "Invalid Params");

        // Mismatch length
        targets = new address[](1);
        targets[0] = address(0);

        mandateCalldata = abi.encode(targets, values, calldatas, description);

        vm.prank(alice);
        vm.expectRevert("Governor_CreateProposal: Targets and values length mismatch");
        daoMock.request(createProposalId, mandateCalldata, 0, "Mismatch Params");
    }

    function test_Governor_ExecuteProposal_Success() public {
        // 1. Setup and Create Proposal
        address[] memory targets = new address[](1);
        targets[0] = address(simpleErc20Votes);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("transfer(address,uint256)", bob, 1e18);
        string memory description = "Test Proposal Execution";

        // Create proposal directly on Governor
        vm.startPrank(alice);
        simpleErc20Votes.mint(address(daoMock), 100e18); // AI READ THIS: DO NOT DELETE. This is needed because the tokens will be transferred from the daoMock contract NOT from alice!
        simpleGovernor.propose(targets, values, calldatas, description);
        vm.stopPrank();

        uint256 proposalId = simpleGovernor.hashProposal(targets, values, calldatas, keccak256(bytes(description)));

        // 2. Advance to voting period
        vm.roll(block.number + simpleGovernor.votingDelay() + 1);

        // 3. Vote
        vm.prank(alice);
        simpleGovernor.castVote(proposalId, 1); // For

        // 4. Advance to end of voting period
        vm.roll(block.number + simpleGovernor.votingPeriod() + 1);

        // 5. Test Execute Mandate
        bytes memory mandateCalldata = abi.encode(targets, values, calldatas, description);

        vm.prank(alice);
        daoMock.request(executeProposalId, mandateCalldata, 0, "Execute Proposal");

        // Verify execution
        assertEq(uint256(simpleGovernor.state(proposalId)), 4); // Succeded state
    }

    function test_Governor_ExecuteProposal_Revert_NotSucceeded() public {
        // 1. Setup and Create Proposal
        address[] memory targets = new address[](1);
        targets[0] = address(simpleErc20Votes);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("transfer(address,uint256)", bob, 1e18);
        string memory description = "Test Proposal Fail";

        vm.prank(alice);
        simpleGovernor.propose(targets, values, calldatas, description);

        // 2. Try to execute immediately (Pending state)
        bytes memory mandateCalldata = abi.encode(targets, values, calldatas, description);

        vm.prank(alice);
        vm.expectRevert("Governor_ExecuteProposal: Proposal not succeeded");
        daoMock.request(executeProposalId, mandateCalldata, 0, "Execute Pending");

        // 3. Vote Against
        uint256 proposalId = simpleGovernor.hashProposal(targets, values, calldatas, keccak256(bytes(description)));
        vm.roll(block.number + simpleGovernor.votingDelay() + 1);

        vm.prank(alice);
        simpleGovernor.castVote(proposalId, 0); // Against

        vm.roll(block.number + simpleGovernor.votingPeriod() + 1);

        // 4. Try to execute (Defeated state)
        vm.prank(alice);
        vm.expectRevert("Governor_ExecuteProposal: Proposal not succeeded");
        daoMock.request(executeProposalId, mandateCalldata, 0, "Execute Defeated");
    }
}

//////////////////////////////////////////////////
//      SAFE ALLOWANCE INTEGRATION TESTS        //
//////////////////////////////////////////////////
contract SafeAllowanceTest is TestSetupIntegrations {
    uint16 public safeAllowanceMandateId_Safe_Setup;
    uint16 public safeAllowanceMandateId_ExecuteActionFromSafe;
    uint16 public safeAllowanceMandateId_SetAllowance;
    uint16 public safeAllowanceTransferId;
    uint16 public safeAssignDelegateId;
    uint256 public actionIdSafeSetup; 

    function setUp() public override {
        super.setUp();

        // skip these tests if allowance module is not set
        if (config.safeAllowanceModule == address(0)) {
            console2.log("Safe Allowance Module not set in config, skipping tests.");
            vm.skip(true);
        }

        // IDs from TestConstitutions
        safeAllowanceMandateId_Safe_Setup =
            findMandateIdInOrg("Setup Safe: Create a SafeProxy and register it as treasury.", daoMock);
        safeAssignDelegateId =
            findMandateIdInOrg("Assign Delegate status: Assign delegate status at Safe treasury to a sub-DAO", daoMock);
        safeAllowanceMandateId_SetAllowance =
            findMandateIdInOrg("Set Allowance: Execute and set allowance for a sub-DAO.", daoMock);
        safeAllowanceMandateId_ExecuteActionFromSafe =
            findMandateIdInOrg("Transfer tokens from the Safe treasury.", daoMock);

        // On daoMockChild1
        safeAllowanceTransferId = 1; // First mandate in constitution2

        vm.prank(alice);
        actionIdSafeSetup = daoMock.request(
            safeAllowanceMandateId_Safe_Setup, abi.encode(), nonce, "Setting up safe with allowance module."
        );

        // safeTreasury = abi.decode(daoMock.getActionReturnData(actionIdSafeSetup, 0), (address)); 
        console2.log("Safe Treasury saved at:",  IPowers(address(daoMock)).getTreasury());
        // vm.prank(address(daoMock));
        // IPowers(address(daoMock)).setTreasury(payable(safeTreasury));

        // Now that the treasury is set, we can constitute the child DAO.
        // This ensures the child DAO is configured with the correct treasury address.
        (PowersTypes.MandateInitData[] memory mandateInitData2_) =
            testConstitutions.integrationsTestConstitution2(address(daoMock), address(allowedTokens));
        daoMockChild1.constitute(mandateInitData2_);
        daoMockChild1.closeConstitute();
    }

    // we will try to add a delegate.
    function test_Safe_ExecTransaction_Success() public { 
        // We are trying to add a delegate (address(0x456)) to the Safe via execTransaction mandate
        address functionTarget = config.safeAllowanceModule;
        bytes4 functionSelector = bytes4(0xe71bdf41); // addDelegate(address)
        bytes memory functionCalldata = abi.encode(address(0x456));

        bytes memory mandateCalldata = abi.encode(
            functionTarget,
            uint256(0), // value
            abi.encodeWithSelector(functionSelector, functionCalldata) // data
        );

        // Execute via DAO
        vm.prank(alice);
        daoMock.request(safeAssignDelegateId, mandateCalldata, nonce, "Safe Exec Transaction");
    }

    function test_SafeAllowance_Transfer_Success() public {
        // 1. Assign Delegate Status to Child DAO
        address functionTarget = config.safeAllowanceModule;
        bytes4 functionSelector = bytes4(0xe71bdf41); // addDelegate(address)

        // Execute via DAO
        vm.prank(alice);
        daoMock.request(safeAssignDelegateId, abi.encode(address(daoMockChild1)), nonce, "Assign Delegate to Child DAO");

        // 2. Set Allowance
        address token = address(simpleErc20Votes);
        uint96 amount = 2e16;
        console2.log("Child DAO:", address(daoMockChild1));

        simpleErc20Votes.mint(daoMock.getTreasury(), 1e18); // Fund the Safe treasury

        // Params: ChildPowers, Token, allowanceAmount, resetTimeMin, resetBaseMin
        bytes memory setAllowanceData = abi.encode(address(daoMockChild1), token, amount, uint16(0), uint32(0));
        vm.prank(alice);
        daoMock.request(safeAllowanceMandateId_SetAllowance, setAllowanceData, 1, "Set Allowance");

        // 3. Execute Transfer on Child
        address payableTo = bob;
        // Params: Token, payableTo, amount
        bytes memory transferData = abi.encode(token, uint96(1e16), payableTo);

        vm.prank(alice);
        daoMockChild1.request(safeAllowanceTransferId, transferData, 0, "Transfer Allowance");
    }
}
 

contract Soulbound1155_GatedAccessTest is TestSetupIntegrations {
    uint16 public mintMandateId;
    uint16 public accessMandateId;
    uint256 public targetRoleId;

    function setUp() public override {
        super.setUp();

        mintMandateId = findMandateIdInOrg(
            "Mint soulbound token: mint a soulbound ERC1155 token and send it to an address of choice.", daoMock
        );
        accessMandateId =
            findMandateIdInOrg("Soulbound1155 Access: Get roleId through soulbound ERC1155 token.", daoMock);
        targetRoleId = 9;
    }

    function test_Soulbound1155_GatedAccess_Success() public {
        vm.startPrank(alice);

        // 1. Mint 4 tokens (Threshold is 3, need > 3 tokens. i.e. 4)
        uint256[] memory tokenIds = new uint256[](4);

        for (uint256 i = 0; i < 4; i++) {
            // Config for mandate 7: params[0] = "address to"
            // So request calldata should be abi.encode(to).
            daoMock.request(mintMandateId, abi.encode(alice), nonce, "Mint Token");

            // Calculate ID that was minted
            // TokenID = (minter << 48) | blockNumber
            // Minter is daoMock (owner of soulbound1155)
            uint256 tokenId = (uint256(uint160(address(alice))) << 48) | uint256(block.number);
            tokenIds[i] = tokenId;

            // Advance block to get unique IDs (and test block threshold)
            // Config block threshold is 100.
            vm.roll(block.number + 1);
            nonce++;
        }

        // 2. Request Access using the minted tokens
        // Check if we are within block threshold.
        // Current block is X. Token mint blocks are X-4, X-3, X-2, X-1.
        // Threshold is 100. So we are well within threshold.
        daoMock.request(accessMandateId, abi.encode(tokenIds), nonce++, "Request Access");
        vm.stopPrank();

        // 3. Verify Role Assigned
        assertTrue(daoMock.hasRoleSince(alice, targetRoleId) > 0);
    }

    function test_Soulbound1155_GatedAccess_Revert_InsufficientTokens() public {
        vm.startPrank(alice); // NB: alice mints the tokens. It is her address that is encoded in their Ids!

        // Mint 3 tokens (Threshold is 3, check is <= threshold, so 3 fails)
        uint256[] memory tokenIds = new uint256[](3);
        for (uint256 i = 0; i < 3; i++) {
            daoMock.request(mintMandateId, abi.encode(alice), nonce, "Mint Token");
            tokenIds[i] = (uint256(uint160(address(daoMock))) << 48) | uint256(block.number);
            vm.roll(block.number + 1);
            nonce++;
        }

        vm.expectRevert("Insuffiicent valid tokens provided");
        daoMock.request(accessMandateId, abi.encode(tokenIds), 0, "Request Access");

        vm.stopPrank();
    }

    function test_Soulbound1155_GatedAccess_Revert_NotOwnerOfToken() public {
        vm.startPrank(alice);

        // Mint 4 tokens
        uint256[] memory tokenIds = new uint256[](4);
        for (uint256 i = 0; i < 4; i++) {
            daoMock.request(mintMandateId, abi.encode(alice), nonce, "Mint Token");
            tokenIds[i] = (uint256(uint160(address(alice))) << 48) | uint256(block.number);
            vm.roll(block.number + 1);
            nonce++;
        }

        // Change one token to random ID (alice doesn't own it)
        tokenIds[0] = 123_456_789;
        tokenIds[1] = 123_456_789;

        vm.expectRevert("Insuffiicent valid tokens provided");
        daoMock.request(accessMandateId, abi.encode(tokenIds), 0, "Request Access");

        vm.stopPrank();
    }

    function test_Soulbound1155_GatedAccess_Revert_TokenExpired() public {
        vm.startPrank(alice);

        uint256[] memory tokenIds = new uint256[](4);
        for (uint256 i = 0; i < 4; i++) {
            daoMock.request(mintMandateId, abi.encode(alice), nonce, "Mint Token");
            tokenIds[i] = (uint256(uint160(address(alice))) << 48) | uint256(block.number);
            vm.roll(block.number + 1);
            nonce++;
        }

        // Advance block beyond threshold
        // Threshold is 100.
        // Last token minted at T. Current block is T+1.
        // We want (block.number - mintBlock) > threshold.
        // mintBlock = T.
        // Need block.number > T + 100.
        // So + 101 blocks.
        vm.roll(block.number + 101);
        vm.expectRevert("Insuffiicent valid tokens provided");
        daoMock.request(accessMandateId, abi.encode(tokenIds), nonce, "Request Access");

        vm.stopPrank();
    }
}

//////////////////////////////////////////////////
//              ELECTIONLIST TESTS              //
//////////////////////////////////////////////////
contract ElectionListIntegrationTest is TestSetupIntegrations {
    uint16 createElectionId;
    uint16 nominateId;
    uint16 revokeId;
    uint16 openVoteId;
    uint16 tallyId;
    uint16 cleanupId;

    address electionListAddress;
    string title = "Test Election";
    uint48 startBlock;
    uint48 endBlock;
    bytes electionParams;
    uint256 electionId;
    uint16 voteMandateId;
    bytes voteParams;
    uint256 creationAcionId;
    bytes returnData;
    bytes mandateConfig;
    address[] nomineesList;
    uint256 openActionId;
    bool[] votes;

    function setUp() public override {
        super.setUp();

        createElectionId =
            findMandateIdInOrg("Create an election: an election can be initiated be any member.", daoMock);
        nominateId = findMandateIdInOrg("Nominate for election: any member can nominate for an election.", daoMock);
        revokeId = findMandateIdInOrg(
            "Revoke nomination for election: any member can revoke their nomination for an election.", daoMock
        );
        openVoteId = findMandateIdInOrg(
            "Open voting for election: Members can open the vote for an election. This will create a dedicated vote mandate.",
            daoMock
        );
        tallyId = findMandateIdInOrg(
            "Tally elections: After an election has finished, assign the Executive role to the winners.", daoMock
        );
        cleanupId = findMandateIdInOrg(
            "Clean up election: After an election has finished, clean up related mandates.", daoMock
        );

        startBlock = uint48(block.number + 10);
        endBlock = uint48(block.number + 100);
        electionParams = abi.encode(title, startBlock, endBlock);

        // Retrieve electionList address from mandate 9 config
        // Mandate 9 is BespokeAction_Simple.
        // Its config is (address target, bytes4 selector, string[] params).
        // target is electionList.
        mandateConfig =
            Mandate(findMandateAddress("BespokeAction_Simple")).getConfig(address(daoMock), createElectionId);
        (electionListAddress,,) = abi.decode(mandateConfig, (address, bytes4, string[]));
    }

    function test_ElectionList_FullFlow_Success() public {
        // 1. Create Election
        // BespokeAction_Simple params: encoded params for the function
        console2.log("Creating Election...");
        vm.prank(alice);
        creationAcionId = daoMock.request(createElectionId, electionParams, nonce, "Create Election");

        console2.log("Getting Election ID...");
        returnData = daoMock.getActionReturnData(creationAcionId, 0);
        electionId = abi.decode(returnData, (uint256));
        assertGt(electionId, 0);

        // 2. Nominate
        // Mandate expects (title, start, end) to compute ID
        console2.log("Nominating Alice...");
        vm.prank(alice);
        daoMock.request(nominateId, electionParams, nonce, "Nominate Alice");

        // Verify Nomination
        nomineesList = ElectionList(electionListAddress).getNominees(electionId);
        assertEq(nomineesList.length, 1);
        assertEq(nomineesList[0], alice);

        vm.roll(startBlock + 1); // Advance to start block

        // 3. Open Vote
        // This deploys a new mandate.
        console2.log("Creating Vote Mandate...");
        vm.prank(alice);
        openActionId = daoMock.request(openVoteId, electionParams, nonce, "Creating Vote Mandate");

        // Get the new mandate ID (it is returned by adoptMandate which is the action executed)
        returnData = daoMock.getActionReturnData(openActionId, 0);
        voteMandateId = abi.decode(returnData, (uint16));
        assertTrue(voteMandateId > 0);

        // 4. Vote
        console2.log("Voting for Alice...");

        // Nominees: [alice]
        vm.prank(alice);
        daoMock.request(voteMandateId, abi.encode(true), nonce, "Vote for Alice");

        assertEq(ElectionList(electionListAddress).getVoteCount(electionId, alice), 1);

        // 5. Tally
        vm.roll(endBlock + 1); // Advance to end block
        console2.log("Tallying Election...");

        // Setup existing role holders (none for role 2 initially maybe?)
        // Config says role 2 is Executive.
        vm.prank(alice);
        daoMock.request(tallyId, electionParams, nonce, "Tally Election");

        // Verify Alice has role 2
        assertTrue(daoMock.hasRoleSince(alice, 2) > 0);
    }
}
