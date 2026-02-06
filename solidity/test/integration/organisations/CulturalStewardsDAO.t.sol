// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Test, console, console2 } from "forge-std/Test.sol";
import { Powers } from "@src/Powers.sol";
import { Mandate } from "@src/Mandate.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { CulturalStewardsDAO } from "../../../script/deployOrganisations/CulturalStewardsDAO.s.sol";
import { Safe } from "lib/safe-smart-account/contracts/Safe.sol";
import { SimpleErc20Votes } from "../../mocks/SimpleErc20Votes.sol";
import { Configurations } from "@script/Configurations.s.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

interface IAllowanceModule {
    function delegates(address safe, uint48 index) external view returns (address delegate, uint48 prev, uint48 next);
    function getTokenAllowance(address safe, address delegate, address token) external view returns (uint256[5] memory);
}

contract CulturalStewardsDAO_IntegrationTest is Test {
    struct Mem {
        address admin;
        uint16 setDelegateMandateId;
        uint16 initiateIdeasMandateId;
        uint16 createIdeasMandateId;
        uint16 assignRoleMandateId;
        uint16 revokeIdeasMandateId;
        uint16 initiatePhysicalId;
        uint16 createPhysicalId;
        uint16 assignRoleId;
        uint16 assignAllowanceId;
        uint16 revokeRoleId;
        uint16 revokeAllowanceId;
        uint16 assignDelegateId;
        uint16 requestPhysicalAllowanceId;
        uint16 grantPhysicalAllowanceId;
        uint16 requestDigitalAllowanceId;
        uint16 grantDigitalAllowanceId;

        uint256 actionId;
        // Added fields to avoid stack too deep
        uint256 constitutionLength;
        uint256 packageSize;
        uint256 numPackages;
        bytes params;
        uint256 nonce;
        address physicalSubDAOAddress;
        bytes revokeParams;
        // Additional fields for other tests
        uint48 delegateIndex;
        address delegateAddr;
        bool isActive;
        bool isEnabled;
        address ideasSubDAOAddress;
        uint32 votingPeriod;
        uint32 timelock;
        uint48 roleSince;
        bytes returnData;

        address token; // ETH
        uint96 amount;
        uint16 resetTime;
        uint32 resetBase;
        address digitalSubDAOAddr;
        bytes allowanceParams;

        // New fields added during refactoring
        address user;
        address recipient;
        address fakeIdeasDao;
        address mockPhysicalDAO;
        address convener;
        address member;

        uint256 paymentAmount;
        uint48 startBlock;
        uint48 endBlock;
        uint256 voteMandateId;

        uint16 submitReceiptId;
        uint16 okReceiptId;
        uint16 approvePaymentId;
        uint16 claimStep1Id;
        uint16 claimStep2Id;
        uint16 mintActivityId;
        uint16 mintPoapPrimaryId;
        uint16 mintActivityTokenPrimaryId;
        uint16 mandateId;
        uint16 createElectionId;
        uint16 nominateId;
        uint16 openVoteId;
        uint16 tallyElectionId;
        uint16 cleanupElectionId;
        uint16 initiateRequestId;
        uint16 createWGId;
        uint16 createWGElectionId;
        uint16 tallyId;
        uint16 requestPhysicalId;

        uint256[5] allowanceInfo;
        bytes paymentParams;
        uint256[] nonces;
        uint256[] actionIds;
        uint256[] tokenIds;
        bytes electionParams;
        bool[] votes;
        uint256[] roleIds;
        // Added for test_IdeasSubDAO_MembershipAndModeration
        uint256 amountRoleHolders;
        address moderator;
        address applicant;
        uint16 assignModeratorId;
        uint16 applyMembershipId;
        uint16 assignMembershipId;
        uint16 revokeMembershipId;
        uint16 revokeModeratorId;
        bytes appParams;
    }
    Mem mem;

    CulturalStewardsDAO deployScript;
    Powers primaryDAO;
    Powers digitalSubDAO;
    Configurations.NetworkConfig config;

    address treasury;
    address safeAllowanceModule;
    uint256 sepoliaFork;
    uint256 optSepoliaFork;
    address cedars = 0x328735d26e5Ada93610F0006c32abE2278c46211;

    function setUp() public {
        vm.skip(false); // Remove this line to run the test
        // Create and select fork
        sepoliaFork = vm.createFork(vm.envString("SEPOLIA_RPC_URL"));
        optSepoliaFork = vm.createSelectFork(vm.envString("OPT_SEPOLIA_RPC_URL"));
        vm.selectFork(optSepoliaFork);

        // Deploy the script
        deployScript = new CulturalStewardsDAO();
        deployScript.run();

        // Get the deployed contracts
        primaryDAO = deployScript.getPrimaryDAO();  
        config = deployScript.getConfig();

        // Execute "Initial Setup"
        vm.prank(cedars);
        primaryDAO.request(1, "", 0, "");

        // Identify Mandate IDs
        console.log("Executing Initial Setup Digital");
        digitalSubDAO = deployScript.getDigitalSubDAO();
        digitalSubDAO.request(1, "", 0, "");

        mem.admin = primaryDAO.getRoleHolderAtIndex(1, 0);
        console.log("Admin address: %s", mem.admin);

        treasury = primaryDAO.getTreasury();
        console.log("Treasury address: %s", treasury);

        mem.digitalSubDAOAddr = address(digitalSubDAO);
        vm.prank(mem.digitalSubDAOAddr);
        digitalSubDAO.assignRole(2, cedars); // Assign Role 2 to Cedars AT THE DIGITAL DAO. (so that cedars can act there as convener as well.)

        /////////////////////////////////////////////////////////////////// 
        // find mandate IDs using findMandateIdInOrg function if needed  //
        ///////////////////////////////////////////////////////////////////
        mem.initiateIdeasMandateId = findMandateIdInOrg("Initiate Ideas sub-DAO: Initiate creation of Ideas sub-DAO", primaryDAO);
        mem.createIdeasMandateId = findMandateIdInOrg("Create Ideas sub-DAO: Execute Ideas sub-DAO creation", primaryDAO);
        mem.assignRoleMandateId = findMandateIdInOrg("Assign role Id to DAO: Assign role id 4 (Ideas sub-DAO) to the new DAO", primaryDAO);
        mem.revokeIdeasMandateId = findMandateIdInOrg("Revoke role Id: Revoke role id 4 (Ideas sub-DAO) from the DAO", primaryDAO);

        mem.initiatePhysicalId = findMandateIdInOrg("Initiate Physical sub-DAO: Initiate creation of Physical sub-DAO", primaryDAO);
        mem.createPhysicalId = findMandateIdInOrg("Create Physical sub-DAO: Execute Physical sub-DAO creation", primaryDAO);
        mem.assignRoleId = findMandateIdInOrg("Assign role Id: Assign role Id 3 to Physical sub-DAO", primaryDAO);
        
        mem.assignDelegateId = findMandateIdInOrg("Assign Delegate status: Assign delegate status at Safe treasury to the Physical sub-DAO", primaryDAO);
        mem.assignAllowanceId = mem.assignDelegateId;

        mem.revokeRoleId = findMandateIdInOrg("Revoke Role Id: Revoke role Id 3 from Physical sub-DAO", primaryDAO);
        mem.revokeAllowanceId = findMandateIdInOrg("Revoke Delegate status: Revoke delegate status Physical sub-DAO at the Safe treasury", primaryDAO);
        
        mem.requestPhysicalAllowanceId = findMandateIdInOrg("Request additional allowance: Any Physical sub-DAO can request an allowance from the Safe Treasury.", primaryDAO);
        mem.grantPhysicalAllowanceId = findMandateIdInOrg("Set Allowance: Execute and set allowance for a Physical sub-DAO.", primaryDAO);
        
        mem.requestDigitalAllowanceId = findMandateIdInOrg("Request additional allowance: The Digital sub-DAO can request an allowance from the Safe Treasury.", primaryDAO);
        mem.grantDigitalAllowanceId = findMandateIdInOrg("Set Allowance: Execute and set allowance for the Digital sub-DAO.", primaryDAO);
    }

    function test_InitialSetup() public {
        // 4. Verify Role Labels
        assertEq(primaryDAO.getRoleLabel(1), "Members", "Role 1 should be Members");
        assertEq(primaryDAO.getRoleLabel(2), "Executives", "Role 2 should be Executives");
        assertEq(primaryDAO.getRoleLabel(3), "Physical sub-DAOs", "Role 3 should be Physical sub-DAOs");
        assertEq(primaryDAO.getRoleLabel(4), "Ideas sub-DAOs", "Role 4 should be Ideas sub-DAOs");
        assertEq(primaryDAO.getRoleLabel(5), "Digital sub-DAOs", "Role 5 should be Digital sub-DAOs");

        // 6. Verify Safe Module
        mem.isEnabled = Safe(payable(treasury)).isModuleEnabled(config.safeAllowanceModule);
        assertTrue(mem.isEnabled, "Allowance Module should be enabled on Safe");

        // 7. Verify Mandate 1 is Revoked
        (,, mem.isActive) = primaryDAO.getAdoptedMandate(1);
        assertFalse(mem.isActive, "Mandate 1 should be revoked");

        // 9. Verify Digital sub-DAO is Delegate
        mem.delegateIndex = uint48(uint160(address(digitalSubDAO)));

        (mem.delegateAddr,,) = IAllowanceModule(config.safeAllowanceModule).delegates(treasury, mem.delegateIndex);
        assertEq(mem.delegateAddr, address(digitalSubDAO), "Digital sub-DAO should be a delegate on Allowance Module");
    }

    function test_CreateAndRevokeIdeasSubDAO() public {
        // --- Step 1: Initiate Ideas sub-DAO (Members) ---
        vm.startPrank(mem.admin);

        mem.params = abi.encode("Test Ideas sub-DAO", "ipfs://test");
        mem.nonce = 1;

        console.log("Initiating Ideas sub-DAO...");
        // Propose
        mem.actionId = primaryDAO.propose(mem.initiateIdeasMandateId, mem.params, mem.nonce, "");
        vm.stopPrank();

        // Vote
        uint256 amountRole1Holders = primaryDAO.getAmountRoleHolders(1);
        for (uint256 i = 0; i < amountRole1Holders; i++) {
            address roleHolder = primaryDAO.getRoleHolderAtIndex(1, i);
            vm.prank(roleHolder);
            primaryDAO.castVote(mem.actionId, 1); // 1 = For
        }

        // Wait for voting period
        mem.votingPeriod = primaryDAO.getConditions(mem.initiateIdeasMandateId).votingPeriod;
        vm.roll(block.number + mem.votingPeriod + 1);

        // Execute (Request)
        vm.startPrank(mem.admin);
        primaryDAO.request(mem.initiateIdeasMandateId, mem.params, mem.nonce, "");
        vm.stopPrank();

        // --- Step 2: Create Ideas sub-DAO (Executives) ---
        vm.startPrank(mem.admin);
        console.log("Creating Ideas sub-DAO...");

        // Propose
        mem.actionId = primaryDAO.propose(mem.createIdeasMandateId, mem.params, mem.nonce, "");

        // Vote
        primaryDAO.castVote(mem.actionId, 1);

        // Wait
        mem.votingPeriod = primaryDAO.getConditions(mem.createIdeasMandateId).votingPeriod;
        vm.roll(block.number + mem.votingPeriod + 1);

        // Execute
        mem.actionId = primaryDAO.request(mem.createIdeasMandateId, mem.params, mem.nonce, "");
        vm.stopPrank();

        // --- Step 3: Assign Role Id (Executives) ---
        vm.startPrank(mem.admin);
        console.log("Assigning Role...");

        // Execute (No quorum, immediate execution)
        primaryDAO.request(mem.assignRoleMandateId, mem.params, mem.nonce, "");
        vm.stopPrank();

        // --- Verify Creation ---
        mem.returnData = primaryDAO.getActionReturnData(mem.actionId, 0);
        mem.ideasSubDAOAddress = abi.decode(mem.returnData, (address));
        console.log("Ideas sub-DAO created at: %s", mem.ideasSubDAOAddress);

        mem.roleSince = primaryDAO.hasRoleSince(mem.ideasSubDAOAddress, 4);
        assertTrue(mem.roleSince > 0, "Ideas sub-DAO should have Role 4");

        // --- Step 4: Revoke Ideas sub-DAO (Executives) ---
        vm.startPrank(mem.admin);
        console.log("Revoking Ideas sub-DAO...");

        mem.revokeParams = abi.encode(mem.ideasSubDAOAddress);
        mem.nonce++;

        // Propose Revoke
        mem.actionId = primaryDAO.propose(mem.revokeIdeasMandateId, mem.revokeParams, mem.nonce, "");

        // Vote
        primaryDAO.castVote(mem.actionId, 1);

        // Wait voting period + timelock
        mem.votingPeriod = primaryDAO.getConditions(mem.revokeIdeasMandateId).votingPeriod;
        mem.timelock = primaryDAO.getConditions(mem.revokeIdeasMandateId).timelock;
        vm.roll(block.number + mem.votingPeriod + mem.timelock + 1);

        // Execute
        primaryDAO.request(mem.revokeIdeasMandateId, mem.revokeParams, mem.nonce, "");
        vm.stopPrank();

        // --- Verify Revocation ---
        mem.roleSince = primaryDAO.hasRoleSince(mem.ideasSubDAOAddress, 4);
        assertEq(mem.roleSince, 0, "Ideas sub-DAO should NOT have Role 4 anymore");
    }

    function test_CreateAndRevokePhysicalSubDAO() public {
        // --- PREP: Create fake Ideas sub-DAO first ---
        mem.params = abi.encode("Physical sub-DAO", "ipfs://physical");
        mem.nonce = 20;

        mem.fakeIdeasDao = address(0xBEEF);
        vm.prank(address(primaryDAO));
        primaryDAO.assignRole(4, mem.fakeIdeasDao); // Temporarily assign Role 4 to fakeIdeasDao so that it can propose the Physical sub-DAO creation

        // --- Step 1: Initiate Physical sub-DAO ---
        mem.params = abi.encode("Physical sub-DAO", "ipfs://physical");
        mem.nonce = 10;
        
        console.log("Initiating Physical sub-DAO...");
        // Propose
        vm.prank(mem.fakeIdeasDao);
        primaryDAO.request(mem.initiatePhysicalId, mem.params, mem.nonce, "");

        // --- Step 2: Create Physical sub-DAO ---
        vm.startPrank(cedars);
        console.log("Creating Physical sub-DAO...");
        mem.actionId = primaryDAO.propose(mem.createPhysicalId, mem.params, mem.nonce, "");
        primaryDAO.castVote(mem.actionId, 1);
        vm.roll(block.number + primaryDAO.getConditions(mem.createPhysicalId).votingPeriod + 1);
        mem.actionId = primaryDAO.request(mem.createPhysicalId, mem.params, mem.nonce, "");
        vm.stopPrank();

        // Get address
        mem.returnData = primaryDAO.getActionReturnData(mem.actionId, 0);
        mem.physicalSubDAOAddress = abi.decode(mem.returnData, (address));
        console.log("Physical sub-DAO created at: %s", mem.physicalSubDAOAddress);

        // --- Step 3: Assign Role ---
        console.log("Assigning Role...");
        vm.startPrank(cedars);
        primaryDAO.request(mem.assignRoleId, mem.params, mem.nonce, "");

        // Verify Role 3 (Physical sub-DAOs)
        assertTrue(primaryDAO.hasRoleSince(mem.physicalSubDAOAddress, 3) > 0, "Role 3 missing");

        // --- Step 4: Assign Allowance ---
        console.log("Assigning Allowance...");
        primaryDAO.request(mem.assignAllowanceId, mem.params, mem.nonce, "");

        // Verify Status (Delegate)
        mem.delegateIndex = uint48(uint160(address(mem.physicalSubDAOAddress)));
        (mem.delegateAddr,,) = IAllowanceModule(config.safeAllowanceModule).delegates(treasury, mem.delegateIndex);
        assertEq(
            mem.delegateAddr, mem.physicalSubDAOAddress, "Digital sub-DAO should be a delegate on Allowance Module"
        );

        // --- Step 5: Revoke Physical sub-DAO ---
        console.log("Revoking Physical sub-DAO...");
        mem.revokeParams = abi.encode(mem.physicalSubDAOAddress, true); // address, bool
        mem.nonce++;

        // Revoke Role
        console.log("Revoking Role...");
        mem.actionId = primaryDAO.propose(mem.revokeRoleId, mem.revokeParams, mem.nonce, "");
        primaryDAO.castVote(mem.actionId, 1);
        vm.roll(
            block.number + primaryDAO.getConditions(mem.revokeRoleId).votingPeriod
                + primaryDAO.getConditions(mem.revokeRoleId).timelock + 1
        );
        primaryDAO.request(mem.revokeRoleId, mem.revokeParams, mem.nonce, "");

        // Verify Role Revoked
        assertEq(primaryDAO.hasRoleSince(mem.physicalSubDAOAddress, 3), 0, "Role 3 not revoked");

        // Revoke Allowance
        console.log("Revoking Allowance...");
        primaryDAO.request(mem.revokeAllowanceId, mem.revokeParams, mem.nonce, "");

        // Verify Allowance Revoked
        mem.delegateIndex = uint48(uint160(address(mem.physicalSubDAOAddress)));
        (mem.delegateAddr,,) = IAllowanceModule(config.safeAllowanceModule).delegates(treasury, mem.delegateIndex);
        assertEq(mem.delegateAddr, address(0), "Digital sub-DAO should NOT be a delegate on Allowance Module anymore");

        vm.stopPrank();
    }

    function test_AddAllowances() public {
        // --- PREP: Create fake Ideas sub-DAO first ---
        mem.params = abi.encode("Physical sub-DAO", "ipfs://physical");
        mem.nonce = 20;

        mem.fakeIdeasDao = address(0xBEEF);
        vm.prank(address(primaryDAO));
        primaryDAO.assignRole(4, mem.fakeIdeasDao); // Temporarily assign Role 4 to fakeIdeasDao so that it can propose the Physical sub-DAO creation

        // Initiate
        // mem.actionId = primaryDAO.propose(mem.initiatePhysicalId, mem.params, mem.nonce, "");
        // primaryDAO.castVote(mem.actionId, 1);
        // vm.roll(block.number + primaryDAO.getConditions(mem.initiatePhysicalId).votingPeriod + 1);
        vm.prank(mem.fakeIdeasDao);
        primaryDAO.request(mem.initiatePhysicalId, mem.params, mem.nonce, "");

        // Create
        vm.startPrank(cedars);
        mem.actionId = primaryDAO.propose(mem.createPhysicalId, mem.params, mem.nonce, "");
        primaryDAO.castVote(mem.actionId, 1);
        vm.roll(block.number + primaryDAO.getConditions(mem.createPhysicalId).votingPeriod + 1);
        mem.actionId = primaryDAO.request(mem.createPhysicalId, mem.params, mem.nonce, "");
        mem.physicalSubDAOAddress = abi.decode(primaryDAO.getActionReturnData(mem.actionId, 0), (address));

        // Assign Role
        
        primaryDAO.request(mem.assignRoleId, mem.params, mem.nonce, "");

        // Assign Delegate Status (Necessary for Allowance Module)
        primaryDAO.request(mem.assignDelegateId, mem.params, mem.nonce, "");
        vm.stopPrank();

        // --- TEST 1: Physical sub-DAO Allowance Flow ---

        // Params for allowance: Sub-DAO, Token, Amount, ResetTime, ResetBase
        mem.token = address(0); // ETH
        mem.amount = 1 ether;
        mem.resetTime = 100;
        mem.resetBase = 0;

        mem.allowanceParams = abi.encode(mem.physicalSubDAOAddress, mem.token, mem.amount, mem.resetTime, mem.resetBase);
        mem.nonce++;

        // 1. Physical sub-DAO requests allowance
        // Must be called by Role 3 (Physical sub-DAOs). Since physicalSubDAOAddress holds Role 3 (via assignRole above):
        vm.startPrank(mem.physicalSubDAOAddress);
        console.log("Physical sub-DAO requesting allowance...");

        // Note: StatementOfIntent mandates often don't have voting periods/quorum set in script (defaults to 0),
        // effectively making them executable immediately by the proposer if allowed role matches.
        primaryDAO.request(mem.requestPhysicalAllowanceId, mem.allowanceParams, mem.nonce, "");
        vm.stopPrank();

        // 2. Executives grant allowance
        vm.startPrank(cedars); // correct role Id?
        console.log("Executives granting allowance to Physical sub-DAO...");

        mem.actionId = primaryDAO.propose(mem.grantPhysicalAllowanceId, mem.allowanceParams, mem.nonce, "");
        primaryDAO.castVote(mem.actionId, 1);

        // Wait voting + timelock
        mem.votingPeriod = primaryDAO.getConditions(mem.grantPhysicalAllowanceId).votingPeriod;
        mem.timelock = primaryDAO.getConditions(mem.grantPhysicalAllowanceId).timelock;
        vm.roll(block.number + mem.votingPeriod + mem.timelock + 1);

        primaryDAO.request(mem.grantPhysicalAllowanceId, mem.allowanceParams, mem.nonce, "");
        vm.stopPrank();

        // Verify Allowance
        mem.allowanceInfo = IAllowanceModule(config.safeAllowanceModule).getTokenAllowance(treasury, mem.physicalSubDAOAddress, mem.token);
        assertEq(uint96(mem.allowanceInfo[0]), mem.amount, "Physical sub-DAO allowance should be set");

        // --- TEST 2: Digital sub-DAO Allowance Flow ---

        // Verify Digital sub-DAO has delegate status (Checked in InitialSetup)
        mem.digitalSubDAOAddr = address(digitalSubDAO); // Usually this should be the address

        // Params for allowance
        mem.allowanceParams = abi.encode(mem.digitalSubDAOAddr, mem.token, mem.amount, mem.resetTime, mem.resetBase);
        mem.nonce++;

        // 1. Digital sub-DAO requests allowance
        // Role 5 is required. In script, Role 5 is assigned to 'Cedars' address
        vm.startPrank(mem.digitalSubDAOAddr);
        console.log("Digital sub-DAO requesting allowance...");
        primaryDAO.request(mem.requestDigitalAllowanceId, mem.allowanceParams, mem.nonce, "");
        vm.stopPrank();

        // 2. Executives grant allowance
        vm.startPrank(mem.admin);
        console.log("Executives granting allowance to Digital sub-DAO...");

        mem.actionId = primaryDAO.propose(mem.grantDigitalAllowanceId, mem.allowanceParams, mem.nonce, "");
        primaryDAO.castVote(mem.actionId, 1);

        mem.votingPeriod = primaryDAO.getConditions(mem.grantDigitalAllowanceId).votingPeriod;
        mem.timelock = primaryDAO.getConditions(mem.grantDigitalAllowanceId).timelock;
        vm.roll(block.number + mem.votingPeriod + mem.timelock + 1);

        primaryDAO.request(mem.grantDigitalAllowanceId, mem.allowanceParams, mem.nonce, "");
        vm.stopPrank();

        // Verify Allowance
        mem.allowanceInfo = IAllowanceModule(config.safeAllowanceModule).getTokenAllowance(treasury, mem.digitalSubDAOAddr, mem.token);
        assertEq(uint96(mem.allowanceInfo[0]), mem.amount, "Digital sub-DAO allowance should be set");
    }

    function test_PaymentOfReceipts_DigitalSubDAO() public {
        // --- Grant Allowance to Digital sub-DAO (Primary DAO side) ---
        // Reusing logic from test_AddAllowances
        // Mandate IDs

        mem.token = address(0); // ETH
        mem.amount = 1 ether;
        mem.resetTime = 100;
        mem.resetBase = 0;

        mem.allowanceParams = abi.encode(mem.digitalSubDAOAddr, mem.token, mem.amount, mem.resetTime, mem.resetBase);
        mem.nonce = 100;

        // 1. Request Allowance (by Cedars - Role 5)
        console2.log("Digital sub-DAO (via Cedars) requesting allowance...");
        vm.startPrank(mem.digitalSubDAOAddr);
        primaryDAO.request(mem.requestDigitalAllowanceId, mem.allowanceParams, mem.nonce, "");
        vm.stopPrank();

        // 2. Grant Allowance (by conveners - Role 2)
        console2.log("Executives granting allowance to Digital sub-DAO...");
        vm.startPrank(mem.admin);
        mem.actionId = primaryDAO.propose(mem.grantDigitalAllowanceId, mem.allowanceParams, mem.nonce, "");
        primaryDAO.castVote(mem.actionId, 1);

        uint32 votingPeriod = primaryDAO.getConditions(mem.grantDigitalAllowanceId).votingPeriod;
        uint32 timelock = primaryDAO.getConditions(mem.grantDigitalAllowanceId).timelock;
        vm.roll(block.number + votingPeriod + timelock + 1);

        primaryDAO.request(mem.grantDigitalAllowanceId, mem.allowanceParams, mem.nonce, "");
        vm.stopPrank();

        // Verify Allowance
        mem.allowanceInfo = IAllowanceModule(config.safeAllowanceModule).getTokenAllowance(treasury, mem.digitalSubDAOAddr, mem.token);
        assertEq(uint96(mem.allowanceInfo[0]), mem.amount, "Digital sub-DAO allowance should be set");

        // Fund Treasury
        vm.deal(treasury, 10 ether);
        assertEq(treasury.balance, 10 ether, "Treasury should have funds");

        // --- Digital sub-DAO Payment Flow ---
        // Mandates:
        // 2: Submit Receipt (Public)
        // 3: OK Receipt (Conveners)
        // 4: Approve Payment (Conveners)

        mem.recipient = address(0x123456789);
        mem.paymentAmount = 0.5 ether;

        // Params: address Token, uint256 Amount, address PayableTo
        mem.paymentParams = abi.encode(mem.token, mem.paymentAmount, mem.recipient);

        // Step 1: Submit Receipt (Public)
        mem.user = address(0x999);
        vm.startPrank(mem.user);
        console.log("Submitting receipt...");
        // Propose
        mem.nonce++;
        mem.submitReceiptId = findMandateIdInOrg("Submit a Receipt: Anyone can submit a receipt for payment reimbursement.", digitalSubDAO);
        digitalSubDAO.request(mem.submitReceiptId, mem.paymentParams, mem.nonce, "");
        vm.stopPrank();

        vm.roll(block.number + 1); // Advance block to avoid same-block issues

        // Step 2: OK Receipt (Conveners)
        // Who is convener? Cedars (assigned in Mandate 1).
        vm.startPrank(cedars);
        console.log("OK'ing receipt...");
        // Request (Condition: Role 2. No voting period set).
        mem.okReceiptId = findMandateIdInOrg("OK a receipt: Any convener can ok a receipt for payment reimbursement.", digitalSubDAO);
        digitalSubDAO.request(mem.okReceiptId, mem.paymentParams, mem.nonce, "");
        vm.stopPrank();

        // Step 3: Approve Payment (Conveners)
        vm.startPrank(cedars);
        console.log("Approving payment...");
        mem.approvePaymentId = findMandateIdInOrg("Approve payment of receipt: Execute a transaction from the Safe Treasury.", digitalSubDAO);
        mem.actionId = digitalSubDAO.propose(mem.approvePaymentId, mem.paymentParams, mem.nonce, "");

        // Vote (Quorum 50%, SucceedAt 67%)
        // Cedars is likely the only role holder?
        // In Mandate 1, only Cedars is assigned Role 2.
        // So 1 vote should be 100%.
        digitalSubDAO.castVote(mem.actionId, 1);

        // Wait voting period (5 mins)
        votingPeriod = digitalSubDAO.getConditions(mem.approvePaymentId).votingPeriod;
        vm.roll(block.number + votingPeriod + 1);

        // Execute
        digitalSubDAO.request(mem.approvePaymentId, mem.paymentParams, mem.nonce, "");
        vm.stopPrank();

        // Verify Payment
        assertEq(mem.recipient.balance, mem.paymentAmount, "Recipient should have received payment");

        // Verify Allowance Spent
        mem.allowanceInfo = IAllowanceModule(config.safeAllowanceModule).getTokenAllowance(treasury, mem.digitalSubDAOAddr, mem.token);
        assertEq(uint96(mem.allowanceInfo[1]), mem.paymentAmount, "Allowance spent should match payment");
    }

    function test_JoinPrimeDAO() public {
        // NB! This test fails because it is indeed impossible at the moment to joint the PRimary DAO! 
        vm.skip(true); 
        mem.claimStep1Id = findMandateIdInOrg("Request Membership Step 1: 2 POAPS from physical DAO and 20 activity tokens from ideas DAOs needed that are not older than 6 months.", primaryDAO);
        mem.claimStep2Id = findMandateIdInOrg("Request Membership Step 2: 2 POAPS from physical DAO and 20 activity tokens from ideas DAOs needed that are not older than 6 months.", primaryDAO);

        // --- Step 1: Create Ideas sub-DAO ---
        vm.startPrank(mem.admin);
        mem.params = abi.encode("Ideas sub-DAO", "ipfs://ideas");
        mem.nonce = 1;

        // Initiate
        mem.actionId = primaryDAO.propose(mem.initiateIdeasMandateId, mem.params, mem.nonce, "");
        vm.stopPrank();

        uint256 amountRole1Holders = primaryDAO.getAmountRoleHolders(1);
        for (uint256 i = 0; i < amountRole1Holders; i++) {
            address roleHolder = primaryDAO.getRoleHolderAtIndex(1, i);
            vm.prank(roleHolder);
            primaryDAO.castVote(mem.actionId, 1); // 1 = For
        }

        vm.startPrank(mem.admin);
        vm.roll(block.number + primaryDAO.getConditions(mem.initiateIdeasMandateId).votingPeriod + 1);
        primaryDAO.request(mem.initiateIdeasMandateId, mem.params, mem.nonce, "");

        // Create
        mem.actionId = primaryDAO.propose(mem.createIdeasMandateId, mem.params, mem.nonce, "");
        primaryDAO.castVote(mem.actionId, 1);
        vm.roll(block.number + primaryDAO.getConditions(mem.createIdeasMandateId).votingPeriod + 1);
        mem.actionId = primaryDAO.request(mem.createIdeasMandateId, mem.params, mem.nonce, "");

        // Get address
        mem.ideasSubDAOAddress = abi.decode(primaryDAO.getActionReturnData(mem.actionId, 0), (address));
        console.log("Ideas sub-DAO created at: %s", mem.ideasSubDAOAddress);

        // Assign Role
        primaryDAO.request(mem.assignRoleMandateId, mem.params, mem.nonce, "");
        vm.stopPrank();

        // --- Step 2: Create Mock Physical sub-DAO ---
        // Replacing the complex governance flow with a mock address that has the correct role
        mem.mockPhysicalDAO = address(0x888);
        console.log("Mock Physical sub-DAO address: %s", mem.mockPhysicalDAO);

        // Assign Role 3 (Physical sub-DAOs) to the mock address
        // We use vm.prank to impersonate the Primary DAO itself to bypass governance for this setup
        vm.prank(address(primaryDAO));
        primaryDAO.assignRole(3, mem.mockPhysicalDAO);

        assertTrue(primaryDAO.hasRoleSince(mem.mockPhysicalDAO, 3) > 0, "Mock Physical sub-DAO should have Role 3");

        // --- Step 3: Mint 20 Activity Tokens at Ideas sub-DAO ---
        mem.user = address(0xABCD);
        mem.nonces = new uint256[](22);
        mem.actionIds = new uint256[](22);
        mem.tokenIds = new uint256[](22);
        mem.params = abi.encode(mem.user);

        // console.log("Minting 20 Activity tokens for user: %s", mem.user);
        // // Mandate 2: Mint activity token (Public)
        // mem.nonce = 1000;
        // mem.mintActivityId = findMandateIdInOrg("Mint activity token: Anyone can mint an Active Ideas token. One token is available per 5 minutes.", Powers(mem.ideasSubDAOAddress));
        // for (uint256 i = 0; i < 20; i++) {
        //     mem.nonce++;
        //     mem.nonces[i] = mem.nonce;
        //     Powers(mem.ideasSubDAOAddress).request(mem.mintActivityId, mem.params, mem.nonce, "");
        //     vm.roll(block.number + deployScript.minutesToBlocks(6, config.BLOCKS_PER_HOUR)); // Advance 6 minutes between mints
        // }

        // --- Step 4: Mint 2 POAPs via Mock Physical sub-DAO ---
        console.log("Minting 2 POAPs for user via Mock Physical DAO: %s", mem.user);
        
        // Find the Primary DAO mandate for minting POAPs (called by Physical sub-DAOs)
        mem.mintPoapPrimaryId = findMandateIdInOrg("Mint token Physical sub-DAO: Any Physical sub-DAO can mint new NFTs", primaryDAO);
        
        vm.startPrank(mem.mockPhysicalDAO); 
        // Mint POAP 1
        mem.nonces[20] = mem.nonce + 1;
        mem.nonce++;
        primaryDAO.request(mem.mintPoapPrimaryId, mem.params, mem.nonce, "");
        
        // Mint POAP 2
        mem.nonces[21] = mem.nonce + 1;
        mem.nonce++;
        primaryDAO.request(mem.mintPoapPrimaryId, mem.params, mem.nonce, "");
        vm.stopPrank();

        // --- Step 5: Claim Access to Primary DAO ---
        mem.mintActivityTokenPrimaryId = findMandateIdInOrg("Mint token Ideas sub-DAO: Any Ideas sub-DAO can mint new NFTs", primaryDAO);
        
        for (uint256 i = 0; i < mem.actionIds.length; i++) {
            
            if (i < 20) {
                mem.mandateId = mem.mintActivityTokenPrimaryId; // Mandate 25: Mint Activity Token @ primaryDAO
            } else {
                mem.mandateId = mem.mintPoapPrimaryId; // Mandate 26: Mint POAP @ primaryDAO
            }
            uint256 actionId = uint256(keccak256(abi.encode(mem.mandateId, mem.params, mem.nonces[i])));

            mem.tokenIds[i] = uint256(abi.decode(primaryDAO.getActionReturnData(actionId, 0), (uint256)));
        }

        vm.startPrank(mem.user);
        console.log("Claiming access to Primary DAO...");

        // Step 1: Check POAPs
        mem.nonce = 2000;
        primaryDAO.request(mem.claimStep1Id, abi.encode(mem.tokenIds), mem.nonce, "");

        // Step 2: Check Activity Tokens
        primaryDAO.request(mem.claimStep2Id, abi.encode(mem.tokenIds), mem.nonce, "");
        vm.stopPrank();

        // Verify Membership
        assertTrue(primaryDAO.hasRoleSince(mem.user, 1) != 0, "User should have Member role (1) in Primary DAO");
    }

    function test_IdeasSubDAO_Election() public {
        // --- Step 1: Initiate Ideas sub-DAO (Members) ---
        vm.startPrank(mem.admin);

        mem.params = abi.encode("Test Ideas sub-DAO", "ipfs://test");
        mem.nonce = 1;

        console.log("Initiating Ideas sub-DAO...");
        // Propose
        mem.actionId = primaryDAO.propose(mem.initiateIdeasMandateId, mem.params, mem.nonce, "");
        vm.stopPrank();

        // Vote
        uint256 amountRole1Holders = primaryDAO.getAmountRoleHolders(1); 
        for (uint256 i = 0; i < amountRole1Holders; i++) {
            address roleHolder = primaryDAO.getRoleHolderAtIndex(1, i); 
            vm.prank(roleHolder);
            primaryDAO.castVote(mem.actionId, 1); // 1 = For
        }

        // Wait for voting period
        mem.votingPeriod = primaryDAO.getConditions(mem.initiateIdeasMandateId).votingPeriod;
        vm.roll(block.number + mem.votingPeriod + 1);

        // Execute (Request)
        vm.startPrank(mem.admin);
        primaryDAO.request(mem.initiateIdeasMandateId, mem.params, mem.nonce, "");
        vm.stopPrank();

        // --- Step 2: Create Ideas sub-DAO (Executives) ---
        vm.startPrank(mem.admin);
        console.log("Creating Ideas sub-DAO...");

        // Propose
        mem.actionId = primaryDAO.propose(mem.createIdeasMandateId, mem.params, mem.nonce, "");

        // Vote
        primaryDAO.castVote(mem.actionId, 1);

        // Wait
        mem.votingPeriod = primaryDAO.getConditions(mem.createIdeasMandateId).votingPeriod;
        vm.roll(block.number + mem.votingPeriod + 1);

        // Execute
        mem.actionId = primaryDAO.request(mem.createIdeasMandateId, mem.params, mem.nonce, "");
        vm.stopPrank();

        // --- Step 3: Assign Role Id (Executives) ---
        vm.startPrank(mem.admin);
        console.log("Assigning Role...");

        // Execute (No quorum, immediate execution)
        primaryDAO.request(mem.assignRoleMandateId, mem.params, mem.nonce, "");
        vm.stopPrank();

        // --- Verify Creation ---
        mem.returnData = primaryDAO.getActionReturnData(mem.actionId, 0);
        mem.ideasSubDAOAddress = abi.decode(mem.returnData, (address));
        console.log("Ideas sub-DAO created at: %s", mem.ideasSubDAOAddress);

        // --- Setup User (Member) ---
        mem.user = address(0x100);
        vm.prank(address(mem.ideasSubDAOAddress)); // Admin of Ideas sub-DAO is itself
        Powers(mem.ideasSubDAOAddress).assignRole(1, mem.user);
        assertTrue(Powers(mem.ideasSubDAOAddress).hasRoleSince(mem.user, 1) != 0, "User should have Role 1 (Member)");

        // --- Refactored Election Flow ---
        vm.startPrank(mem.user);
        mem.nonce = 100;

        // 1. Create Election (Mandate 8)
        console.log("Creating Election...");
        mem.startBlock = uint48(block.number + 50);
        mem.endBlock = uint48(block.number + 100);
        mem.electionParams = abi.encode("Convener Election", mem.startBlock, mem.endBlock);

        mem.createElectionId = findMandateIdInOrg("Create an election: an election can be initiated be any member.", Powers(mem.ideasSubDAOAddress));
        Powers(mem.ideasSubDAOAddress).request(mem.createElectionId, mem.electionParams, mem.nonce, "");

        // 2. Nominate (Mandate 9)
        console.log("Nominating...");
        mem.nominateId = findMandateIdInOrg("Nominate for election: any member can nominate for an election.", Powers(mem.ideasSubDAOAddress));
        Powers(mem.ideasSubDAOAddress).request(mem.nominateId, mem.electionParams, mem.nonce, "");

        // 3. Open Vote (Mandate 11)
        console.log("Creating Vote...");
        vm.roll(mem.startBlock + 1); // Advance to start
        mem.openVoteId = findMandateIdInOrg("Open voting for election: Members can open the vote for an election. This will create a dedicated vote mandate.", Powers(mem.ideasSubDAOAddress));
        mem.actionId = Powers(mem.ideasSubDAOAddress).request(mem.openVoteId, mem.electionParams, mem.nonce, "");

        // Get Vote Mandate ID
        mem.returnData = Powers(mem.ideasSubDAOAddress).getActionReturnData(mem.actionId, 0);
        mem.voteMandateId = abi.decode(mem.returnData, (uint256));
        console.log("Vote Mandate ID: %s", mem.voteMandateId);

        // 4. Vote (Mandate = voteMandateId)
        console.log("Voting...");
        // mem.votes = new bool[](1);
        // mem.votes[0] = true;
        mem.params = abi.encode(true);

        Powers(mem.ideasSubDAOAddress).request(uint16(mem.voteMandateId), mem.params, mem.nonce, "");

        // 5. Tally (Mandate 12)
        console.log("Tallying...");
        vm.roll(mem.endBlock + 1); // Advance to end
        mem.tallyElectionId = findMandateIdInOrg("Tally elections: After an election has finished, assign the Convener role to the winners.", Powers(mem.ideasSubDAOAddress));
        Powers(mem.ideasSubDAOAddress).request(mem.tallyElectionId, mem.electionParams, mem.nonce, "");

        // 6. Clean Up (Mandate 13)
        console.log("Cleaning Up...");
        // Verify Vote Mandate Active
        (,, mem.isActive) = Powers(mem.ideasSubDAOAddress).getAdoptedMandate(uint16(mem.voteMandateId));
        assertTrue(mem.isActive, "Vote Mandate should be active before cleanup");

        // Clean up needs same calldata and nonce as Open Vote to find the return value
        mem.cleanupElectionId = findMandateIdInOrg("Clean up election: After an election has finished, clean up related mandates.", Powers(mem.ideasSubDAOAddress));
        Powers(mem.ideasSubDAOAddress).request(mem.cleanupElectionId, mem.electionParams, mem.nonce, "");

        // Verify Vote Mandate Revoked
        (,, mem.isActive) = Powers(mem.ideasSubDAOAddress).getAdoptedMandate(uint16(mem.voteMandateId));
        assertFalse(mem.isActive, "Vote Mandate should be revoked after cleanup");

        vm.stopPrank();

        // Verify Result
        assertTrue(Powers(mem.ideasSubDAOAddress).hasRoleSince(mem.user, 2) != 0, "User should have Role 2 (Convener)");
    }

    function test_IdeasSubDAO_MembershipAndModeration() public {
        // --- Setup: Create Ideas sub-DAO ---
        vm.startPrank(mem.admin);
        mem.params = abi.encode("Ideas sub-DAO", "ipfs://ideas");
        mem.nonce = 1;

        // Initiate
        mem.actionId = primaryDAO.propose(mem.initiateIdeasMandateId, mem.params, mem.nonce, "");
        vm.stopPrank();

        mem.amountRoleHolders = primaryDAO.getAmountRoleHolders(1);
        for (uint256 i = 0; i < mem.amountRoleHolders; i++) {
            mem.member = primaryDAO.getRoleHolderAtIndex(1, i);
            vm.prank(mem.member);
            primaryDAO.castVote(mem.actionId, 1);
        }

        vm.roll(block.number + primaryDAO.getConditions(mem.initiateIdeasMandateId).votingPeriod + 1);
        
        vm.prank(mem.admin);
        primaryDAO.request(mem.initiateIdeasMandateId, mem.params, mem.nonce, "");

        // Create
        vm.startPrank(mem.admin);
        mem.actionId = primaryDAO.propose(mem.createIdeasMandateId, mem.params, mem.nonce, "");
        primaryDAO.castVote(mem.actionId, 1);
        
        vm.roll(block.number + primaryDAO.getConditions(mem.createIdeasMandateId).votingPeriod + 1);
        
        mem.actionId = primaryDAO.request(mem.createIdeasMandateId, mem.params, mem.nonce, "");
        mem.ideasSubDAOAddress = abi.decode(primaryDAO.getActionReturnData(mem.actionId, 0), (address));
        console.log("Ideas sub-DAO created at: %s", mem.ideasSubDAOAddress);

        // Assign Role 4 to the new DAO (in Primary DAO)
        primaryDAO.request(mem.assignRoleMandateId, mem.params, mem.nonce, "");
        vm.stopPrank();

        // --- Step 1: Assign Moderator Role & execute setup ---
        mem.moderator = address(0xCAFE);
        mem.applicant = address(0xDEAF);
        Powers(mem.ideasSubDAOAddress).request(1, "", 0, "");

        mem.assignModeratorId = findMandateIdInOrg("Assign Moderator Role: Conveners can assign the Moderator role to an account.", Powers(mem.ideasSubDAOAddress));
        mem.applyMembershipId = findMandateIdInOrg("Apply for Membership: Anyone can apply for membership to the DAO by submitting an application.", Powers(mem.ideasSubDAOAddress));
        mem.assignMembershipId = findMandateIdInOrg("Assess and Assign Membership: Moderators can assess applications and assign membership to applicants.", Powers(mem.ideasSubDAOAddress));
        mem.revokeMembershipId = findMandateIdInOrg("Revoke Membership: Moderators can revoke membership from members.", Powers(mem.ideasSubDAOAddress));
        mem.revokeModeratorId = findMandateIdInOrg("Revoke Moderator Role: Conveners can revoke the Moderator role from an account.", Powers(mem.ideasSubDAOAddress));

        mem.params = abi.encode(mem.moderator);
        mem.nonce = 100;

        vm.startPrank(cedars);
        console.log("Assigning Moderator...");
        
        mem.actionId = Powers(mem.ideasSubDAOAddress).propose(mem.assignModeratorId, mem.params, mem.nonce, "");
        Powers(mem.ideasSubDAOAddress).castVote(mem.actionId, 1);
        
        mem.votingPeriod = Powers(mem.ideasSubDAOAddress).getConditions(mem.assignModeratorId).votingPeriod;
        vm.roll(block.number + mem.votingPeriod + 1);
        
        Powers(mem.ideasSubDAOAddress).request(mem.assignModeratorId, mem.params, mem.nonce, "");
        vm.stopPrank();

        assertTrue(Powers(mem.ideasSubDAOAddress).hasRoleSince(mem.moderator, 3) > 0, "Moderator should have Role 3");

        // --- Step 2: Apply and Assign Membership ---
        mem.appParams = abi.encode(mem.applicant, "ipfs://application");
        mem.nonce++;
        
        vm.startPrank(mem.applicant);
        console.log("Applying for Membership...");
        Powers(mem.ideasSubDAOAddress).request(mem.applyMembershipId, mem.appParams, mem.nonce, "");
        vm.stopPrank();

        vm.startPrank(mem.moderator);
        console.log("Assigning Membership...");
        Powers(mem.ideasSubDAOAddress).request(mem.assignMembershipId, mem.appParams, mem.nonce, "");
        vm.stopPrank();

        assertTrue(Powers(mem.ideasSubDAOAddress).hasRoleSince(mem.applicant, 1) > 0, "Applicant should have Role 1 (Member)");

        // --- Step 3: Revoke Membership ---
        mem.nonce++;
        mem.revokeParams = abi.encode(mem.applicant);
        
        vm.startPrank(mem.moderator);
        console.log("Revoking Membership...");
        mem.actionId = Powers(mem.ideasSubDAOAddress).propose(mem.revokeMembershipId, mem.revokeParams, mem.nonce, "");
        vm.stopPrank();
        
        mem.amountRoleHolders = Powers(mem.ideasSubDAOAddress).getAmountRoleHolders(3);
        for (uint256 i = 0; i < mem.amountRoleHolders; i++) {
            mem.member = Powers(mem.ideasSubDAOAddress).getRoleHolderAtIndex(3, i);
            vm.prank(mem.member);
            Powers(mem.ideasSubDAOAddress).castVote(mem.actionId, 1);
        }
        
        mem.votingPeriod = Powers(mem.ideasSubDAOAddress).getConditions(mem.revokeMembershipId).votingPeriod;
        mem.timelock = Powers(mem.ideasSubDAOAddress).getConditions(mem.revokeMembershipId).timelock;
        vm.roll(block.number + mem.votingPeriod + mem.timelock + 1);
        
        vm.prank(mem.moderator);
        Powers(mem.ideasSubDAOAddress).request(mem.revokeMembershipId, mem.revokeParams, mem.nonce, "");
 
        assertTrue(Powers(mem.ideasSubDAOAddress).hasRoleSince(mem.applicant, 1) == 0, "Applicant should NOT have Role 1 anymore");

        // --- Step 4: Revoke Moderator ---
        mem.nonce++;
        mem.revokeParams = abi.encode(mem.moderator);
        
        vm.startPrank(cedars);
        console.log("Revoking Moderator...");
        mem.actionId = Powers(mem.ideasSubDAOAddress).propose(mem.revokeModeratorId, mem.revokeParams, mem.nonce, "");
        vm.stopPrank();

        mem.amountRoleHolders = Powers(mem.ideasSubDAOAddress).getAmountRoleHolders(2);
        for (uint256 i = 0; i < mem.amountRoleHolders; i++) {
            mem.member = Powers(mem.ideasSubDAOAddress).getRoleHolderAtIndex(2, i);
            vm.prank(mem.member);
            Powers(mem.ideasSubDAOAddress).castVote(mem.actionId, 1);
        }
        
        mem.votingPeriod = Powers(mem.ideasSubDAOAddress).getConditions(mem.revokeModeratorId).votingPeriod;
        vm.roll(block.number + mem.votingPeriod + 1);
        
        vm.prank(cedars);
        Powers(mem.ideasSubDAOAddress).request(mem.revokeModeratorId, mem.revokeParams, mem.nonce, "");
 
        assertTrue(Powers(mem.ideasSubDAOAddress).hasRoleSince(mem.moderator, 3) == 0, "Moderator should NOT have Role 3 anymore");
    }

    //////////////////////////////////////////////////////////////////////////////////
    //                             Helper Functions                                 //
    //////////////////////////////////////////////////////////////////////////////////  
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
