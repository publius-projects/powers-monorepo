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
    }
    Mem mem;

    CulturalStewardsDAO deployScript;
    Powers primeDAO;
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
        primeDAO = deployScript.getPrimeDAO();  
        config = deployScript.getConfig();

        // Execute "Initial Setup"
        vm.prank(cedars);
        primeDAO.request(1, "", 0, "");

        // Identify Mandate IDs
        console.log("Executing Initial Setup Digital");
        digitalSubDAO = deployScript.getDigitalSubDAO();
        digitalSubDAO.request(1, "", 0, "");

        mem.admin = primeDAO.getRoleHolderAtIndex(1, 0);
        console.log("Admin address: %s", mem.admin);

        treasury = primeDAO.getTreasury();
        console.log("Treasury address: %s", treasury);

        mem.digitalSubDAOAddr = address(digitalSubDAO);
        vm.prank(mem.digitalSubDAOAddr);
        digitalSubDAO.assignRole(2, cedars); // Assign Role 2 to Cedars AT THE DIGITAL DAO. (so that cedars can act there as convener as well.)

        ///////////////////////////// 
        // find mandate IDs using findMandateIdInOrg function if needed //
        mem.initiateIdeasMandateId = findMandateIdInOrg("Initiate Ideas sub-DAO: Initiate creation of Ideas sub-DAO", primeDAO);
        mem.createIdeasMandateId = findMandateIdInOrg("Create Ideas sub-DAO: Execute Ideas sub-DAO creation", primeDAO);
        mem.assignRoleMandateId = findMandateIdInOrg("Assign role Id to DAO: Assign role id 4 (Ideas sub-DAO) to the new DAO", primeDAO);
        mem.revokeIdeasMandateId = findMandateIdInOrg("Revoke role Id: Revoke role id 4 (Ideas sub-DAO) from the DAO", primeDAO);

        mem.initiatePhysicalId = findMandateIdInOrg("Initiate Physical sub-DAO: Initiate creation of Physical sub-DAO", primeDAO);
        mem.createPhysicalId = findMandateIdInOrg("Create Physical sub-DAO: Execute Physical sub-DAO creation", primeDAO);
        mem.assignRoleId = findMandateIdInOrg("Assign role Id: Assign role Id 3 to Physical sub-DAO", primeDAO);
        
        mem.assignDelegateId = findMandateIdInOrg("Assign Delegate status: Assign delegate status at Safe treasury to the Physical sub-DAO", primeDAO);
        mem.assignAllowanceId = mem.assignDelegateId;

        mem.revokeRoleId = findMandateIdInOrg("Revoke Role Id: Revoke role Id 3 from Physical sub-DAO", primeDAO);
        mem.revokeAllowanceId = findMandateIdInOrg("Revoke Delegate status: Revoke delegate status Physical sub-DAO at the Safe treasury", primeDAO);
        
        mem.requestPhysicalAllowanceId = findMandateIdInOrg("Request additional allowance: Any Physical sub-DAO can request an allowance from the Safe Treasury.", primeDAO);
        mem.grantPhysicalAllowanceId = findMandateIdInOrg("Set Allowance: Execute and set allowance for a Physical sub-DAO.", primeDAO);
        
        mem.requestDigitalAllowanceId = findMandateIdInOrg("Request additional allowance: The Digital sub-DAO can request an allowance from the Safe Treasury.", primeDAO);
        mem.grantDigitalAllowanceId = findMandateIdInOrg("Set Allowance: Execute and set allowance for the Digital sub-DAO.", primeDAO);
    }

    function test_InitialSetup() public {
        // 4. Verify Role Labels
        assertEq(primeDAO.getRoleLabel(1), "Members", "Role 1 should be Members");
        assertEq(primeDAO.getRoleLabel(2), "Executives", "Role 2 should be Executives");
        assertEq(primeDAO.getRoleLabel(3), "Physical sub-DAOs", "Role 3 should be Physical sub-DAOs");
        assertEq(primeDAO.getRoleLabel(4), "Ideas sub-DAOs", "Role 4 should be Ideas sub-DAOs");
        assertEq(primeDAO.getRoleLabel(5), "Digital sub-DAOs", "Role 5 should be Digital sub-DAOs");

        // 6. Verify Safe Module
        mem.isEnabled = Safe(payable(treasury)).isModuleEnabled(config.safeAllowanceModule);
        assertTrue(mem.isEnabled, "Allowance Module should be enabled on Safe");

        // 7. Verify Mandate 1 is Revoked
        (,, mem.isActive) = primeDAO.getAdoptedMandate(1);
        assertFalse(mem.isActive, "Mandate 1 should be revoked");

        // 9. Verify Digital sub-DAO is Delegate
        Powers digitalSubDAO = deployScript.getDigitalSubDAO();
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
        mem.actionId = primeDAO.propose(mem.initiateIdeasMandateId, mem.params, mem.nonce, "");

        // Vote
        primeDAO.castVote(mem.actionId, 1); // 1 = For

        // Wait for voting period
        mem.votingPeriod = primeDAO.getConditions(mem.initiateIdeasMandateId).votingPeriod;
        vm.roll(block.number + mem.votingPeriod + 1);

        // Execute (Request)
        primeDAO.request(mem.initiateIdeasMandateId, mem.params, mem.nonce, "");
        vm.stopPrank();

        // --- Step 2: Create Ideas sub-DAO (Executives) ---
        vm.startPrank(mem.admin);
        console.log("Creating Ideas sub-DAO...");

        // Propose
        mem.actionId = primeDAO.propose(mem.createIdeasMandateId, mem.params, mem.nonce, "");

        // Vote
        primeDAO.castVote(mem.actionId, 1);

        // Wait
        mem.votingPeriod = primeDAO.getConditions(mem.createIdeasMandateId).votingPeriod;
        vm.roll(block.number + mem.votingPeriod + 1);

        // Execute
        mem.actionId = primeDAO.request(mem.createIdeasMandateId, mem.params, mem.nonce, "");
        vm.stopPrank();

        // --- Step 3: Assign Role Id (Executives) ---
        vm.startPrank(mem.admin);
        console.log("Assigning Role...");

        // Execute (No quorum, immediate execution)
        primeDAO.request(mem.assignRoleMandateId, mem.params, mem.nonce, "");
        vm.stopPrank();

        // --- Verify Creation ---
        mem.returnData = primeDAO.getActionReturnData(mem.actionId, 0);
        mem.ideasSubDAOAddress = abi.decode(mem.returnData, (address));
        Powers ideasSubDAO = Powers(mem.ideasSubDAOAddress);
        console.log("Ideas sub-DAO created at: %s", mem.ideasSubDAOAddress);

        mem.roleSince = primeDAO.hasRoleSince(mem.ideasSubDAOAddress, 4);
        assertTrue(mem.roleSince > 0, "Ideas sub-DAO should have Role 4");

        // --- Step 4: Revoke Ideas sub-DAO (Executives) ---
        vm.startPrank(mem.admin);
        console.log("Revoking Ideas sub-DAO...");

        mem.revokeParams = abi.encode(mem.ideasSubDAOAddress);
        mem.nonce++;

        // Propose Revoke
        mem.actionId = primeDAO.propose(mem.revokeIdeasMandateId, mem.revokeParams, mem.nonce, "");

        // Vote
        primeDAO.castVote(mem.actionId, 1);

        // Wait voting period + timelock
        mem.votingPeriod = primeDAO.getConditions(mem.revokeIdeasMandateId).votingPeriod;
        mem.timelock = primeDAO.getConditions(mem.revokeIdeasMandateId).timelock;
        vm.roll(block.number + mem.votingPeriod + mem.timelock + 1);

        // Execute
        primeDAO.request(mem.revokeIdeasMandateId, mem.revokeParams, mem.nonce, "");
        vm.stopPrank();

        // --- Verify Revocation ---
        mem.roleSince = primeDAO.hasRoleSince(mem.ideasSubDAOAddress, 4);
        assertEq(mem.roleSince, 0, "Ideas sub-DAO should NOT have Role 4 anymore");
    }

    function test_CreateAndRevokePhysicalSubDAO() public {
        // --- PREP: Create fake Ideas sub-DAO first ---
        mem.params = abi.encode("Physical sub-DAO", "ipfs://physical");
        mem.nonce = 20;

        address fakeIdeasDao = address(0xBEEF);
        vm.prank(address(primeDAO));
        primeDAO.assignRole(4, fakeIdeasDao); // Temporarily assign Role 4 to fakeIdeasDao so that it can propose the Physical sub-DAO creation

        // --- Step 1: Initiate Physical sub-DAO ---
        mem.params = abi.encode("Physical sub-DAO", "ipfs://physical");
        mem.nonce = 10;
        
        console.log("Initiating Physical sub-DAO...");
        // Propose
        vm.prank(fakeIdeasDao);
        primeDAO.request(mem.initiatePhysicalId, mem.params, mem.nonce, "");

        // --- Step 2: Create Physical sub-DAO ---
        vm.startPrank(cedars);
        console.log("Creating Physical sub-DAO...");
        mem.actionId = primeDAO.propose(mem.createPhysicalId, mem.params, mem.nonce, "");
        primeDAO.castVote(mem.actionId, 1);
        vm.roll(block.number + primeDAO.getConditions(mem.createPhysicalId).votingPeriod + 1);
        mem.actionId = primeDAO.request(mem.createPhysicalId, mem.params, mem.nonce, "");
        vm.stopPrank();

        // Get address
        bytes memory returnData = primeDAO.getActionReturnData(mem.actionId, 0);
        mem.physicalSubDAOAddress = abi.decode(returnData, (address));
        Powers physicalSubDAO = Powers(mem.physicalSubDAOAddress);
        console.log("Physical sub-DAO created at: %s", mem.physicalSubDAOAddress);

        // --- Step 3: Assign Role ---
        console.log("Assigning Role...");
        vm.startPrank(cedars);
        primeDAO.request(mem.assignRoleId, mem.params, mem.nonce, "");

        // Verify Role 3 (Physical sub-DAOs)
        assertTrue(primeDAO.hasRoleSince(mem.physicalSubDAOAddress, 3) > 0, "Role 3 missing");

        // --- Step 4: Assign Allowance ---
        console.log("Assigning Allowance...");
        primeDAO.request(mem.assignAllowanceId, mem.params, mem.nonce, "");

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
        mem.actionId = primeDAO.propose(mem.revokeRoleId, mem.revokeParams, mem.nonce, "");
        primeDAO.castVote(mem.actionId, 1);
        vm.roll(
            block.number + primeDAO.getConditions(mem.revokeRoleId).votingPeriod
                + primeDAO.getConditions(mem.revokeRoleId).timelock + 1
        );
        primeDAO.request(mem.revokeRoleId, mem.revokeParams, mem.nonce, "");

        // Verify Role Revoked
        assertEq(primeDAO.hasRoleSince(mem.physicalSubDAOAddress, 3), 0, "Role 3 not revoked");

        // Revoke Allowance
        console.log("Revoking Allowance...");
        primeDAO.request(mem.revokeAllowanceId, mem.revokeParams, mem.nonce, "");

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

        address fakeIdeasDao = address(0xBEEF);
        vm.prank(address(primeDAO));
        primeDAO.assignRole(4, fakeIdeasDao); // Temporarily assign Role 4 to fakeIdeasDao so that it can propose the Physical sub-DAO creation

        // Initiate
        // mem.actionId = primeDAO.propose(mem.initiatePhysicalId, mem.params, mem.nonce, "");
        // primeDAO.castVote(mem.actionId, 1);
        // vm.roll(block.number + primeDAO.getConditions(mem.initiatePhysicalId).votingPeriod + 1);
        vm.prank(fakeIdeasDao);
        primeDAO.request(mem.initiatePhysicalId, mem.params, mem.nonce, "");

        // Create
        vm.startPrank(cedars);
        mem.actionId = primeDAO.propose(mem.createPhysicalId, mem.params, mem.nonce, "");
        primeDAO.castVote(mem.actionId, 1);
        vm.roll(block.number + primeDAO.getConditions(mem.createPhysicalId).votingPeriod + 1);
        mem.actionId = primeDAO.request(mem.createPhysicalId, mem.params, mem.nonce, "");
        mem.physicalSubDAOAddress = abi.decode(primeDAO.getActionReturnData(mem.actionId, 0), (address));

        // Assign Role
        
        primeDAO.request(mem.assignRoleId, mem.params, mem.nonce, "");

        // Assign Delegate Status (Necessary for Allowance Module)
        primeDAO.request(mem.assignDelegateId, mem.params, mem.nonce, "");
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
        primeDAO.request(mem.requestPhysicalAllowanceId, mem.allowanceParams, mem.nonce, "");
        vm.stopPrank();

        // 2. Executives grant allowance
        vm.startPrank(cedars); // correct role Id?
        console.log("Executives granting allowance to Physical sub-DAO...");

        mem.actionId = primeDAO.propose(mem.grantPhysicalAllowanceId, mem.allowanceParams, mem.nonce, "");
        primeDAO.castVote(mem.actionId, 1);

        // Wait voting + timelock
        mem.votingPeriod = primeDAO.getConditions(mem.grantPhysicalAllowanceId).votingPeriod;
        mem.timelock = primeDAO.getConditions(mem.grantPhysicalAllowanceId).timelock;
        vm.roll(block.number + mem.votingPeriod + mem.timelock + 1);

        primeDAO.request(mem.grantPhysicalAllowanceId, mem.allowanceParams, mem.nonce, "");
        vm.stopPrank();

        // Verify Allowance
        uint256[5] memory allowanceInfo =
            IAllowanceModule(config.safeAllowanceModule).getTokenAllowance(treasury, mem.physicalSubDAOAddress, mem.token);
        assertEq(uint96(allowanceInfo[0]), mem.amount, "Physical sub-DAO allowance should be set");

        // --- TEST 2: Digital sub-DAO Allowance Flow ---

        // Verify Digital sub-DAO has delegate status (Checked in InitialSetup)
        Powers digitalSubDAO = deployScript.getDigitalSubDAO();
        mem.digitalSubDAOAddr = address(digitalSubDAO); // Usually this should be the address

        // Params for allowance
        mem.allowanceParams = abi.encode(mem.digitalSubDAOAddr, mem.token, mem.amount, mem.resetTime, mem.resetBase);
        mem.nonce++;

        // 1. Digital sub-DAO requests allowance
        // Role 5 is required. In script, Role 5 is assigned to 'Cedars' address
        vm.startPrank(mem.digitalSubDAOAddr);
        console.log("Digital sub-DAO requesting allowance...");
        primeDAO.request(mem.requestDigitalAllowanceId, mem.allowanceParams, mem.nonce, "");
        vm.stopPrank();

        // 2. Executives grant allowance
        vm.startPrank(mem.admin);
        console.log("Executives granting allowance to Digital sub-DAO...");

        mem.actionId = primeDAO.propose(mem.grantDigitalAllowanceId, mem.allowanceParams, mem.nonce, "");
        primeDAO.castVote(mem.actionId, 1);

        mem.votingPeriod = primeDAO.getConditions(mem.grantDigitalAllowanceId).votingPeriod;
        mem.timelock = primeDAO.getConditions(mem.grantDigitalAllowanceId).timelock;
        vm.roll(block.number + mem.votingPeriod + mem.timelock + 1);

        primeDAO.request(mem.grantDigitalAllowanceId, mem.allowanceParams, mem.nonce, "");
        vm.stopPrank();

        // Verify Allowance
        allowanceInfo =
            IAllowanceModule(config.safeAllowanceModule).getTokenAllowance(treasury, mem.digitalSubDAOAddr, mem.token);
        assertEq(uint96(allowanceInfo[0]), mem.amount, "Digital sub-DAO allowance should be set");
    }

    function test_PaymentOfReceipts_DigitalSubDAO() public {
        // --- Grant Allowance to Digital sub-DAO (Prime DAO side) ---
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
        vm.startPrank(cedars);
        primeDAO.request(mem.requestDigitalAllowanceId, mem.allowanceParams, mem.nonce, "");
        vm.stopPrank();

        // 2. Grant Allowance (by conveners - Role 2)
        console2.log("Executives granting allowance to Digital sub-DAO...");
        vm.startPrank(mem.admin);
        mem.actionId = primeDAO.propose(mem.grantDigitalAllowanceId, mem.allowanceParams, mem.nonce, "");
        primeDAO.castVote(mem.actionId, 1);

        uint32 votingPeriod = primeDAO.getConditions(mem.grantDigitalAllowanceId).votingPeriod;
        uint32 timelock = primeDAO.getConditions(mem.grantDigitalAllowanceId).timelock;
        vm.roll(block.number + votingPeriod + timelock + 1);

        primeDAO.request(mem.grantDigitalAllowanceId, mem.allowanceParams, mem.nonce, "");
        vm.stopPrank();

        // Verify Allowance
        uint256[5] memory allowanceInfo =
            IAllowanceModule(config.safeAllowanceModule).getTokenAllowance(treasury, mem.digitalSubDAOAddr, mem.token);
        assertEq(uint96(allowanceInfo[0]), mem.amount, "Digital sub-DAO allowance should be set");

        // Fund Treasury
        vm.deal(treasury, 10 ether);
        assertEq(treasury.balance, 10 ether, "Treasury should have funds");

        // --- Digital sub-DAO Payment Flow ---
        // Mandates:
        // 2: Submit Receipt (Public)
        // 3: OK Receipt (Conveners)
        // 4: Approve Payment (Conveners)

        address recipient = address(0x123456789);
        uint256 paymentAmount = 0.5 ether;

        // Params: address Token, uint256 Amount, address PayableTo
        bytes memory paymentParams = abi.encode(mem.token, paymentAmount, recipient);

        // Step 1: Submit Receipt (Public)
        address publicUser = address(0x999);
        vm.startPrank(publicUser);
        console.log("Submitting receipt...");
        // Propose
        mem.nonce++;
        uint16 submitReceiptId = findMandateIdInOrg("Submit a Receipt: Anyone can submit a receipt for payment reimbursement.", digitalSubDAO);
        digitalSubDAO.request(submitReceiptId, paymentParams, mem.nonce, "");
        vm.stopPrank();

        vm.roll(block.number + 1); // Advance block to avoid same-block issues

        // Step 2: OK Receipt (Conveners)
        // Who is convener? Cedars (assigned in Mandate 1).
        vm.startPrank(cedars);
        console.log("OK'ing receipt...");
        // Request (Condition: Role 2. No voting period set).
        uint16 okReceiptId = findMandateIdInOrg("OK a receipt: Any convener can ok a receipt for payment reimbursement.", digitalSubDAO);
        digitalSubDAO.request(okReceiptId, paymentParams, mem.nonce, "");
        vm.stopPrank();

        // Step 3: Approve Payment (Conveners)
        vm.startPrank(cedars);
        console.log("Approving payment...");
        uint16 approvePaymentId = findMandateIdInOrg("Approve payment of receipt: Execute a transaction from the Safe Treasury.", digitalSubDAO);
        mem.actionId = digitalSubDAO.propose(approvePaymentId, paymentParams, mem.nonce, "");

        // Vote (Quorum 50%, SucceedAt 67%)
        // Cedars is likely the only role holder?
        // In Mandate 1, only Cedars is assigned Role 2.
        // So 1 vote should be 100%.
        digitalSubDAO.castVote(mem.actionId, 1);

        // Wait voting period (5 mins)
        votingPeriod = digitalSubDAO.getConditions(approvePaymentId).votingPeriod;
        vm.roll(block.number + votingPeriod + 1);

        // Execute
        digitalSubDAO.request(approvePaymentId, paymentParams, mem.nonce, "");
        vm.stopPrank();

        // Verify Payment
        assertEq(recipient.balance, paymentAmount, "Recipient should have received payment");

        // Verify Allowance Spent
        allowanceInfo =
            IAllowanceModule(config.safeAllowanceModule).getTokenAllowance(treasury, mem.digitalSubDAOAddr, mem.token);
        assertEq(uint96(allowanceInfo[1]), paymentAmount, "Allowance spent should match payment");
    }

    function test_JoinPrimeDAO() public {
        uint16 claimStep1Id = findMandateIdInOrg("Request Membership Step 1: 2 POAPS from physical DAO and 20 activity tokens from ideas DAOs needed that are not older than 6 months.", primeDAO);
        uint16 claimStep2Id = findMandateIdInOrg("Request Membership Step 2: 2 POAPS from physical DAO and 20 activity tokens from ideas DAOs needed that are not older than 6 months.", primeDAO);

        // --- Step 1: Create Ideas sub-DAO ---
        vm.startPrank(mem.admin);
        mem.params = abi.encode("Ideas sub-DAO", "ipfs://ideas");
        mem.nonce = 1;

        // Initiate
        mem.actionId = primeDAO.propose(mem.initiateIdeasMandateId, mem.params, mem.nonce, "");
        primeDAO.castVote(mem.actionId, 1);
        vm.roll(block.number + primeDAO.getConditions(mem.initiateIdeasMandateId).votingPeriod + 1);
        primeDAO.request(mem.initiateIdeasMandateId, mem.params, mem.nonce, "");

        // Create
        mem.actionId = primeDAO.propose(mem.createIdeasMandateId, mem.params, mem.nonce, "");
        primeDAO.castVote(mem.actionId, 1);
        vm.roll(block.number + primeDAO.getConditions(mem.createIdeasMandateId).votingPeriod + 1);
        mem.actionId = primeDAO.request(mem.createIdeasMandateId, mem.params, mem.nonce, "");

        // Get address
        mem.ideasSubDAOAddress = abi.decode(primeDAO.getActionReturnData(mem.actionId, 0), (address));
        Powers ideasSubDAO = Powers(mem.ideasSubDAOAddress);
        console.log("Ideas sub-DAO created at: %s", mem.ideasSubDAOAddress);

        // Assign Role
        primeDAO.request(mem.assignRoleMandateId, mem.params, mem.nonce, "");
        vm.stopPrank();

        // --- Step 2: Create Physical sub-DAO (via Ideas sub-DAO) ---
        // Ideas sub-DAO Mandate 3: Request new Physical sub-DAO
        // Needs Convener (Cedars) - Role 2 @Ideas sub-DAO
        // Powers ideasSubDAO = Powers(mem.ideasSubDAOAddress); // Already defined above
        vm.prank(mem.ideasSubDAOAddress);
        ideasSubDAO.assignRole(2, cedars); // Assign Role 2 to Cedars at Ideas sub-DAO

        vm.startPrank(cedars); // has role two, also at Ideas sub-DAO
        mem.params = abi.encode("Physical sub-DAO", "ipfs://physical");
        mem.nonce = 1;

        console.log("Ideas sub-DAO requesting Physical sub-DAO creation...");
        // Ideas sub-DAO Mandate 3 calls PrimeDAO Mandate 11 (Initiate Physical)
        uint16 reqPhysicalId = findMandateIdInOrg("Initiate request new Physical sub-DAO: Conveners can request creation new Physical sub-DAO.", ideasSubDAO);
        ideasSubDAO.request(reqPhysicalId, mem.params, mem.nonce, "");

        // // --- Step 2: Create Physical sub-DAO ---
        vm.roll(block.number + 1); // Advance block to avoid same-block issues
        
        console.log("Creating Physical sub-DAO...");
        mem.actionId = primeDAO.propose(mem.createPhysicalId, mem.params, mem.nonce, "");
        primeDAO.castVote(mem.actionId, 1);
        vm.roll(block.number + primeDAO.getConditions(mem.createPhysicalId).votingPeriod + 1);
        mem.actionId = primeDAO.request(mem.createPhysicalId, mem.params, mem.nonce, "");

        // Get address
        bytes memory returnData = primeDAO.getActionReturnData(mem.actionId, 0);
        mem.physicalSubDAOAddress = abi.decode(returnData, (address));
        Powers physicalSubDAO = Powers(mem.physicalSubDAOAddress);
        console.log("Physical sub-DAO created at: %s", mem.physicalSubDAOAddress);

        // --- Step 3: Assign Role ---
        console.log("Assigning Role...");
        primeDAO.request(mem.assignRoleId, mem.params, mem.nonce, "");

        // Verify Role 3 (Physical sub-DAOs)
        assertTrue(primeDAO.hasRoleSince(mem.physicalSubDAOAddress, 3) > 0, "Role 3 missing");

        // --- Step 4: Assign Allowance ---
        console.log("Assigning Allowance...");
        primeDAO.request(mem.assignDelegateId, mem.params, mem.nonce, "");
        vm.stopPrank();

        // --- Step 3: Mint 20 Activity Tokens at Ideas sub-DAO ---
        address user = address(0xABCD);
        uint256[] memory nonces = new uint256[](22);
        uint256[] memory actionIds = new uint256[](22);
        uint256[] memory tokenIds = new uint256[](22);
        mem.params = abi.encode(user);

        console.log("Minting 20 Activity tokens for user: %s", user);
        // Mandate 2: Mint activity token (Public)
        mem.nonce = 1000;
        uint16 mintActivityId = findMandateIdInOrg("Mint activity token: Anyone can mint an Active Ideas token. One token is available per 5 minutes.", ideasSubDAO);
        for (uint256 i = 0; i < 20; i++) {
            mem.nonce++;
            nonces[i] = mem.nonce;
            ideasSubDAO.request(mintActivityId, mem.params, mem.nonce, "");
            vm.roll(block.number + deployScript.minutesToBlocks(6, config.BLOCKS_PER_HOUR)); // Advance 6 minutes between mints
        }

        // --- Step 4: Mint 2 POAPs at Physical sub-DAO ---
        // Powers physicalSubDAO = Powers(mem.physicalSubDAOAddress); // Already defined
        vm.prank(address(physicalSubDAO));
        physicalSubDAO.assignRole(2, cedars); // Assign Role 2 to Cedars at Ideas sub-DAO

        console.log("Minting 2 POAPs for user: %s", user);
        vm.startPrank(cedars); // Convener of Physical sub-DAO
        mem.params = abi.encode(user);

        // Mandate 2: Mint POAP
        uint16 mintPoapId = findMandateIdInOrg("Mint POAP: Any Convener can mint a POAP.", physicalSubDAO);
        physicalSubDAO.request(mintPoapId, mem.params, mem.nonce, "");
        nonces[20] = mem.nonce;
        mem.nonce++;
        physicalSubDAO.request(mintPoapId, mem.params, mem.nonce, "");
        nonces[21] = mem.nonce;
        vm.stopPrank();

        // --- Step 5: Claim Access to Prime DAO ---
        uint16 mintActivityTokenPrimeId = findMandateIdInOrg("Mint token Ideas sub-DAO: Any Ideas sub-DAO can mint new NFTs", primeDAO);
        uint16 mintPoapPrimeId = findMandateIdInOrg("Mint token Physical sub-DAO: Any Physical sub-DAO can mint new NFTs", primeDAO);

        for (uint256 i = 0; i < actionIds.length; i++) {
            uint16 mandateId;
            if (i < 20) {
                mandateId = mintActivityTokenPrimeId; // Mandate 25: Mint Activity Token @ primeDAO
            } else {
                mandateId = mintPoapPrimeId; // Mandate 26: Mint POAP @ primeDAO
            }
            uint256 actionId = uint256(keccak256(abi.encode(mandateId, mem.params, nonces[i])));

            tokenIds[i] = uint256(abi.decode(primeDAO.getActionReturnData(actionId, 0), (uint256)));
        }

        vm.startPrank(user);
        console.log("Claiming access to Prime DAO...");

        // Step 1: Check POAPs
        mem.nonce = 2000;
        primeDAO.request(claimStep1Id, abi.encode(tokenIds), mem.nonce, "");

        // Step 2: Check Activity Tokens
        primeDAO.request(claimStep2Id, abi.encode(tokenIds), mem.nonce, "");
        vm.stopPrank();

        // Verify Membership
        assertTrue(primeDAO.hasRoleSince(user, 1) != 0, "User should have Member role (1) in Prime DAO");
    }

    function test_DigitalSubDAO_TransferToTreasury() public {
        // 2. Grant Allowance for Tokens
        SimpleErc20Votes tokenToSweep = new SimpleErc20Votes();

        mem.amount = 1000 ether; // Large allowance
        mem.resetTime = 0;
        mem.resetBase = 0;

        // Grant Allowance for tokenToSweep
        mem.allowanceParams =
            abi.encode(mem.digitalSubDAOAddr, address(tokenToSweep), mem.amount, mem.resetTime, mem.resetBase);
        mem.nonce = 100;

        vm.startPrank(cedars);
        primeDAO.request(mem.requestDigitalAllowanceId, mem.allowanceParams, mem.nonce, "");
        vm.stopPrank();

        vm.startPrank(mem.admin);
        mem.actionId = primeDAO.propose(mem.grantDigitalAllowanceId, mem.allowanceParams, mem.nonce, "");
        primeDAO.castVote(mem.actionId, 1);
        vm.roll(
            block.number + primeDAO.getConditions(mem.grantDigitalAllowanceId).votingPeriod
                + primeDAO.getConditions(mem.grantDigitalAllowanceId).timelock + 1
        );
        primeDAO.request(mem.grantDigitalAllowanceId, mem.allowanceParams, mem.nonce, "");
        vm.stopPrank();

        // 3. Fund Digital sub-DAO with tokens
        tokenToSweep.mint(mem.digitalSubDAOAddr, 50 ether);

        assertEq(tokenToSweep.balanceOf(mem.digitalSubDAOAddr), 50 ether, "Digital sub-DAO should have sweep tokens");
        assertEq(tokenToSweep.balanceOf(treasury), 0, "Treasury should have 0 sweep tokens");

        // 4. Execute Transfer Mandate
        // Mandate 8: Transfer tokens to treasury
        // Allowed Role: 2 (Conveners) => Cedars
        vm.startPrank(cedars);
        console.log("Executing Transfer Tokens to Treasury...");

        mem.nonce = 500;
        uint16 transferToTreasuryId = findMandateIdInOrg("Transfer tokens to treasury: Any tokens accidently sent to the DAO can be recovered by sending them to the treasury", digitalSubDAO);
        digitalSubDAO.request(transferToTreasuryId, "", mem.nonce, "");
        vm.stopPrank();

        // 5. Verify
        assertEq(tokenToSweep.balanceOf(mem.digitalSubDAOAddr), 0, "Digital sub-DAO should have 0 sweep tokens");
        assertEq(tokenToSweep.balanceOf(treasury), 50 ether, "Treasury should have received sweep tokens");
    }

    function test_IdeasSubDAO_Election() public {
        // --- Step 1: Initiate Ideas sub-DAO (Members) ---
        vm.startPrank(mem.admin);

        mem.params = abi.encode("Test Ideas sub-DAO", "ipfs://test");
        mem.nonce = 1;

        console.log("Initiating Ideas sub-DAO...");
        // Propose
        mem.actionId = primeDAO.propose(mem.initiateIdeasMandateId, mem.params, mem.nonce, "");

        // Vote
        primeDAO.castVote(mem.actionId, 1); // 1 = For

        // Wait for voting period
        mem.votingPeriod = primeDAO.getConditions(mem.initiateIdeasMandateId).votingPeriod;
        vm.roll(block.number + mem.votingPeriod + 1);

        // Execute (Request)
        primeDAO.request(mem.initiateIdeasMandateId, mem.params, mem.nonce, "");
        vm.stopPrank();

        // --- Step 2: Create Ideas sub-DAO (Executives) ---
        vm.startPrank(mem.admin);
        console.log("Creating Ideas sub-DAO...");

        // Propose
        mem.actionId = primeDAO.propose(mem.createIdeasMandateId, mem.params, mem.nonce, "");

        // Vote
        primeDAO.castVote(mem.actionId, 1);

        // Wait
        mem.votingPeriod = primeDAO.getConditions(mem.createIdeasMandateId).votingPeriod;
        vm.roll(block.number + mem.votingPeriod + 1);

        // Execute
        mem.actionId = primeDAO.request(mem.createIdeasMandateId, mem.params, mem.nonce, "");
        vm.stopPrank();

        // --- Step 3: Assign Role Id (Executives) ---
        vm.startPrank(mem.admin);
        console.log("Assigning Role...");

        // Execute (No quorum, immediate execution)
        primeDAO.request(mem.assignRoleMandateId, mem.params, mem.nonce, "");
        vm.stopPrank();

        // --- Verify Creation ---
        mem.returnData = primeDAO.getActionReturnData(mem.actionId, 0);
        mem.ideasSubDAOAddress = abi.decode(mem.returnData, (address));
        Powers ideasSubDAO = Powers(mem.ideasSubDAOAddress);
        console.log("Ideas sub-DAO created at: %s", mem.ideasSubDAOAddress);

        // --- Setup User (Member) ---
        address user = address(0x100);
        vm.prank(address(ideasSubDAO)); // Admin of Ideas sub-DAO is itself
        ideasSubDAO.assignRole(1, user);
        assertTrue(ideasSubDAO.hasRoleSince(user, 1) != 0, "User should have Role 1 (Member)");

        // --- Refactored Election Flow ---
        vm.startPrank(user);
        mem.nonce = 100;

        // 1. Create Election (Mandate 8)
        console.log("Creating Election...");
        uint48 startBlock = uint48(block.number + 50);
        uint48 endBlock = uint48(block.number + 100);
        bytes memory electionParams = abi.encode("Convener Election", startBlock, endBlock);

        uint16 createElectionId = findMandateIdInOrg("Create an election: an election can be initiated be any member.", ideasSubDAO);
        ideasSubDAO.request(createElectionId, electionParams, mem.nonce, "");

        // 2. Nominate (Mandate 9)
        console.log("Nominating...");
        uint16 nominateId = findMandateIdInOrg("Nominate for election: any member can nominate for an election.", ideasSubDAO);
        ideasSubDAO.request(nominateId, electionParams, mem.nonce, "");

        // 3. Open Vote (Mandate 11)
        console.log("Creating Vote...");
        vm.roll(startBlock + 1); // Advance to start
        uint16 openVoteId = findMandateIdInOrg("Open voting for election: Members can open the vote for an election. This will create a dedicated vote mandate.", ideasSubDAO);
        mem.actionId = ideasSubDAO.request(openVoteId, electionParams, mem.nonce, "");

        // Get Vote Mandate ID
        bytes memory returnData = ideasSubDAO.getActionReturnData(mem.actionId, 0);
        uint256 voteMandateId = abi.decode(returnData, (uint256));
        console.log("Vote Mandate ID: %s", voteMandateId);

        // 4. Vote (Mandate = voteMandateId)
        console.log("Voting...");
        bool[] memory votes = new bool[](1);
        votes[0] = true;
        mem.params = abi.encode(votes);

        ideasSubDAO.request(uint16(voteMandateId), mem.params, mem.nonce, "");

        // 5. Tally (Mandate 12)
        console.log("Tallying...");
        vm.roll(endBlock + 1); // Advance to end
        uint16 tallyElectionId = findMandateIdInOrg("Tally elections: After an election has finished, assign the Convener role to the winners.", ideasSubDAO);
        ideasSubDAO.request(tallyElectionId, electionParams, mem.nonce, "");

        // 6. Clean Up (Mandate 13)
        console.log("Cleaning Up...");
        // Verify Vote Mandate Active
        (,, mem.isActive) = ideasSubDAO.getAdoptedMandate(uint16(voteMandateId));
        assertTrue(mem.isActive, "Vote Mandate should be active before cleanup");

        // Clean up needs same calldata and nonce as Open Vote to find the return value
        uint16 cleanupElectionId = findMandateIdInOrg("Clean up election: After an election has finished, clean up related mandates.", ideasSubDAO);
        ideasSubDAO.request(cleanupElectionId, electionParams, mem.nonce, "");

        // Verify Vote Mandate Revoked
        (,, mem.isActive) = ideasSubDAO.getAdoptedMandate(uint16(voteMandateId));
        assertFalse(mem.isActive, "Vote Mandate should be revoked after cleanup");

        vm.stopPrank();

        // Verify Result
        assertTrue(ideasSubDAO.hasRoleSince(user, 2) != 0, "User should have Role 2 (Convener)");
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
